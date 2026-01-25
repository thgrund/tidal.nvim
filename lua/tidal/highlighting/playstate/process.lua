local PlayStateProcessor = {}

local highlight = require("tidal.highlighting.highlights")
local marker = require("tidal.highlighting.marker")
local playStateParser = require("tidal.highlighting.playstate.parser")
local state = require("tidal.core.state")

local LOCK_INIT_PLAYSTATE = "INIT_PLAYSTATE"
local LOCK_EXTEND_PLAYSTATE = "EXTEND_PLAYSTATE"

---@type table<string, TidalEvent>
local currentPlayState = {}

--- @type table<string, TidalEvent>
local activeEvents = {}

PlayStateProcessor.timer = nil
PlayStateProcessor.sam = 0
PlayStateProcessor.interval = nil
PlayStateProcessor._lastReceivedPlayState = nil
PlayStateProcessor._currentPlayState = {}

PlayStateProcessor.handleMessageCallback = nil

local function removeFirstAndLast(t)
  if not t or type(t) ~= "table" or #t < 2 then
    return t
  end

  table.remove(t, 1)
  table.remove(t)

  return t
end

local function startsWith(str, start)
  return str:sub(1, #start) == start
end

---
--- @param sam number
--- @param prevActive table<string, TidalEvent>
--- @param current table<string, TidalEvent>
local function diff(sam, prevActive, current)
  local remove = {}
  local add = {}
  local active = {}

  if sam ~= nil then
    if next(current) ~= nil then
      for key, _ in pairs(prevActive) do
        if current[key] == nil then
          table.insert(remove, key)
        end
      end
    end
    for key, tidalEvent in pairs(current) do
      if tidalEvent ~= nil and tidalEvent.whole ~= nil then
        if tidalEvent.whole.stop <= sam then
          table.insert(remove, key)
        end

        if tidalEvent.whole.start <= sam and tidalEvent.whole.stop >= sam then
          if prevActive[key] == nil then
            table.insert(add, key)
          end

          if prevActive[key] ~= nil then
            table.insert(active, key)
          end
        end
      end
    end
  end

  return {
    remove = remove,
    add = add,
    active = active,
  }
end

--- @param active table<string, TidalEvent>
--- @param current table<string, TidalEvent>
local function updateActive(active, current)
  local removable = {}
  local keepable = {}
  local currentLookup = {}

  -- Build a lookup table for current events using a composite key
  -- This reduces complexity from O(n²) to O(n + m)
  for currentId, currentEvent in pairs(current) do
    if currentEvent and currentEvent.whole then
      local key = string.format(
        "%d_%d_%.6f_%.6f_%s",
        currentEvent.eventId,
        currentEvent.colStart,
        currentEvent.whole.start,
        currentEvent.whole.stop,
        currentEvent.id or ""
      )
      currentLookup[key] = { id = currentId, event = currentEvent }
    end
  end

  -- Check each active event against the lookup table
  for activeId, activeEvent in pairs(active) do
    if activeEvent and activeEvent.whole then
      local key = string.format(
        "%d_%d_%.6f_%.6f_%s",
        activeEvent.eventId,
        activeEvent.colStart,
        activeEvent.whole.start,
        activeEvent.whole.stop,
        activeEvent.id or ""
      )

      local found = currentLookup[key]
      if found then
        keepable[found.id] = found.event
      else
        removable[activeId] = activeEvent
      end
    else
      removable[activeId] = activeEvent
    end
  end

  return { removable = removable, active = keepable }
end

---@param id string
---@return TidalExtMark?
local function getExtMark(id, playState)
  local extmark

  if playState[id] ~= nil then
    local eventId = playState[id].eventId
    local colStart = playState[id].colStart

    if marker.extMarks[eventId] and marker.extMarks[eventId][colStart] then
      extmark = marker.extMarks[eventId][colStart]
      extmark.id = playState[id].id
    end
  end

  return extmark
end

local function cleanHighlights(removableEvents)
  for id, _ in pairs(removableEvents) do
    local extmark = getExtMark(id, removableEvents)

    if extmark ~= nil then
      highlight.removeHighlight(extmark.buf, extmark.markerId)
    end
  end
end

function PlayStateProcessor.setSam(sam)
  if sam == nil then
    return
  end

  local prevSam = PlayStateProcessor.sam

  PlayStateProcessor.sam = sam

  if prevSam == nil then
    PlayStateProcessor.init()
  end

  local intSam = math.floor(sam)

  if prevSam ~= nil and math.floor(prevSam) ~= intSam and next(currentPlayState) ~= nil then
    PlayStateProcessor.getPlayState(intSam + 3, intSam + 4, LOCK_EXTEND_PLAYSTATE)
  end
end

function PlayStateProcessor.handleEvents()
  local events = diff(PlayStateProcessor.sam, activeEvents, currentPlayState)

  local activeMessages = {}

  for _, id in ipairs(events.add) do
    local extmark = getExtMark(id, currentPlayState)

    activeEvents[id] = currentPlayState[id]

    if extmark ~= nil then
      highlight.addHighlight(extmark.id, extmark.buf, extmark.markerId)
      table.insert(activeMessages, extmark)
    end
  end

  for _, id in ipairs(events.remove) do
    local removeCandidate = activeEvents[id]
    local shallBeRemoved = true

    if removeCandidate == nil then
      shallBeRemoved = false
    else
      for _, event in pairs(activeEvents) do
        if
          event ~= nil
          and event.whole ~= nil
          and removeCandidate.whole ~= nil
          and event.colStart == removeCandidate.colStart
          and event.eventId == removeCandidate.eventId
          and event.whole.stop > removeCandidate.whole.stop
        then
          shallBeRemoved = false
        end
      end
    end

    if shallBeRemoved then
      local extmark = getExtMark(id, currentPlayState)

      if extmark ~= nil then
        highlight.removeHighlight(extmark.buf, extmark.markerId)
      end
    end

    activeEvents[id] = nil
    currentPlayState[id] = nil
  end

  for _, id in ipairs(events.active) do
    local extmark = getExtMark(id, currentPlayState)

    if extmark ~= nil then
      table.insert(activeMessages, extmark)
    end
  end

  if PlayStateProcessor.handleMessageCallback then
    PlayStateProcessor.handleMessageCallback(activeMessages)
  end
end

--- Parses and maps a list of tidal event state strings like
--- [((8,2),(18,2))]0-(1>2)-3|_id_: "1", orbit: 0, s: "superpiano"
--- so that can be processed.
---@param list string[]
---@return table<string, TidalEvent>
function PlayStateProcessor.parse(list)
  local result = {}

  for _, raw in ipairs(list) do
    for key, parsed in pairs(playStateParser.parse(raw)) do
      result[key] = parsed
    end
  end

  return result
end

function PlayStateProcessor.onDataProcessed(output)
  if #output > 2 then
    if startsWith(output[1], LOCK_EXTEND_PLAYSTATE) then
      output = removeFirstAndLast(output)

      PlayStateProcessor._lastReceivedPlayState = output

      -- local initNow = vim.loop.hrtime() / 1e6
      local parsedOutput = PlayStateProcessor.parse(output)
      --  local delta = (vim.loop.hrtime() / 1e6) - initNow
      --  print("EXTEND DELTA: " .. tostring(delta))

      for key, parsed in pairs(parsedOutput) do
        currentPlayState[key] = parsed
      end

      PlayStateProcessor._currentPlayState = currentPlayState

      return
    end

    if startsWith(output[1], LOCK_INIT_PLAYSTATE) then
      local initNow = vim.loop.hrtime() / 1e6
      output = removeFirstAndLast(output)
      local delta = (vim.loop.hrtime() / 1e6) - initNow
      print("removeFirstAndLast: " .. tostring(delta))

      PlayStateProcessor._lastReceivedPlayState = output

      local initNow2 = vim.loop.hrtime() / 1e6
      local parsedOutput = PlayStateProcessor.parse(output)
      local delta2 = (vim.loop.hrtime() / 1e6) - initNow2
      print("parse: " .. tostring(delta2))

      currentPlayState = parsedOutput

      local initNow3 = vim.loop.hrtime() / 1e6
      local updatedEvents = updateActive(activeEvents, currentPlayState)
      local delta3 = (vim.loop.hrtime() / 1e6) - initNow3
      print("updateActive: " .. tostring(delta3))

      local initNow4 = vim.loop.hrtime() / 1e6
      cleanHighlights(updatedEvents.removable)
      local delta4 = (vim.loop.hrtime() / 1e6) - initNow4
      print("cleanHighlights: " .. tostring(delta4))

      activeEvents = updatedEvents.active

      PlayStateProcessor._currentPlayState = currentPlayState

      print("\n")
      return
    end
  end
end

function PlayStateProcessor.init()
  local sam = PlayStateProcessor.sam

  if sam ~= nil and next(currentPlayState) == nil then
    local intSam = math.floor(sam)
    PlayStateProcessor.getPlayState(intSam, intSam + 5, LOCK_INIT_PLAYSTATE)
  end
end

function PlayStateProcessor.reset()
  currentPlayState = {}
  -- activeEvents = {}
  PlayStateProcessor.sam = nil
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayStateProcessor.getPlayState(start, stop, lock)
  if start and stop then
    state.ghci:send("streamActivePt tidal (Arc " .. start .. " " .. stop .. ")", nil, lock)
  end
end

PlayStateProcessor._diff = diff
PlayStateProcessor._updateActive = updateActive
return PlayStateProcessor

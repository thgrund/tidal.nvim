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

local handleMessageCallback = nil

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

  --print(string.format("SAM: %f ", sam))
  -- for _, tidalEvent in pairs(current) do
  --   if tidalEvent.whole ~= nil then
  --     print(string.format("Whole start: %f ; stop: %f", tidalEvent.whole.start, tidalEvent.whole.stop))
  --   end
  -- end

  if sam ~= nil then
    for key, tidalEvent in pairs(current) do
      if tidalEvent ~= nil and tidalEvent.whole ~= nil then
        if tidalEvent.whole.stop < sam then
          -- print(
          --   string.format(
          --     "Remove Key: %s ; SAM: %f ;Whole start: %f ; stop: %f",
          --     key,
          --     sam,
          --     tidalEvent.whole.start,
          --     tidalEvent.whole.stop
          --   )
          -- )
          table.insert(remove, key)
        end

        if tidalEvent.whole.start <= sam and tidalEvent.whole.stop >= sam then
          if prevActive[key] == nil then
            -- print(
            --   string.format(
            --     "Add Key: %s ; SAM: %f ;Whole start: %f ; stop: %f",
            --     key,
            --     sam,
            --     tidalEvent.whole.start,
            --     tidalEvent.whole.stop
            --   )
            -- )
            table.insert(add, key)
          end

          if prevActive[key] ~= nil then
            -- print(
            --   string.format(
            --     "Active Key: %s ; SAM: %f ;Whole start: %f ; stop: %f",
            --     key,
            --     sam,
            --     tidalEvent.whole.start,
            --     tidalEvent.whole.stop
            --   )
            -- )
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

---@param id integer
---@return TidalExtMark?
local function getExtMark(id)
  local extmark

  local eventId = currentPlayState[id].eventId
  local colStart = currentPlayState[id].colStart

  if marker.extMarks[eventId] and marker.extMarks[eventId][colStart] then
    extmark = marker.extMarks[eventId][colStart]
    extmark.id = currentPlayState[id].id
  end

  return extmark
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

  --  print(
  --    string.format(
  --      "Remove %s Add %s Active %s",
  --      table.concat(events.remove, ", "),
  --      table.concat(events.add, ", "),
  --      table.concat(events.active, ", ")
  --    )
  --  )
  --
  for _, id in ipairs(events.add) do
    local extmark = getExtMark(id)

    activeEvents[id] = currentPlayState[id]

    if extmark ~= nil then
      highlight.addHighlight(extmark.id, extmark.buf, extmark.markerId)
      -- table.insert(activeMessages, extmark)
    end
  end

  for _, id in ipairs(events.remove) do
    local removeCandidate = activeEvents[id]
    local shallBeRemoved = true

    for _, event in pairs(activeEvents) do
      if
        event ~= nil
        and event.whole ~= nil
        and removeCandidate ~= nil
        and removeCandidate.whole ~= nil
        and event.colStart == removeCandidate.colStart
        and event.eventId == removeCandidate.eventId
        and event.whole.stop > removeCandidate.whole.stop
      then
        shallBeRemoved = false
      end
    end

    if shallBeRemoved then
      local extmark = getExtMark(id)

      if extmark ~= nil then
        highlight.removeHighlight(extmark.buf, extmark.markerId)
      end
    end

    activeEvents[id] = nil
    currentPlayState[id] = nil
  end

  -- for _, id in ipairs(events.active) do
  --   local extmark = getExtMark(id)

  --   if extmark ~= nil then
  --     table.insert(activeMessages, extmark)
  --   end
  -- end

  -- if handleMessageCallback then
  --   handleMessageCallback(activeMessages)
  -- end
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

      local parsedOutput = PlayStateProcessor.parse(output)

      for key, parsed in pairs(parsedOutput) do
        currentPlayState[key] = parsed
      end

      PlayStateProcessor._currentPlayState = currentPlayState

      return
    end

    if startsWith(output[1], LOCK_INIT_PLAYSTATE) then
      output = removeFirstAndLast(output)

      PlayStateProcessor._lastReceivedPlayState = output
      local parsedOutput = PlayStateProcessor.parse(output)

      currentPlayState = parsedOutput

      PlayStateProcessor._currentPlayState = currentPlayState

      return
    end
  end
end

function PlayStateProcessor.init()
  local sam = PlayStateProcessor.sam

  if sam ~= nil and next(currentPlayState) == nil then
    local intSam = math.floor(sam)
    PlayStateProcessor.getPlayState(intSam, intSam + 4, LOCK_INIT_PLAYSTATE)
  end
end

function PlayStateProcessor.reset()
  currentPlayState = {}
  activeEvents = {}
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayStateProcessor.getPlayState(start, stop, lock)
  -- print(string.format("sam %f start %f stop %f", PlayStateProcessor.sam, start, stop))
  if start and stop then
    state.ghci:send("streamActivePt tidal (Arc " .. start .. " " .. stop .. ")", nil, lock)
  end
end

PlayStateProcessor._diff = diff

return PlayStateProcessor

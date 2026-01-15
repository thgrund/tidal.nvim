local PlayStateProcessor = {}

local highlight = require("tidal.highlighting.highlights")
local marker = require("tidal.highlighting.marker")
local playStateParser = require("tidal.highlighting.playstate.parser")
local state = require("tidal.core.state")

local LOCK_SAM = "SAM"
local LOCK_INIT_PLAYSTATE = "INIT_PLAYSTATE"
local LOCK_EXTEND_PLAYSTATE = "EXTEND_PLAYSTATE"

---@type table<string, TidalEvent>
local currentPlayState = {}

--- @type table<string, TidalEvent>
local activeEvents = {}

PlayStateProcessor.timer = nil
PlayStateProcessor.sam = nil
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

local function convertHaskelRatio(s)
  local num, den = s:match("^%s*(%-?%d+)%s*%%%s*(%-?%d+)%s*$")

  if not num then
    return nil
  end

  num = tonumber(num)
  den = tonumber(den)

  -- convert to number
  local value = num / den

  return value
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
    for key, tidalEvent in pairs(current) do
      if tidalEvent ~= nil then
        if tidalEvent.whole.stop < sam then
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

local function handleEvents()
  local events = diff(PlayStateProcessor.sam, activeEvents, currentPlayState)

  for _, id in ipairs(events.remove) do
    local extmark = getExtMark(id)

    if extmark ~= nil then
      highlight.removeHighlight(extmark.buf, extmark.markerId)
    end

    activeEvents[id] = nil
    currentPlayState[id] = nil
  end

  for _, id in ipairs(events.add) do
    local extmark = getExtMark(id)

    activeEvents[id] = currentPlayState[id]

    if extmark ~= nil then
      highlight.addHighlight(extmark.id, extmark.buf, extmark.markerId)
      -- table.insert(activeMessages, extmark)
    end
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

function PlayStateProcessor.handleSchedule()
  state.ghci:send("getnow", nil, LOCK_SAM)
end

--- Parses and maps a list of tidal event state strings like
--- [((8,2),(18,2))]0-(1>2)-3|_id_: "1", orbit: 0, s: "superpiano"
--- so that can be processed.
---@param list string[]
---@return table<string, TidalEvent>
function PlayStateProcessor.parse(list)
  local result = {}

  for _, raw in ipairs(list) do
    for key, parsed in pairs(playStateParser.parse(raw, math.floor(PlayStateProcessor.sam))) do
      result[key] = parsed
    end
  end

  return result
end

function PlayStateProcessor.onDataProcessed(output)
  if #output > 2 then
    if startsWith(output[1], LOCK_SAM) then
      removeFirstAndLast(output)
      local sam = convertHaskelRatio(output[1])

      if sam == nil then
        return
      end

      local prevSam = PlayStateProcessor.sam

      PlayStateProcessor.sam = sam
      local intSam = math.floor(sam)

      if next(currentPlayState) == nil then
        PlayStateProcessor.getPlayState(intSam, intSam + 4, LOCK_INIT_PLAYSTATE)
      end

      if prevSam ~= nil and math.floor(prevSam) ~= intSam and next(currentPlayState) ~= nil then
        PlayStateProcessor.getPlayState(intSam + 3, intSam + 4, LOCK_EXTEND_PLAYSTATE)
      end

      handleEvents()

      return
    end

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

function PlayStateProcessor.reset()
  currentPlayState = {}
  activeEvents = {}
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayStateProcessor.getPlayState(start, stop, lock)
  if start and stop then
    state.ghci:send("streamActivePt tidal (Arc " .. start .. " " .. stop .. ")", nil, lock)
  end
end

PlayStateProcessor._handleEvents = handleEvents
PlayStateProcessor._diff = diff

return PlayStateProcessor

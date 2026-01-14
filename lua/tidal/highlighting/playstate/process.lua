local PlayState = {}

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

PlayState.timer = nil
PlayState.sam = nil
PlayState._lastReceivedPlayState = nil
PlayState._currentPlayState = {}

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
    error("Invalid ratio format")
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

  for key, tidalEvent in pairs(current) do
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

--- @param sam number
--- @param prevActive table<string, TidalEvent>
--- @param current table<string, TidalEvent>
local function handleEvents(sam, prevActive, current)
  local events = diff(sam, prevActive, current)
  local activeMessages = {}

  for _, id in ipairs(events.remove) do
    local extmark = getExtMark(id)

    table.remove(activeEvents, id)
    table.remove(currentPlayState, id)

    if extmark ~= nil then
      highlight.removeHighlight(extmark.buf, extmark.markerId)
    end
  end

  for _, id in ipairs(events.add) do
    local extmark = getExtMark(id)

    table.insert(activeEvents, currentPlayState[id])

    if extmark ~= nil then
      highlight.addHighlight(extmark.id, extmark.buf, extmark.markerId)
      table.insert(activeMessages, extmark)
    end
  end

  for _, id in ipairs(events.active) do
    local extmark = getExtMark(id)

    if extmark ~= nil then
      table.insert(activeMessages, extmark)
    end
  end

  if handleMessageCallback then
    handleMessageCallback(activeMessages)
  end
end

function PlayState.handleSchedule()
  state.ghci:send("getnow >>= print . sam", nil, LOCK_SAM)
end

--- Parses and maps a list of tidal event state strings like
--- [((8,2),(18,2))]0-(1>2)-3|_id_: "1", orbit: 0, s: "superpiano"
--- so that can be processed.
---@param list string[]
---@return TidalEvent[]
function PlayState.parse(list)
  local result = {}

  for _, raw in ipairs(list) do
    for key, parsed in pairs(playStateParser.parse(raw)) do
      result[key] = parsed
    end
  end

  return result
end

function PlayState.onDataProcessed(output)
  if #output > 2 then
    if startsWith(output[1], LOCK_SAM) then
      removeFirstAndLast(output)
      local sam = convertHaskelRatio(output[1])

      handleEvents(sam, activeEvents, currentPlayState)

      if next(currentPlayState) == nil then
        PlayState.getPlayState(sam, sam + 4, LOCK_INIT_PLAYSTATE)
      end

      if PlayState.sam == nil then
        PlayState.sam = sam
      elseif math.floor(PlayState.sam) ~= math.floor(sam) then
        PlayState.sam = sam

        if next(currentPlayState) ~= nil then
          PlayState.getPlayState(sam + 3, sam + 4, LOCK_EXTEND_PLAYSTATE)
        end
      end

      return
    end

    if startsWith(output[1], LOCK_EXTEND_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output

      local parsedOutput = PlayState.parse(output)

      for key, parsed in pairs(parsedOutput) do
        currentPlayState[key] = parsed
      end

      PlayState._currentPlayState = currentPlayState

      return
    end

    if startsWith(output[1], LOCK_INIT_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output
      local parsedOutput = PlayState.parse(output)

      currentPlayState = parsedOutput

      PlayState._currentPlayState = currentPlayState

      return
    end
  end
end

function PlayState.reset()
  currentPlayState = {}
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayState.getPlayState(start, stop, lock)
  if start and stop then
    state.ghci:send("streamActivePt tidal (Arc " .. start .. " " .. stop .. ")", nil, lock)
  end
end

PlayState._handleEvents = handleEvents
PlayState._diff = diff

return PlayState

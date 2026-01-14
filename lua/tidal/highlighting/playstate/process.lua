local PlayState = {}

local playStateParser = require("tidal.highlighting.playstate.parser")
local state = require("tidal.core.state")

local LOCK_SAM = "SAM"
local LOCK_INIT_PLAYSTATE = "INIT_PLAYSTATE"
local LOCK_EXTEND_PLAYSTATE = "EXTEND_PLAYSTATE"

---@type TidalEvent[]
local currentPlayState = {}
local activeEvents = {}

PlayState.timer = nil
PlayState.sam = nil
PlayState._lastReceivedPlayState = nil
PlayState._currentPlayState = {}

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
--- @param activeEvents TidalEvent[]
--- @param currentEvents TidalEvent[]
local function diff(sam, active, current)
  local removed = {}
  local added = {}
  local active = {}

  return {
    removed = removed,
    added = added,
    active = active,
  }
end

local function handleEvents() end

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
    for _, parsed in ipairs(playStateParser.parse(raw)) do
      table.insert(result, parsed)
    end
  end

  return result
end

function PlayState.onDataProcessed(output)
  if #output > 2 then
    if startsWith(output[1], LOCK_SAM) then
      removeFirstAndLast(output)
      local sam = convertHaskelRatio(output[1])

      if #currentPlayState == 0 then
        PlayState.getPlayState(sam, sam + 4, LOCK_INIT_PLAYSTATE)
      end

      if PlayState.sam ~= sam then
        PlayState.sam = sam

        if #currentPlayState > 0 then
          PlayState.getPlayState(sam + 3, sam + 4, LOCK_EXTEND_PLAYSTATE)
        end
      end

      handleEvents()

      return
    end

    if startsWith(output[1], LOCK_EXTEND_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output

      local parsedOutput = PlayState.parse(output)

      for _, parsed in ipairs(parsedOutput) do
        table.insert(currentPlayState, parsed)
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

return PlayState

local PlayState = {}

local playStateParser = require("tidal.highlighting.playstate.parser")
local state = require("tidal.core.state")

local uv = vim.uv

local LOCK_SAM = "SAM"
local LOCK_INIT_PLAYSTATE = "INIT_PLAYSTATE"
local LOCK_EXTEND_PLAYSTATE = "EXTEND_PLAYSTATE"

local currentPlayState = {}

PlayState.timer = nil
PlayState.sam = nil
PlayState._lastReceivedPlayState = nil

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

function PlayState.handleSchedule()
  state.ghci:send("getnow >>= print . sam", nil, LOCK_SAM)
end

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

      if PlayState.sam ~= sam then
        PlayState.sam = sam
        PlayState.getPlayState(sam + 3, sam + 4, LOCK_EXTEND_PLAYSTATE)
      end
      return
    end

    if startsWith(output[1], LOCK_EXTEND_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output
      local parsedOutput = PlayState.parse(output)

      for _, parsed in ipairs(parsedOutput) do
        table.insert(currentPlayState, parsed)
      end
      return
    end

    if startsWith(output[1], LOCK_INIT_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output
      local parsedOutput = PlayState.parse(output)
      currentPlayState = parsedOutput
      return
    end
  end
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayState.getPlayState(start, stop, lock)
  if start and stop then
    state.ghci:send("streamActivePt tidal (Arc " .. start .. " " .. stop .. ")", nil, lock)
  end
end

return PlayState

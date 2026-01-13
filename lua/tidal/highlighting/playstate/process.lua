local PlayState = {}

local state = require("tidal.core.state")

local uv = vim.uv

local LOCK_SAM = "SAM"
local LOCK_PLAYSTATE = "PLAYSTATE"

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

local function handleSchedule()
  state.ghci:send("getnow >>= print . sam", nil, LOCK_SAM)
end

local function onDataProcessed(output)
  if #output > 2 then
    if startsWith(output[1], LOCK_SAM) then
      removeFirstAndLast(output)
      local sam = convertHaskelRatio(output[1])

      PlayState.sam = sam

      PlayState.getCurrent()
      return
    end

    if startsWith(output[1], LOCK_PLAYSTATE) then
      removeFirstAndLast(output)
      PlayState._lastReceivedPlayState = output
      return
    end
  end
end

function PlayState.getCurrent()
  if PlayState.sam then
    state.ghci:send(
      "streamActivePt tidal (Arc " .. PlayState.sam .. " " .. (PlayState.sam + 1) .. ")",
      nil,
      LOCK_PLAYSTATE
    )
  end
end

function PlayState.launch()
  state.ghci.onDataProcessed = onDataProcessed
end

function PlayState.setInterval(interval)
  PlayState.timer = uv.new_timer()
  PlayState.timer:start(interval, interval, function()
    vim.schedule(handleSchedule)
  end)
end

function PlayState.clearInterval()
  if PlayState.timer ~= nil then
    PlayState.timer:stop()
    PlayState.timer:close()
    PlayState.timer = nil
  end
end

PlayState._onDataProcessed = onDataProcessed

return PlayState

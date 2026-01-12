local PlayState = {}

local state = require("tidal.core.state")

local uv = vim.uv

PlayState.timer = nil

local function removeFirstAndLast(t)
  if not t or type(t) ~= "table" or #t < 2 then
    return t
  end

  table.remove(t, 1)
  table.remove(t)

  return t
end

local function handleMessages()
  state.ghci:send("getnow >>= print . sam", nil, true)
end

function PlayState.launch()
  state.ghci.onDataProcessed = function(_, playstate)
    local shortened = removeFirstAndLast(playstate)

    for _, value in ipairs(shortened) do
      print(value)
    end
  end
end

function PlayState.setInterval(interval)
  PlayState.timer = uv.new_timer()
  PlayState.timer:start(interval, interval, function()
    vim.schedule(handleMessages)
  end)
end

function PlayState.clearInterval()
  if PlayState.timer ~= nil then
    PlayState.timer:stop()
    PlayState.timer:close()
    PlayState.timer = nil
  end
end

return PlayState

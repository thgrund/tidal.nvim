local PlayState = {}

local process = require("tidal.highlighting.playstate.process")
local state = require("tidal.core.state")

local uv = vim.uv

function PlayState.launch()
  state.ghci.onDataProcessed = process.onDataProcessed
end

function PlayState.setInterval(interval)
  PlayState.timer = uv.new_timer()
  PlayState.timer:start(interval, interval, function()
    vim.schedule(process.handleSchedule)
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

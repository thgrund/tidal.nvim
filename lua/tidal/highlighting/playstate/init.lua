local PlayState = {}

local process = require("tidal.highlighting.playstate.process")
local state = require("tidal.core.state")

local uv = vim.uv

---@class TidalEvent
---@field id string
---@field eventId integer
---@field colStart integer
---@field whole TidalWhole
---
---@class TidalWhole
---@field start number
---@field stop number

function PlayState.launch()
  state.ghci.onDataProcessed = process.onDataProcessed
  state.ghci.sendCallback = process.reset
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

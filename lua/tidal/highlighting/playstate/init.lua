local PlayState = {}

local process = require("tidal.highlighting.playstate.process")
local state = require("tidal.core.state")

---@class TidalEvent
---@field id string
---@field eventId integer
---@field colStart integer
---@field whole TidalWhole
---
---@class TidalWhole
---@field start number
---@field stop number

function PlayState.launch(highlight)
  state.ghci.onDataProcessed = process.onDataProcessed

  process.handleMessageCallback = highlight.highlightCallback
  --state.ghci.stdin:write([[clock "1*60"]])

  state.ghci.sendCallback = function()
    process.reset()
    process.init()
  end
end

return PlayState

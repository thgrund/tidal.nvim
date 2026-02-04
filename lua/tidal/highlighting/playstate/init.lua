local PlayState = {}

local process = require("tidal.highlighting.playstate.process")
local socket = require("tidal.highlighting.playstate.socket")
local state = require("tidal.core.state")

---@class TidalEvent
---@field id string
---@field eventId integer
---@field colStart integer
---@field whole TidalWhole
---@field fun string
---@field val string
---
---@class TidalWhole
---@field start number
---@field stop number

function PlayState.launchStdOut(highlight)
  state.ghci.onDataProcessed = process.onDataProcessed

  process.handleMessageCallback = highlight.highlightCallback

  local tidalExtensionPath = vim.api.nvim_get_runtime_file("tidal/playstate.hs", false)[1]
  state.ghci.stdin:write(string.format('\n:{\n:script "%s"\n:}\n', tidalExtensionPath))

  state.ghci.sendCallback = function()
    process.reset()
    state.ghci.stdin:write(string.format('\n:{\nclock "1*%s"\n:}\n', highlight.fps))
  end
end

function PlayState.launchSocket(highlight)
  socket.handleMessageCallback = highlight.highlightCallback

  local tidalSocketPackPath = vim.api.nvim_get_runtime_file("tidal/socket.hs", false)[1]
  state.ghci.stdin:write(string.format('\n:{\n:script "%s"\n:}\n', tidalSocketPackPath))

  state.ghci.sendCallback = function()
    socket.reset()
    state.ghci.stdin:write(string.format('\n:{\nclock "1*%s"\n:}\n', highlight.fps))
  end

  socket.launch()
end

return PlayState

local EventHighlights = {}

local config = require("tidal.config")
local highlights = require("tidal.highlighting.highlights")
local osc = require("tidal.highlighting.osc")
local playstate = require("tidal.highlighting.playstate")
local playstateOsc = require("tidal.highlighting.playstate.osc")

function EventHighlights.start(highlight)
  local fpsToMs = 1000 / highlight.fps

  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  local baseStyle = config.options.boot.tidal.highlight.styles.global.style
  vim.api.nvim_set_hl(0, baseName, baseStyle)

  for id, style in pairs(highlight.styles.custom) do
    highlights.addConfigHl(id, style)
  end

  if highlight.type == "stdio" then
    playstate.launchStdOut(highlight)
    playstateOsc.launch(highlight)
    vim.notify("Stdio event highlighting launched")
  elseif highlight.type == "socket" then
    playstate.launchSocket(highlight)
    playstateOsc.launch(highlight)
    vim.notify("Unix socket event highlighting launched")
  elseif highlight.type == "osc" then
    osc.launch(highlight)
    osc.handleMessageCallback = highlight.highlightCallback
    osc.setInterval(fpsToMs)
  end
end

function EventHighlights.stop()
  osc:clearInterval()
end

return EventHighlights

local EventHighlights = {}

local config = require("tidal.config")
local highlights = require("tidal.highlighting.highlights")
local osc = require("tidal.highlighting.osc")
local playstate = require("tidal.highlighting.playstate")

function EventHighlights.start(highlight)
  local fpsToMs = 1000 / highlight.fps

  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  local baseStyle = config.options.boot.tidal.highlight.styles.global.style
  vim.api.nvim_set_hl(0, baseName, baseStyle)

  for id, style in pairs(highlight.styles.custom) do
    highlights.addConfigHl(id, style)
  end

  osc.launch(highlight)
  osc.handleMessageCallback = highlight.highlightCallback
  osc.setInterval(fpsToMs)

  playstate.launch()
  playstate.setInterval(1000)
end

function EventHighlights.stop()
  osc:clearInterval()
  playstate:clearInterval()
end

return EventHighlights

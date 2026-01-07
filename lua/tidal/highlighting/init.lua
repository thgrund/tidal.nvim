local EventHighlights = {}

local config = require("tidal.config")
local highlights = require("tidal.highlighting.highlights")
local osc = require("tidal.highlighting.osc")

function EventHighlights.start(highlight)
  local fpsToMs = 1000 / highlight.fps
  osc.launch(highlight)
  osc.handleMessageCallback = highlight.highlightCallback

  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  local baseStyle = config.options.boot.tidal.highlight.styles.global.style
  vim.api.nvim_set_hl(0, baseName, baseStyle)

  for id, style in pairs(highlight.styles.custom) do
    highlights.addConfigHl(id, style)
  end

  osc.setInterval(fpsToMs)
end

function EventHighlights.stop()
  osc:clearInterval()
end

return EventHighlights

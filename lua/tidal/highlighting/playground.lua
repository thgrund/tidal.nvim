package.loaded["tidal.highlighting.marker"] = nil
package.loaded["tidal.highlighting.highlights"] = nil
package.loaded["tidal.highlighting.tokenizer"] = nil

local highlights = require("tidal.highlighting.highlights")
local marker = require("tidal.highlighting.marker")
local tokenizer = require("tidal.highlighting.tokenizer")

local multiLineExample = [[
:{
  do
    d4 $ s "sally" <| note "c'maj'8"
    d2 $ while "t*2 t" (# silence) $ s "fbass"
    d3 $ s "sally" <| note "c'maj'8"
    d1 $ s "superpiano" <| note "c a f e"
    d5 $ s "bubu" # speed "-1.0"
:}
]]

local bg = "#7eaefc"
vim.api.nvim_set_hl(0, "CodeHighlight", { bg = bg, foreground = "#000000" })

local initRow = 10
local rowIndex = 0
local _, newlines = multiLineExample:gsub("\n", "")

marker.cleanUpMarkers(initRow, initRow + newlines - 1)

for line in multiLineExample:gmatch("[^\r\n]+") do
  tokenizer.addMetadata(line, initRow + rowIndex)
  rowIndex = rowIndex + 1
end

marker.print()

-- for _, markers in pairs(marker.extMarks) do
--   for _, extmark in pairs(markers) do
--     highlights.addHighlight(extmark.buf, extmark.markerId, extmark.row, extmark.colStart, extmark.colEnd)
--   end
-- end

-- for _, markers in pairs(marker.extMarks) do
--   for _, extmark in pairs(markers) do
--     highlights.removeHighlight(extmark.buf, extmark.markerId, extmark.row, extmark.colStart, extmark.colEnd)
--   end
-- end
-- local singleLine = [[d4 $ s "sally" <| note "c'maj'8"]]
--
-- local bg = "#7eaefc"
-- vim.api.nvim_set_hl(0, "CodeHighlight", { bg = bg, foreground = "#000000" })
--
-- local initRow = 43
--
-- print(marker.count())
--
-- tokenizer.addMetadata(singleLine, initRow)
--
-- print(marker.count())
--
-- marker.cleanUpMarkers(initRow, initRow)
--
-- marker.addAllHighlights()
--
-- marker.cleanUpMarkers(initRow, initRow)
--
-- print(marker.count())
--
--
--

local a = nil

if a then
  print("Klappt")
end

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

local a = 1

local b = 1.234

print(tostring(a < b))

local a = 61.933333
local b = 61.933334

local epsilon = 1e-5 -- tolerance

if math.abs(a - b) < epsilon then
  print("Values are equal")
else
  print("Values are different")
end

local epsilon = 1e-5 -- tolerance

local start = 61.933333
local sam   = 61.93333

if (start == sam) then
 print ("Equal")
else
print ("Not equal")
end

local function round(x, decimals)
    local p = 10 ^ decimals
    return math.floor(x * p + 0.5) / p
end


local sam = 61.933334

print (tostring(round(sam, 6)))


        if tidalEvent.whole.stop < sam then

        if tidalEvent.whole.start <= sam and tidalEvent.whole.stop >= sam then

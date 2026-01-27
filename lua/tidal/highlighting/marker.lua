---@class Marker
---@field extMarks TidalExtMarks -- eventId -> col -> ExtMark
local Marker = {}

---@class TidalWordRanges
---@field range_start integer
---@field range_end integer
---@field function_name string
---@field quote_index integer
---

---@class TidalExtMark
---@field id? string
---@field buf integer
---@field markerId integer
---@field colStart integer
---@field colEnd integer
---@field row integer
---@field functionName string
---@field quoteIndex integer
---@field originalText string
---@field whole? TidalWhole

---@alias TidalExtMarkMap table<string, TidalExtMark>
---@alias TidalExtMarks table<integer, TidalExtMarkMap>
---
---
Marker.extMarks = {}
Marker.removeCandidates = {}

Marker.ns = vim.api.nvim_create_namespace("tidalEventHighlighting")

---Create all properties and metadata for ext marks
---@param ranges table<TidalWordRanges>
---@param lineNumber integer
---@param eventId integer
function Marker.createMarkers(ranges, lineNumber, eventId)
  local curr_buf = vim.api.nvim_get_current_buf()
  for _, value in ipairs(ranges) do
    Marker.extMarks = Marker.extMarks or {}
    Marker.extMarks[eventId] = Marker.extMarks[eventId] or {}

    if value.range_start > 0 then
      local line_text = vim.api.nvim_buf_get_lines(curr_buf, lineNumber - 1, lineNumber, false)[1] or ""
      local line_len = #line_text
      local safe_end_col = math.min(value.range_end, line_len)

      local markerId = vim.api.nvim_buf_set_extmark(curr_buf, Marker.ns, lineNumber - 1, value.range_start - 1, {
        end_row = lineNumber - 1,
        end_col = safe_end_col, -- until EOL
      })

      local originalText = vim.api.nvim_buf_get_text(
        curr_buf,
        lineNumber - 1,
        value.range_start - 1,
        lineNumber - 1,
        safe_end_col,
        {}
      )[1] or ""

      Marker.extMarks[eventId][value.range_start] = {
        buf = curr_buf,
        markerId = markerId,
        colStart = value.range_start - 1,
        colEnd = value.range_end,
        row = lineNumber - 1,
        functionName = value.function_name,
        quoteIndex = value.quote_index,
        originalText = originalText,
      } -- extmark
    end
  end
end

function Marker.countNsExtmarks()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      -- get all extmarks in this buffer for this namespace
      local marks = vim.api.nvim_buf_get_extmarks(buf, Marker.ns, 0, -1, {})
      count = count + #marks
    end
  end

  return count
end

--- Debug function to count all created extmarks
function Marker.count()
  local count = 0
  if Marker.extMarks then
    for _, markers in pairs(Marker.extMarks) do
      for _, _ in pairs(markers) do
        count = count + 1
      end
    end
  end

  return count
end

--- Debug function to print all created extmarks information
function Marker.print()
  if Marker.extMarks then
    for eventId, markers in pairs(Marker.extMarks) do
      for col, extmark in pairs(markers) do
        print(
          "MarkerId: "
            .. extmark.markerId
            .. " | eventId: "
            .. eventId
            .. " | Row: "
            .. extmark.row
            .. " | colStart: "
            .. extmark.colStart
            .. " | colEnd: "
            .. extmark.colEnd
            .. " | loopCol: "
            .. col
            .. " | functionName: "
            .. extmark.functionName
        )
      end
    end
  end
end

function Marker.deleteAllMarkers()
  -- Wiping complete namespace
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, Marker.ns, 0, -1)
    end
  end

  Marker.removeCandidates = {}
  Marker.extMarks = {} -- eventId -> col -> ExtMark
end

---Remove all markers within a given row range
---@param startRow integer
---@param endRow integer
function Marker.setRemovables(startRow, endRow)
  for eventId, markers in pairs(Marker.extMarks) do
    for col, extmark in pairs(markers) do
      local oldMarker = vim.api.nvim_buf_get_extmark_by_id(extmark.buf, Marker.ns, extmark.markerId, {})

      if oldMarker ~= nil then
        local row = oldMarker[1] + 1

        if row >= startRow and row <= endRow then
          table.insert(
            Marker.removeCandidates,
            { eventId = eventId, col = col, buf = extmark.buf, ns = Marker.ns, markerId = extmark.markerId }
          )
        end
      end
    end
  end
end

---Remove all markers within a given row range
function Marker.cleanUpMarkers()
  for _, extmark in ipairs(Marker.removeCandidates) do
    vim.api.nvim_buf_del_extmark(extmark.buf, extmark.ns, extmark.markerId)
    if Marker.extMarks[extmark.eventId] ~= nil then
      Marker.extMarks[extmark.eventId][extmark.col] = nil
    end
  end
end

return Marker

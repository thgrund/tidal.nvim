local Highlights = {}

local config = require("tidal.config")

local Marker = require("tidal.highlighting.marker")

local fn = vim.fn

local function selectHlGroup(id)
  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  local hlName = baseName .. id
  local hlId = fn.hlID(hlName)

  if hlId > 0 then
    return hlName
  else
    return baseName
  end
end

function Highlights.addHl(id, color)
  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  vim.api.nvim_set_hl(0, baseName .. id, { bg = color, foreground = "#000000" })
end

function Highlights.addConfigHl(id, style)
  local baseName = config.options.boot.tidal.highlight.styles.global.baseName
  vim.api.nvim_set_hl(0, baseName .. id, style)
end

function Highlights.addHighlight(id, buf, markerId)
  local extMark = vim.api.nvim_buf_get_extmark_by_id(buf, Marker.ns, markerId, { details = true })

  if #extMark > 0 and extMark[1] and extMark[2] then
    -- Create Highlight
    vim.api.nvim_buf_set_extmark(buf, Marker.ns, extMark[1], extMark[2], {
      end_col = extMark[3].end_col,
      id = markerId,
      hl_group = selectHlGroup(id),
      end_row = extMark[3].end_row,
    })
  end
end

function Highlights.addAllHighlights()
  for _, markers in pairs(Marker.extMarks) do
    for _, marker in pairs(markers) do
      local oldMarker = vim.api.nvim_buf_get_extmark_by_id(marker.buf, Marker.ns, marker.markerId, {})

      if oldMarker[2] > 0 then
        -- Create Highlight
        vim.api.nvim_buf_set_extmark(marker.buf, Marker.ns, oldMarker[1], oldMarker[2], {
          end_col = marker.colEnd,
          id = marker.markerId,
          hl_group = "CodeHighlight",
        })
      end
    end
  end
end

function Highlights.removeHighlight(buf, markerId)
  local extMark = vim.api.nvim_buf_get_extmark_by_id(buf, Marker.ns, markerId, { details = true })

  if #extMark > 0 and extMark[1] and extMark[2] then
    -- Create Highlight
    vim.api.nvim_buf_set_extmark(buf, Marker.ns, extMark[1], extMark[2], {
      end_col = extMark[3].end_col,
      id = markerId,
      hl_group = nil,
      end_row = extMark[3].end_row,
    })
  end
end

function Highlights.removeAllHighlights()
  for _, markers in pairs(Marker.extMarks.eventid) do
    for _, marker in pairs(markers) do
      local oldMarker = vim.api.nvim_buf_get_extmark_by_id(marker.buf, Marker.ns, marker.markerId, {})

      -- Delete Highlight
      vim.api.nvim_buf_set_extmark(marker.buf, Marker.ns, oldMarker[1], oldMarker[2], {
        end_col = marker.colEnd,
        id = marker.markerId,
        hl_group = nil,
      })
    end
  end
end

-- For testing
Highlights._selectHlGroup = selectHlGroup

return Highlights

--- @diagnostic disable: undefined-field
---
local Marker = require("tidal.highlighting.marker")
local eq = assert.are.same

describe("Marker", function()
  local buf

  before_each(function()
    -- Create a new scratch buffer and switch to it
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    -- Ensure clean state
    Marker.deleteAllMarkers()
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("createMarkers", function()
    it("creates extmarks and stores them internally", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'd1 $ s "bd sn"',
      })

      local ranges = {
        {
          range_start = 9,
          range_end = 10,
          function_name = "d1",
          quote_index = 1,
        },
        {
          range_start = 12,
          range_end = 13,
          function_name = "d1",
          quote_index = 1,
        },
      }

      Marker.createMarkers(ranges, 1, 1)

      -- internal count
      eq(2, Marker.count())

      -- namespace extmarks count
      eq(2, Marker.countNsExtmarks())

      -- verify stored metadata
      local markers = Marker.extMarks[1]
      eq("bd", markers[9].originalText)
      eq("sn", markers[12].originalText)

      eq(0, markers[9].row)
      eq(8, markers[9].colStart)
      eq(10, markers[9].colEnd)
      eq("d1", markers[9].functionName)
      eq(1, markers[9].quoteIndex)
    end)

    it("clamps end_col to line length", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'd1 $ s "bd"',
      })

      local ranges = {
        {
          range_start = 9,
          range_end = 100, -- intentionally too large
          function_name = "d1",
          quote_index = 1,
        },
      }

      Marker.createMarkers(ranges, 1, 1)

      eq(1, Marker.count())

      local markers = Marker.extMarks[1]
      eq('bd"', markers[9].originalText:sub(1, 3))
    end)
  end)

  describe("count and countNsExtmarks", function()
    it("returns zero when no markers exist", function()
      eq(0, Marker.count())
      eq(0, Marker.countNsExtmarks())
    end)

    it("counts markers across multiple events", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'd1 $ s "bd"',
        'd2 $ s "sn"',
      })

      Marker.createMarkers({
        { range_start = 9, range_end = 10, function_name = "d1", quote_index = 1 },
      }, 1, 1)

      Marker.createMarkers({
        { range_start = 9, range_end = 10, function_name = "d2", quote_index = 1 },
      }, 2, 2)

      eq(2, Marker.count())
      eq(2, Marker.countNsExtmarks())
    end)
  end)

  describe("deleteAllMarkers", function()
    it("removes all extmarks and clears internal state", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'd1 $ s "bd sn"',
      })

      Marker.createMarkers({
        { range_start = 9, range_end = 10, function_name = "d1", quote_index = 1 },
        { range_start = 12, range_end = 13, function_name = "d1", quote_index = 1 },
      }, 1, 1)

      eq(2, Marker.count())

      Marker.deleteAllMarkers()

      eq(0, Marker.count())
      eq(0, Marker.countNsExtmarks())
      eq({}, Marker.extMarks)
    end)
  end)

  describe("cleanUpMarkers", function()
    it("removes markers within a given row range", function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'd1 $ s "bd"',
        'd2 $ s "sn"',
        'd3 $ s "cp"',
      })

      Marker.createMarkers({ { range_start = 9, range_end = 10, function_name = "s", quote_index = 1 } }, 1, 1)
      Marker.createMarkers({ { range_start = 9, range_end = 10, function_name = "s", quote_index = 1 } }, 2, 2)
      Marker.createMarkers({ { range_start = 9, range_end = 10, function_name = "s", quote_index = 1 } }, 3, 3)

      eq(3, Marker.count())

      -- remove only line 2
      Marker.cleanUpMarkers(2, 2)

      eq(2, Marker.count())
      eq(2, Marker.countNsExtmarks())

      -- ensure remaining rows are 1 and 3
      local rows = {}
      for _, extmarks in pairs(Marker.extMarks) do
        for _, extmark in pairs(extmarks) do
          table.insert(rows, extmark.row + 1)
        end
      end
      table.sort(rows)

      eq({ 1, 3 }, rows)
    end)
  end)
end)

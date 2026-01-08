local Events = require("tidal.highlighting.events")

local eq = assert.are.same

local orig_schedule

local function sortEvents(list)
  table.sort(list, function(a, b)
    if a.buf ~= b.buf then
      return a.buf < b.buf
    end
    return a.markerId < b.markerId
  end)
end

describe("OSC", function()
  local osc
  local marker
  local highlight
  local losc_instances = {}

  before_each(function()
    losc_instances = {}
    -- Reset modules
    package.loaded["tidal.highlighting.osc"] = nil
    package.loaded["losc.src.losc"] = nil
    package.loaded["losc.src.losc.plugins.udp-libuv"] = nil
    package.loaded["tidal.highlighting.marker"] = nil
    package.loaded["tidal.highlighting.highlights"] = nil

    -- Track calls manually (luassert-style)
    local addHl_calls = {}

    -- Stub highlight module
    highlight = {
      addHl = function(id, color)
        table.insert(addHl_calls, { id = id, color = color })
      end,
      _calls = addHl_calls,
    }
    package.loaded["tidal.highlighting.highlights"] = highlight

    -- Stub marker module
    marker = {
      extMarks = {},
    }
    package.loaded["tidal.highlighting.marker"] = marker

    -- Stub libuv transport
    package.loaded["losc.src.losc.plugins.udp-libuv"] = {
      new = function()
        return {}
      end,
    }

    -- Stub losc and capture handlers
    package.loaded["losc.src.losc"] = {
      new = function()
        local instance = {
          handlers = {},
          add_handler = function(self, path, cb)
            self.handlers[path] = cb
          end,
          open = function() end,
        }
        table.insert(losc_instances, instance)
        return instance
      end,
    }

    osc = require("tidal.highlighting.osc")
    osc.messageBuffer = {}
    osc.activeMessages = {}

    orig_schedule = vim.schedule
    vim.schedule = function(fn)
      fn()
    end
  end)

  after_each(function()
    -- Restore vim.schedule
    vim.schedule = orig_schedule
  end)

  describe("diffEventLists", function()
    it("returns all events as added when previous list is empty", function()
      local curr = {
        { buf = 1, markerId = 10 },
        { buf = 1, markerId = 11 },
      }

      local diff = Events.diffEventLists({}, curr)

      sortEvents(diff.added)
      sortEvents(curr)

      eq({}, diff.removed)
      eq(curr, diff.added)
      eq({}, diff.active)
    end)

    it("returns all events as removed when current list is empty", function()
      local prev = {
        { buf = 1, markerId = 10 },
      }

      local diff = Events.diffEventLists(prev, {})

      eq(prev, diff.removed)
      eq({}, diff.added)
      eq({}, diff.active)
    end)

    it("detects active, added, and removed events", function()
      local prev = {
        { buf = 1, markerId = 10 },
        { buf = 1, markerId = 11 },
      }

      local curr = {
        { buf = 1, markerId = 11 },
        { buf = 2, markerId = 99 },
      }

      local diff = Events.diffEventLists(prev, curr)

      eq({ { buf = 1, markerId = 10 } }, diff.removed)
      eq({ { buf = 2, markerId = 99 } }, diff.added)
      eq({ { buf = 1, markerId = 11 } }, diff.active)
    end)
  end)

  describe("OSC event handler (/editor/highlights)", function()
    it("adds matching extmarks to messageBuffer", function()
      -- Arrange marker
      marker.extMarks[0] = {
        [5] = {
          buf = 1,
          markerId = 42,
        },
      }

      -- Launch OSC (registers handlers)
      osc.launch({
        events = { osc = { ip = "127.0.0.1", port = 9000 } },
        styles = { osc = { ip = "127.0.0.1", port = 9001 } },
      })

      local event_osc = losc_instances[1]
      local handler = event_osc.handlers["/editor/highlights"]
      assert(handler)

      handler({
        message = {
          99, -- id
          nil,
          nil,
          4, -- colStart (0-based, +1 in handler)
          1, -- eventId (1-based, -1 in handler)
        },
      })

      vim.wait(10, function()
        return #osc._messageBuffer == 1
      end)

      eq(1, #osc._messageBuffer)
      eq(99, osc._messageBuffer[1].id)
      eq(42, osc._messageBuffer[1].markerId)
    end)

    it("ignores messages without matching extmarks", function()
      osc.launch({
        events = { osc = { ip = "127.0.0.1", port = 9000 } },
        styles = { osc = { ip = "127.0.0.1", port = 9001 } },
      })

      local event_osc = losc_instances[1]
      local handler = event_osc.handlers["/editor/highlights"]
      assert(handler)

      handler({ message = { 1, nil, nil, 99, 5 } })

      vim.wait(10)

      eq({}, osc.messageBuffer)
    end)
  end)

  describe("OSC style handler (/neovim/eventhighlighting/addstyle)", function()
    it("forwards style messages to highlight.addHl", function()
      osc.launch({
        events = { osc = { ip = "127.0.0.1", port = 9000 } },
        styles = { osc = { ip = "127.0.0.1", port = 9001 } },
      })

      local event_osc = losc_instances[2]
      local handler = event_osc.handlers["/neovim/eventhighlighting/addstyle"]
      assert(handler)

      handler({
        message = {
          123,
          "#ff0000",
        },
      })

      vim.wait(10)

      eq(1, #highlight._calls)
      eq({ id = 123, color = "#ff0000" }, highlight._calls[1])
    end)
  end)
end)

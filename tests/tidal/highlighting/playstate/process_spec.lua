local orig_schedule

describe("PlayState", function()
  local playstate

  local eq = assert.are.same
  local ghciSend_called = false

  before_each(function()
    -- Stub vim.uv for timer testing (must be set up before any modules are loaded)
    package.loaded["vim.uv"] = {
      new_timer = function()
        return {
          started = false,
          closed = false,
          start = function(self, initial, repeat_interval, callback)
            self.started = true
            self.initial = initial
            self.repeat_interval = repeat_interval
            self.callback = callback
          end,
          stop = function(self)
            self.started = false
          end,
          close = function(self)
            self.closed = true
          end,
        }
      end,
      new_udp = function()
        return {
          bind = function()
            return true
          end,
          recv_start = function()
            return true
          end,
          recv_stop = function()
            return true
          end,
          close = function()
            return true
          end,
        }
      end,
    }

    package.loaded["tidal.core.state"] = {
      ghci = {
        send = function() end,
      },
    }

    -- Also stub vim.uv directly to ensure it's used by modules that cache it
    vim.uv = package.loaded["vim.uv"]

    playstate = require("tidal.highlighting.playstate.process")

    orig_schedule = vim.schedule
    vim.schedule = function(fn)
      fn()
    end
  end)

  after_each(function()
    -- Restore vim.schedule
    vim.schedule = orig_schedule
    ghciSend_called = false
  end)

  describe("timer functions", function()
    it("setInterval creates and starts a timer", function()
      playstate.setInterval(100)

      local timer = playstate.timer
      assert(timer ~= nil, "Timer should be created")
      assert(timer.started, "Timer should be started")
      assert(timer.initial == 100, "Timer should have correct initial interval")
      assert(timer.repeat_interval == 100, "Timer should have correct repeat interval")
    end)

    it("clearInterval stops and closes the timer", function()
      playstate.setInterval(100)
      local timer = playstate.timer

      playstate.clearInterval()

      assert(not timer.started, "Timer should be stopped")
      assert(timer.closed, "Timer should be closed")
      assert(playstate.timer == nil, "Timer reference should be cleared")
    end)

    it("clearInterval handles case when timer is nil", function()
      playstate.timer = nil

      assert.has_no.errors(function()
        playstate.clearInterval()
      end)
    end)
  end)

  describe("onDataProcessed", function()
    it("extract SAM correctly", function()
      local sam = { "SAM_START", "100 % 1", "SAM_END" }

      playstate._onDataProcessed(sam)

      eq(playstate.sam, 100)
    end)
    it("triggers getCurrent when SAM was received", function()
      local getCurrent_called = false
      local sam = { "SAM_START", "100 % 1", "SAM_END" }
      playstate.getCurrent = function()
        getCurrent_called = true
      end

      playstate._onDataProcessed(sam)
      assert.truthy(getCurrent_called)
    end)
    it("extract PLAYSTATE correctly", function()
      local state = {
        "PLAYSTATE_START",
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,2),(27,2)),((38,2),(39,2))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        "PLAYSTATE_END",
      }

      playstate._onDataProcessed(state)

      eq(playstate._lastReceivedPlayState, {
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,2),(27,2)),((38,2),(39,2))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
      })
    end)
  end)
end)

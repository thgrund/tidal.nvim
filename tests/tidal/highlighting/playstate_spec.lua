local orig_schedule

describe("PlayState", function()
  local playstate
  before_each(function()
    -- Reset modules
    package.loaded["tidal.highlighting.osc"] = nil

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

    -- Also stub vim.uv directly to ensure it's used by modules that cache it
    vim.uv = package.loaded["vim.uv"]

    playstate = require("tidal.highlighting.playstate")

    orig_schedule = vim.schedule
    vim.schedule = function(fn)
      fn()
    end
  end)

  after_each(function()
    -- Restore vim.schedule
    vim.schedule = orig_schedule
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
end)

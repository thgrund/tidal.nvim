--- @diagnostic disable: undefined-field

local orig_schedule

describe("PlayState", function()
  local process
  local parser

  local eq = assert.are.same

  before_each(function()
    -- Stub vim.uv for timer testing (must be set up before any modules are loaded)
    package.loaded["tidal.core.state"] = {
      ghci = {
        send = function() end,
      },
    }

    process = require("tidal.highlighting.playstate.process")
    parser = require("tidal.highlighting.playstate.parser")

    process._currentPlayState = {}
    process._lastReceivedPlayState = {}
  end)

  after_each(function()
    -- Restore vim.schedule
    vim.schedule = orig_schedule
  end)

  describe("onDataProcessed", function()
    it("extract SAM correctly", function()
      local sam = { "SAM_START", "100 % 1", "SAM_END" }

      process.onDataProcessed(sam)

      eq(process.sam, 100)
    end)

    it("extract SAM with fraction correctly", function()
      local sam = { "SAM_START", "1 % 3", "SAM_END" }

      process.onDataProcessed(sam)

      eq(process.sam, (1 / 3))
    end)

    it("triggers getPlayState with LOCK_INIT_PLAYSTATE when sam was received and currentPlaystate is empty", function()
      local getLockName = nil
      local getStart = nil
      local getStop = nil

      local expectedStart = 100
      local expectedStop = 104

      process.getPlayState = function(start, stop, lockName)
        getStart = start
        getStop = stop
        getLockName = lockName
      end

      local sam = { "SAM_START", "100 % 1", "SAM_END" }
      process.reset()
      process.onDataProcessed(sam)

      eq(getLockName, "INIT_PLAYSTATE")
      eq(getStart, expectedStart)
      eq(getStop, expectedStop)
    end)

    it(
      "triggers getPlayState with LOCK_EXTEND_PLAYSTATE when sam was received and currentPlaystate is filled",
      function()
        local getStart = nil
        local getStop = nil

        local expectedStart = 103
        local expectedStop = 104

        local getLockName = nil
        process.getPlayState = function(start, stop, lockName)
          getStart = start
          getStop = stop
          getLockName = lockName
        end

        local state = {
          "INIT_PLAYSTATE_START",
          '[((8,2),(18,2)),((30,2),(31,2))](100>101)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
          "INIT_PLAYSTATE_END",
        }
        process.onDataProcessed(state)

        local sam = { "SAM_START", "100 % 1", "SAM_END" }
        process.sam = 99
        process.onDataProcessed(sam)

        eq(getLockName, "EXTEND_PLAYSTATE")
        eq(getStart, expectedStart)
        eq(getStop, expectedStop)
      end
    )

    it("triggers getPlayState when next SAM was received", function()
      local getCurrent_called = false
      local sam = { "SAM_START", "100 % 1", "SAM_END" }
      process.getPlayState = function(_, _, _)
        getCurrent_called = true
      end

      process.sam = 99

      process.onDataProcessed(sam)
      assert.truthy(getCurrent_called)
    end)
    it("do not triggers getPlayState when same SAM but with fraction was received", function()
      local getCurrent_called = false
      local sam = { "SAM_START", "501 % 5 ", "SAM_END" }
      process.getPlayState = function(_, _, _)
        getCurrent_called = true
      end

      process.sam = 100

      process.onDataProcessed(sam)
      assert.falsy(getCurrent_called)
    end)
    it("do not triggers getPlayState when same SAM but with fraction over > .5 was received", function()
      local getCurrent_called = false
      local sam = { "SAM_START", " 503 % 5 ", "SAM_END" }
      process.getPlayState = function(_, _, _)
        getCurrent_called = true
      end

      process.sam = 100

      process.onDataProcessed(sam)
      assert.falsy(getCurrent_called)
    end)

    it("extract INIT_PLAYSTATE correctly", function()
      local state = {
        "INIT_PLAYSTATE_START",
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,2),(27,2)),((38,2),(39,2))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }

      process.onDataProcessed(state)

      eq(process._lastReceivedPlayState, {
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,2),(27,2)),((38,2),(39,2))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
      })
    end)

    it("handles empty INIT_PLAYSTATE correctly", function()
      local state = {
        "INIT_PLAYSTATE_START",
        "INIT_PLAYSTATE_END",
      }

      process.onDataProcessed(state)

      eq(process._lastReceivedPlayState, {})
      eq(next(process._lastReceivedPlayState), nil)
    end)

    it("Overrided the playstate when INIT_PLAYSTART was received", function()
      local testMe
      local initState = {
        "INIT_PLAYSTATE_START",
        '[((8,2),(18,2)))](0>1)|_id_: "1", orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }

      local eventIds = { "XRKUfOvTA", "UIhicEQF1" }
      parser.genEventId = function()
        local eventId = eventIds[1]
        table.remove(eventIds, 1)
        return eventId
      end

      process.onDataProcessed(initState)

      testMe = { ["XRKUfOvTA"] = { colStart = 9, eventId = 1, id = "1", whole = { start = 0, stop = 1 } } }

      eq(process._currentPlayState, testMe)

      local extendState = {
        "INIT_PLAYSTATE_START",
        '[((17,3),(27,3))]0-(1>2)-3|_id_: "2", orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }

      process.onDataProcessed(extendState)
      testMe = {
        ["UIhicEQF1"] = { colStart = 18, eventId = 2, id = "2", whole = { start = 0, stop = 3 } },
      }
      eq(process._currentPlayState, testMe)
    end)

    it("Updates the initial playstate when EXTEND_PLAYSTATE was received", function()
      local testMe

      local initState = {
        "INIT_PLAYSTATE_START",
        '[((8,2),(18,2)))](0>1)|_id_: "1", orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }

      local eventIds = { "XRKUfOvTA", "UIhicEQF1" }
      parser.genEventId = function()
        local eventId = eventIds[1]
        table.remove(eventIds, 1)
        return eventId
      end

      process.onDataProcessed(initState)

      testMe = { ["XRKUfOvTA"] = { colStart = 9, eventId = 1, id = "1", whole = { start = 0, stop = 1 } } }

      eq(process._currentPlayState, testMe)

      local extendState = {
        "EXTEND_PLAYSTATE_START",
        '[((17,3),(27,3))]0-(1>2)-3|_id_: "2", orbit: 0, s: "superpiano"',
        "EXTEND_PLAYSTATE_END",
      }

      process.onDataProcessed(extendState)

      testMe = {
        ["XRKUfOvTA"] = { colStart = 9, eventId = 1, id = "1", whole = { start = 0, stop = 1 } },
        ["UIhicEQF1"] = { colStart = 18, eventId = 2, id = "2", whole = { start = 0, stop = 3 } },
      }

      eq(process._currentPlayState, testMe)
    end)
  end)

  describe("parse", function()
    it("should return the expected parsed events", function()
      local plain = {
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,3),(27,3)),((38,3),(39,3))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,4),(29,4)),((40,4),(41,4))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,5),(29,5)),((40,5),(41,5))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
      }

      local count = 0

      parser.genEventId = function()
        count = count + 1
        return count
      end

      process.parse(plain)

      eq(count, 8)
    end)

    it("should return the expected parsed events within one are", function()
      local plain = {
        '[((8,2),(18,2)),((30,2),(31,2))](0>0.5)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,3),(27,3)),((38,3),(39,3))](0.5>1)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
      }

      local count = 0

      parser.genEventId = function()
        count = count + 1
        return count
      end

      process.parse(plain)

      eq(count, 4)
    end)
  end)

  describe("diff", function()
    it("should add past events to removed", function()
      local prevActive = {
        ["2-8"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["2-30"] = {
          id = "1",
          eventId = 2,
          colStart = 30,
          whole = {
            start = 0,
            stop = 1,
          },
        },
      }

      local current = prevActive

      local futureSam = 2

      local testme = process._diff(futureSam, prevActive, current)

      table.sort(testme.remove)
      table.sort(testme.add)
      table.sort(testme.active)

      local expected = { remove = { "2-30", "2-8" }, add = {}, active = {} }

      table.sort(expected.remove)
      table.sort(expected.add)
      table.sort(expected.active)

      eq(testme, expected)
    end)

    it(
      "should add current events to add, if they are not in prevActive but in current and whole is within now",
      function()
        local prevActive = {
          ["2-8"] = {
            id = "1",
            eventId = 2,
            colStart = 8,
            whole = {
              start = 0,
              stop = 1,
            },
          },
        }
        local current = {
          ["2-8"] = {
            id = "1",
            eventId = 2,
            colStart = 8,
            whole = {
              start = 0,
              stop = 1,
            },
          },
          ["2-30"] = {
            id = "1",
            eventId = 2,
            colStart = 30,
            whole = {
              start = 0,
              stop = 1,
            },
          },
        }

        local testme = process._diff(0.5, prevActive, current)
        local expected = { remove = {}, add = { "2-30" }, active = { "2-8" } }

        eq(testme, expected)
      end
    )

    it("should add current events to active, if they are in prevActive and whole is within now", function()
      local prevActive = {
        ["2-8"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["2-30"] = {
          id = "1",
          eventId = 2,
          colStart = 30,
          whole = {
            start = 0,
            stop = 1,
          },
        },
      }

      local current = prevActive

      local testme = process._diff(0.5, prevActive, current)
      table.sort(testme.remove)
      table.sort(testme.add)
      table.sort(testme.active)

      local expected = { remove = {}, add = {}, active = { "2-8", "2-30" } }
      table.sort(expected.remove)
      table.sort(expected.add)
      table.sort(expected.active)

      eq(testme, expected)
    end)
  end)
end)

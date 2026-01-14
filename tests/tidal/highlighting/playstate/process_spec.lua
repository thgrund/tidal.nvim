--- @diagnostic disable: undefined-field

local orig_schedule

describe("PlayState", function()
  local process

  local eq = assert.are.same

  before_each(function()
    -- Stub vim.uv for timer testing (must be set up before any modules are loaded)
    package.loaded["tidal.core.state"] = {
      ghci = {
        send = function() end,
      },
    }

    process = require("tidal.highlighting.playstate.process")
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

    it("Overrided the playstate when INIT_PLAYSTART was received", function()
      local testMe
      local initState = {
        "INIT_PLAYSTATE_START",
        '[((8,2),(18,2)))](0>1)|_id_: "1", orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }
      process.onDataProcessed(initState)

      testMe = { { colStart = 8, eventId = 2, id = "1", whole = { start = 0, stop = 1 } } }

      eq(process._currentPlayState, testMe)

      local extendState = {
        "INIT_PLAYSTATE_START",
        '[((17,3),(27,3))]0-(1>2)-3|_id_: "2", orbit: 0, s: "superpiano"',
        "INIT_PLAYSTATE_END",
      }

      process.onDataProcessed(extendState)
      testMe = {
        { colStart = 17, eventId = 3, id = "2", whole = { start = 0, stop = 3 } },
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
      process.onDataProcessed(initState)

      testMe = { { colStart = 8, eventId = 2, id = "1", whole = { start = 0, stop = 1 } } }

      eq(process._currentPlayState, testMe)

      local extendState = {
        "EXTEND_PLAYSTATE_START",
        '[((17,3),(27,3))]0-(1>2)-3|_id_: "2", orbit: 0, s: "superpiano"',
        "EXTEND_PLAYSTATE_END",
      }

      process.onDataProcessed(extendState)
      testMe = {
        { colStart = 8, eventId = 2, id = "1", whole = { start = 0, stop = 1 } },
        { colStart = 17, eventId = 3, id = "2", whole = { start = 0, stop = 3 } },
      }
      eq(process._currentPlayState, testMe)
    end)
  end)

  describe("parse", function()
    it("should return the expected parsed events", function()
      local plain = {
        '[((8,2),(18,2)),((30,2),(31,2))](0>1)|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
        '[((17,2),(27,2)),((38,2),(39,2))]0-(1>2)-3|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))]0-(2>2½)|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
        '[((19,2),(29,2)),((40,2),(41,2))](2½>3)-5|_id_: "1", note: 9.0n (a5), orbit: 0, s: "superpiano"',
      }

      local testMe = process.parse(plain)

      eq(#testMe, 8)
    end)
  end)
end)

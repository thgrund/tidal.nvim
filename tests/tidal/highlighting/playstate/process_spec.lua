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

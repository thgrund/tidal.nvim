--- @diagnostic disable: undefined-field

local orig_schedule

describe("PlayState", function()
  local process
  local parser

  local eq = assert.are.same

  before_each(function()
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
        "1,[(8,2)],0,1,1,1,0,1,superpiano",
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
        "2,[(17,3)],0,1,3,1,0,1,superpiano",
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
        "1,[(8,2)],0,1,1,1,0,1,superpiano",
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
        "2,[(17,3)],0,1,3,1,0,1,superpiano",
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
        "1,[(1,1),(2,1)],0,1,1,1,0,1,superpiano",
        "2,[(3,2),(2,2)],1,1,2,1,0,1,superpiano",
        "3,[(5,3),(5,3)],2,1,3,1,0,1,superpiano",
        "4,[(7,4),(7,4)],3,1,4,1,0,1,superpiano",
      }

      local count = 0

      parser.genEventId = function()
        count = count + 1
        return count
      end

      process.parse(plain)

      eq(count, 8)
    end)

    it("should return the expected parsed events within one arc", function()
      local plain = {
        "1,[(1,1),(2,1)],0,1,1,2,0,1,superpiano",
        "2,[(3,2),(2,2)],1,1,1,1,9,1,superpiano",
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

    it("should handle same events over time correctly", function()
      local prevActive = {
        ["past"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["present"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 1,
            stop = 2,
          },
        },
      }

      local current = {
        ["past"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["present"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 1,
            stop = 2,
          },
        },
        ["future"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 2,
            stop = 3,
          },
        },
      }

      local testme = process._diff(1.200000, prevActive, current)
      local expected = { remove = { "past" }, add = {}, active = { "present" } }

      eq(testme, expected)
    end)
    it("should keep active events, when current is empty", function()
      local prevActive = {
        ["past"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["present"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 1,
            stop = 2,
          },
        },
      }

      local current = {}

      local testme = process._diff(1.200000, prevActive, current)
      local expected = { remove = {}, add = {}, active = {} }

      eq(testme, expected)
    end)
  end)

  describe("updateActives", function()
    it("should update the active id, when current has the same event with a different id", function()
      local active = {
        ["old"] = {
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
        ["new"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
      }

      local testme = process._updateActive(active, current)
      local expected = { active = current, removable = {} }

      eq(testme, expected)
    end)
    it("should marke the active id as removable, when current hasn't the same event with a different id", function()
      local active = {
        ["old"] = {
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
        ["new"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 1,
            stop = 2,
          },
        },
      }

      local testme = process._updateActive(active, current)
      local expected = { active = {}, removable = active }

      eq(testme, expected)
    end)
    it("should keep the active empty, regardless what is in current", function()
      local active = {}
      local current = {
        ["event1"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["event2"] = {
          id = "1",
          eventId = 2,
          colStart = 8,
          whole = {
            start = 1,
            stop = 2,
          },
        },
      }

      local testme = process._updateActive(active, current)
      local expected = { removable = {}, active = {} }

      eq(testme, expected)
    end)
  end)

  -- describe("currentToJSON", function()
  --   it("should transform playstate correctly with extmark enrichment", function()
  --     local state = {
  --       "INIT_PLAYSTATE_START",
  --       '[((8,2),(18,2)),((30,2),(31,2))]((0,0/1)<(1,0/1))|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"',
  --       "INIT_PLAYSTATE_END",
  --     }
  --     marker.extMarks[1] = {}

  --     marker.extMarks[1][9] = {
  --       functionName = "s",
  --       originalText = "superpiano",
  --     }
  --     marker.extMarks[1][31] = {
  --       functionName = "note",
  --       originalText = "0.0",
  --     }

  --     process.onDataProcessed(state)

  --     local expected =
  --       '[{"colStart": 9,"eventId": 1,"fun": "s","id": "1","val": "superpiano","whole": {"start": 0,"stop": 1}},{"colStart": 31,"eventId": 1,"fun": "note","id": "1","val": "0.0","whole": {"start": 0,"stop": 1}}]'
  --     local testme = process.currentToJSON(process._currentPlayState)

  --     eq(expected, testme)
  --   end)
  -- end)
end)

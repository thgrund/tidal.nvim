describe("Events module tests", function()
  local Events = require("tidal.highlighting.events")

  local eq = assert.are.same

  describe("merge function", function()
    it("should merge two tables correctly", function()
      local t1 = { 1, 2, 3 }
      local t2 = { 4, 5, 6 }
      local result = Events.merge(t1, t2)
      eq({ 1, 2, 3, 4, 5, 6 }, result)
    end)

    it("should handle empty tables", function()
      local t1 = {}
      local t2 = {}
      local result = Events.merge(t1, t2)
      eq({}, result)
    end)
  end)

  describe("diffEventLists function", function()
    it("should identify added events", function()
      local prevEvents = {
        { buf = 1, markerId = "a", other = "data" },
      }
      local currentEvents = {
        { buf = 1, markerId = "a", other = "data" },
        { buf = 1, markerId = "b", other = "new" },
      }
      local result = Events.diffEventLists(prevEvents, currentEvents)
      eq(1, #result.added)
      eq("b", result.added[1].markerId)
    end)

    it("should identify removed events", function()
      local prevEvents = {
        { buf = 1, markerId = "a", other = "data" },
        { buf = 1, markerId = "b", other = "old" },
      }
      local currentEvents = {
        { buf = 1, markerId = "a", other = "data" },
      }
      local result = Events.diffEventLists(prevEvents, currentEvents)
      eq(1, #result.removed)
      eq("b", result.removed[1].markerId)
    end)

    it("should identify active events", function()
      local prevEvents = {
        { buf = 1, markerId = "a", other = "data" },
        { buf = 1, markerId = "b", other = "old" },
      }
      local currentEvents = {
        { buf = 1, markerId = "a", other = "data" },
        { buf = 1, markerId = "b", other = "new" },
      }
      local result = Events.diffEventLists(prevEvents, currentEvents)
      eq(2, #result.active)
    end)

    it("should handle empty event lists", function()
      local result = Events.diffEventLists({}, {})
      eq(0, #result.added)
      eq(0, #result.removed)
      eq(0, #result.active)
    end)
  end)
end)

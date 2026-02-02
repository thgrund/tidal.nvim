--- @diagnostic disable: undefined-field

local eq = assert.are.same

describe("PlayStateParser", function()
  local playStateParser

  before_each(function()
    playStateParser = require("tidal.highlighting.playstate.parser")
  end)

  describe("mapPos", function()
    it("should map one pair of tuples correctly", function()
      eq(playStateParser.mapPos("[((8,2),(18,2))]"), { { 8, 2 }, { 18, 2 } })
    end)
    it("should map two pairs of tuples correctly", function()
      eq(playStateParser.mapPos("[((8,2),(18,2)),((30,2),(31,2))]"), { { 8, 2 }, { 18, 2 }, { 30, 2 }, { 31, 2 } })
    end)
  end)

  describe("extract", function()
    it("should map playstate within one circle correctly", function()
      local plain = '[((8,2),(18,2))]((0,0/1)<(1,0/1))|_id_: "1",orbit: 0, s: "superpiano"'

      local testMe = playStateParser.extract(plain)
      local expected = { "[((8,2),(18,2))]", "((0,0/1)<(1,0/1))", "1" }

      eq(testMe, expected)
    end)

    it("should map multiple events within one cycle", function()
      local plain =
        '[((8,2),(18,2)),((30,2),(31,2))]((0,0/1)<(1,0/1))|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"'

      local testMe = playStateParser.extract(plain)
      local expected = { "[((8,2),(18,2)),((30,2),(31,2))]", "((0,0/1)<(1,0/1))", "1" }

      eq(testMe, expected)
    end)

    it("should map event with past start and future stop correctly", function()
      local plain = '[((8,2),(18,2))](0,0/1)-((1,0/1)<(2,0/1))-(3,0/1)|_id_: "1", orbit: 0, s: "superpiano"'

      local testMe = playStateParser.extract(plain)
      local expected = { "[((8,2),(18,2))]", "(0,0/1)-((1,0/1)<(2,0/1))-(3,0/1)", "1" }

      eq(testMe, expected)
    end)

    it("should map event with past start correctly", function()
      local plain = '[((8,2),(18,2)))](0,0/1)-((2,0/1)<(2,1/2))|_id_: "1", orbit: 0, s: "superpiano"'

      local testMe = playStateParser.extract(plain)
      local expected = { "[((8,2),(18,2)))]", "(0,0/1)-((2,0/1)<(2,1/2))", "1" }

      eq(testMe, expected)
    end)
    it("should map event with future stop correctly", function()
      local plain = '[((8,2),(18,2))]((2,1/2)<(3,0/1))-(5,0/1)|_id_: "1", orbit: 0, s: "superpiano"'

      local testMe = playStateParser.extract(plain)
      local expected = { "[((8,2),(18,2))]", "((2,1/2)<(3,0/1))-(5,0/1)", "1" }

      eq(testMe, expected)
    end)
  end)

  describe("mapWhole", function()
    it("should map whole within a cycle", function()
      -- local old = "(0>1)"
      local plain = "((0,0/1)<(1,0/1))"
      local testMe = playStateParser.mapWhole(plain)
      local expected = { start = 0, stop = 1 }

      eq(expected, testMe)
    end)

    it("should map whole with past start and future stop", function()
      --local old = "0-(1>2)-3"
      local plain = "(0,0/1)-((1,0/1)<(2,0/1))-(3,0/1)"
      local testMe = playStateParser.mapWhole(plain)
      local expected = { start = 0, stop = 3 }

      eq(expected, testMe)
    end)
    it("should map whole within past start", function()
      -- local old = "0-(2>2½)"
      local plain = "(0,0/1)-((2,0/1)<(2,1/2))"
      local testMe = playStateParser.mapWhole(plain)
      local expected = { start = 0, stop = 2.5 }

      eq(expected, testMe)
    end)
    it("should map whole within future stop", function()
      --local old = "(2½>3)-5"
      local plain = "((2,1/2)<(3,0/1))-(5,0/1)"
      local testMe = playStateParser.mapWhole(plain)
      local expected = { start = 2.5, stop = 5 }

      eq(expected, testMe)
    end)
  end)

  describe("parse", function()
    it("should map single event within one cycle", function()
      local plain = '[((8,2),(18,2))]((0,0/1)<(1,0/1))|_id_: "1",orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["lp5tew5bP"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0,
            stop = 1,
          },
        },
      }

      eq(passedIn, expected)
    end)

    it("should map multiple events within one cycle", function()
      local plain = '[((8,2),(18,2)),((30,2),(31,2))]((0,0/1)<(1,0/1))|_id_: "1"'

      local eventIds = { "XRKUfOvTA", "UIhicEQF1" }

      playStateParser.genEventId = function()
        local eventId = eventIds[1]
        table.remove(eventIds, 1)
        return eventId
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["XRKUfOvTA"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0,
            stop = 1,
          },
        },
        ["UIhicEQF1"] = {
          id = "1",
          eventId = 1,
          colStart = 31,
          whole = {
            start = 0,
            stop = 1,
          },
        },
      }

      eq(passedIn, expected)
    end)
    it("should map event with past start and future stop correctly", function()
      local plain = '[((8,2),(18,2)))](0,0/1)-((1,0/1)<(2,0/1))-(3,0/1)|_id_: "1", orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["lp5tew5bP"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0,
            stop = 3,
          },
        },
      }

      eq(passedIn, expected)
    end)

    it("should map event with fractional at the end of current correctly", function()
      local plain = '[((8,2),(18,2)))]((0,7/8)<(0,15/16))|_id_: "1", orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["lp5tew5bP"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0.875,
            stop = 0.9375,
          },
        },
      }

      eq(passedIn, expected)
    end)
    it("should map event with fractional at the start of current correctly", function()
      local plain = '[((8,2),(18,2)))]((0,15/16)<(1,0/1))|_id_: "1", orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["lp5tew5bP"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0.9375,
            stop = 1,
          },
        },
      }

      eq(passedIn, expected)
    end)

    it("should map event with past start correctly", function()
      local plain = '[((8,2),(18,2)))](0,0/1)-((2,0/1)<(2,1/2))|_id_: "1", orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "iZKbZdZMZ"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["iZKbZdZMZ"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 0,
            stop = 2.5,
          },
        },
      }

      eq(passedIn, expected)
    end)

    it("should map event with future stop correctly", function()
      local plain = '[((8,2),(18,2)))]((2,1/2)<(3,0/1))-(5,0/1)|_id_: "1", orbit: 0, s: "superpiano"'

      playStateParser.genEventId = function()
        return "Jhd8Rk8rv"
      end

      local passedIn = playStateParser.parse(plain)

      local expected = {
        ["Jhd8Rk8rv"] = {
          id = "1",
          eventId = 1,
          colStart = 9,
          whole = {
            start = 2.5,
            stop = 5,
          },
        },
      }

      eq(passedIn, expected)
    end)
  end)
end)

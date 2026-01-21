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

  describe("replaceFractions", function()
    it("should map ½ to .5", function()
      local testMe = playStateParser._replaceFractions("½")
      local expected = ".5"

      eq(testMe, expected)
    end)
    it("should map 2½ to 2.5", function()
      local testMe = playStateParser._replaceFractions("2½")
      local expected = "2.5"

      eq(testMe, expected)
    end)
    it("should map ⅓ to .333", function()
      local testMe = playStateParser._replaceFractions("⅓")
      local expected = ".333"

      eq(testMe, expected)
    end)
    it("should map 3⅓ to 3.333", function()
      local testMe = playStateParser._replaceFractions("3⅓")
      local expected = "3.333"

      eq(testMe, expected)
    end)
    it("should map ⅔ to .666", function()
      local testMe = playStateParser._replaceFractions("⅔")
      local expected = ".666"

      eq(testMe, expected)
    end)
    it("should map ¼ to .25", function()
      local testMe = playStateParser._replaceFractions("¼")
      local expected = ".25"

      eq(testMe, expected)
    end)
    it("should map ¾ to .75", function()
      local testMe = playStateParser._replaceFractions("¾")
      local expected = ".75"

      eq(testMe, expected)
    end)
    it("should map ⅕ to .2", function()
      local testMe = playStateParser._replaceFractions("⅕")
      local expected = ".2"

      eq(testMe, expected)
    end)
    it("should map ⅖ to .4", function()
      local testMe = playStateParser._replaceFractions("⅖")
      local expected = ".4"

      eq(testMe, expected)
    end)
    it("should map ⅗ to .6", function()
      local testMe = playStateParser._replaceFractions("⅗")
      local expected = ".6"

      eq(testMe, expected)
    end)
    it("should map ⅘ to .8", function()
      local testMe = playStateParser._replaceFractions("⅘")
      local expected = ".8"

      eq(testMe, expected)
    end)
    it("should map ⅙ to .166", function()
      local testMe = playStateParser._replaceFractions("⅙")
      local expected = ".166"

      eq(testMe, expected)
    end)
    it("should map ⅚ to .833", function()
      local testMe = playStateParser._replaceFractions("⅚")
      local expected = ".833"

      eq(testMe, expected)
    end)
    it("should map ⅐ to .142", function()
      local testMe = playStateParser._replaceFractions("⅐")
      local expected = ".142"

      eq(testMe, expected)
    end)
    it("should map ⅛ to .125", function()
      local testMe = playStateParser._replaceFractions("⅛")
      local expected = ".125"

      eq(testMe, expected)
    end)
    it("should map ⅜ to .375", function()
      local testMe = playStateParser._replaceFractions("⅜")
      local expected = ".375"

      eq(testMe, expected)
    end)
    it("should map ⅝ to .625", function()
      local testMe = playStateParser._replaceFractions("⅝")
      local expected = ".625"

      eq(testMe, expected)
    end)
    it("should map ⅞ to .875", function()
      local testMe = playStateParser._replaceFractions("⅞")
      local expected = ".875"

      eq(testMe, expected)
    end)
    it("should map ⅑ to .111", function()
      local testMe = playStateParser._replaceFractions("⅑")
      local expected = ".111"

      eq(testMe, expected)
    end)
    it("should map ⅒ to .1", function()
      local testMe = playStateParser._replaceFractions("⅒")
      local expected = ".1"

      eq(testMe, expected)
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
      local plain =
        '[((8,2),(18,2)),((30,2),(31,2))]((0,0/1)<(1,0/1))|_id_: "1", note: 0.0n (c5), orbit: 0, s: "superpiano"'

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

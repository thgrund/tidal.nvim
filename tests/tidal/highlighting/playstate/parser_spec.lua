--- @diagnostic disable: undefined-field

local eq = assert.are.same

describe("PlayStateParser", function()
  local playStateParser

  before_each(function()
    playStateParser = require("tidal.highlighting.playstate.parser")
  end)

  -- id       ctx          ws    we    note     sound
  -- 2,  [(8,2),(29,2)],  2,1,  3,1,   4,1,   superpiano

  describe("mapCtx", function()
    it("should map one tuple correctly", function()
      eq(playStateParser.mapCtx("[(8,2)]"), { { 8, 2 } })
    end)
    it("should map three tuples correctly", function()
      eq(playStateParser.mapCtx("[(8,2),(18,2),(32,3)]"), { { 8, 2 }, { 18, 2 }, { 32, 3 } })
    end)
  end)

  describe("mapEvent", function()
    it("should map single event within one cycle", function()
      local plain = "1,[(8,2)],0,1,1,1,0,1,superpiano"

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2),(30,2)],0,1,1,1,0,1,superpiano"

      local eventIds = { "XRKUfOvTA", "UIhicEQF1" }

      playStateParser.genEventId = function()
        local eventId = eventIds[1]
        table.remove(eventIds, 1)
        return eventId
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2)],0,1,3,1,0,1,superpiano"

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2)],7,8,15,16,0,1,superpiano"

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2)],15,16,1,1,1,superpiano"

      playStateParser.genEventId = function()
        return "lp5tew5bP"
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2)],0,1,5,2,1,superpiano"

      playStateParser.genEventId = function()
        return "iZKbZdZMZ"
      end

      local passedIn = playStateParser.mapEvent(plain)

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
      local plain = "1,[(8,2)],5,2,5,1,1,superpiano"

      playStateParser.genEventId = function()
        return "Jhd8Rk8rv"
      end

      local passedIn = playStateParser.mapEvent(plain)

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

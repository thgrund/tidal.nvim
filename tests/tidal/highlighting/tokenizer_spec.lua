---
-- Unit tests for the tokenizer module
-- @diagnostic disable: undefined-field

local Tokenizer = require("tidal.highlighting.tokenizer")

local eq = assert.are.same

describe("Tokenizer", function()
  describe("addDeltaContext function", function()
    before_each(function()
      -- Reset the event ID before each test
      Tokenizer.lastEventId = 0
    end)

    it("should transform control patterns into deltaContext format", function()
      -- Mock the control patterns to match a simple pattern
      local result = Tokenizer.addDeltaContext('d1 $ s "bd"', 1)

      -- Should contain deltaContext with event ID 1
      eq(string.find(result, "deltaContext") ~= nil, true)
      eq(string.find(result, "1") ~= nil, true) -- Event ID should be 1
    end)

    it("should wrap content in quotes when excepted patterns are found", function()
      local result = Tokenizer.addDeltaContext('d1 $ s "bd"', 1)

      -- Should wrap content in quotes
      eq(string.find(result, '"bd"') ~= nil, true)
    end)

    it("should leave lines without control patterns unchanged", function()
      local original = "regular line without patterns"
      local result = Tokenizer.addDeltaContext(original, 1)

      -- Should remain unchanged
      eq(result, "regular line without patterns")
    end)

    it("should handle empty lines", function()
      local result = Tokenizer.addDeltaContext("", 1)
      eq(result, "")
    end)

    it("should use the provided event ID in deltaContext", function()
      -- Test with event ID 42
      local result = Tokenizer.addDeltaContext('d1 $ s "bd"', 42)

      -- Should contain event ID 42
      eq(string.find(result, "42") ~= nil, true)
    end)

    it("should handle multiple control patterns in one line", function()
      local result = Tokenizer.addDeltaContext('d1 $ s "bd" # n "0"', 1)

      -- Should contain multiple deltaContext entries
      local deltaCount = select(2, string.gsub(result, "deltaContext", "deltaContext"))
      eq(deltaCount >= 2, true)
    end)

    it("should ignore lines that start with a colon", function()
      local result = Tokenizer.addDeltaContext(':load "test.hs"', 1)

      local deltaCount = select(2, string.gsub(result, "deltaContext", "deltaContext"))
      assert.truthy(deltaCount == 0)
    end)
  end)
end)

--- @diagnostic disable: undefined-field
local playstate = require("tidal.highlighting.playstate")

local eq = assert.are.same

describe("PlayState", function()
  before_each(function()
    -- Clear the module cache to ensure we get a fresh start
    package.loaded["tidal.core.state"] = nil
    package.loaded["tidal.highlighting.playstate"] = nil
    package.loaded["tidal.highlighting.playstate.process"] = nil

    -- Create a complete mock of the tidal.core.state module
    package.loaded["tidal.core.state"] = {
      ghci = {
        stdin = {
          write = function(val)
            return val
          end,
        },
        onDataProcessed = function() end, -- Required by playstate.launch
        sendCallback = function() end, -- Required by playstate.launch
      },
    }

    -- Reload the playstate module with the mocked state
    playstate = require("tidal.highlighting.playstate")
  end)

  describe("launch", function()
    it("sends the clock to stdin with the correct fps that was passed", function()
      local actual
      local expected = [[clock "1*60"]]

      -- Override the write function to capture the value
      package.loaded["tidal.core.state"].ghci.stdin.write = function(_, val)
        actual = val
        return val -- Return the value to match the original behavior
      end

      playstate.launch({ highlightCallback = function() end, fps = 60 })
      eq(expected, actual)
    end)
  end)
end)

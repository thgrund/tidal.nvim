local Ghci = require("tidal.repl.ghci")
local Sclang = require("tidal.repl.sclang")
local state = require("tidal.core.state")

local M = {}

---Start a tidal repl
---@param opts TidalProcConfig
---@param split? 'v' | 'h' | nil
function M.tidal(opts, split)
  if not opts.enabled then
    return
  end

  state.ghci = Ghci:new({
    name = "tidal-fast://ghci-output",
    cmd = opts.cmd,
    args = vim.list_extend({
      "-XOverloadedStrings",
      "-ghci-script=" .. vim.fn.expand(opts.file),
    }, opts.args or {}),
    on_exit = function(_code, _signal)
      state.ghci = nil
    end,
  }):start({
    split = split or "v",
  })
end

---Start an sclang instance
---@param opts TidalProcConfig
---@param split? 'v' | 'h' | nil
function M.sclang(opts, split)
  if not opts.enabled then
    return
  end

  state.sclang = Sclang:new({
    name = "tidal-fast://sclang-output",
    cmd = opts.cmd,
    args = vim.list_extend({
      "-i",
      "scnvim",
    }, opts.args or {}),
    on_exit = function(_code, _signal)
      state.sclang = nil
    end,
    window = {
      split = "h",
    },
  }):start({
    split = split or "h",
  })

  -- load the boot file
  local file = vim.fn.expand(opts.file)
  state.sclang:send_line('"' .. file .. '".load;')
end

return M

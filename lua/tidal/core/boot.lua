local Ghci = require("tidal.repl.ghci")
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

return M

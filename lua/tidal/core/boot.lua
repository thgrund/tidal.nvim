local Ghci = require("tidal.repl.ghci")
local state = require("tidal.core.state")
local tokenizer = require("tidal.highlighting.tokenizer")

local M = {}

---Start a tidal repl
---@param opts TidalProcConfig
---@param split? 'v' | 'h' | nil
function M.tidal(opts, split)
  if not opts.enabled then
    return
  end

  local ghci = Ghci:new({
    name = "tidal-fast://ghci-output",
    cmd = opts.cmd,
    args = vim.list_extend({
      "-XOverloadedStrings",
      "-ghci-script=" .. vim.fn.expand(opts.file),
    }, opts.args or {}),
    on_exit = function(_code, _signal)
      state.ghci = nil
    end,
  })

  if opts.remote then
    tokenizer.eventIdBase = opts.remote.eventIdBase or tokenizer.eventIdBase
    tokenizer.lastEventId = tokenizer.eventIdBase
    state.ghci = ghci:connect_remote(opts.remote)
  else
    state.ghci = ghci:start({ split = split or "v" })
  end
end

return M

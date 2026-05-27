local boot = require("tidal.core.boot")
local highlight = require("tidal.highlighting")
local marker = require("tidal.highlighting.marker")
local message = require("tidal.core.message")
local notify = require("tidal.util.notify")
local select = require("tidal.util.select")
local state = require("tidal.core.state")
local util = require("tidal.util")
-- Lazily require highlight module to ensure 'setup' is called before

local M = {}

--- Begin a Tidal session
---@param args TidalBootConfig
function M.launch_tidal(args)
  local current_win = vim.api.nvim_get_current_win()
  if state.launched then
    notify.warn("Tidal is already running")
    return
  end
  if args.tidal.enabled then
    boot.tidal(args.tidal, args.split)
  end
  M.start_event_highlighting(args.tidal)
  vim.api.nvim_set_current_win(current_win)
  state.launched = true

  vim.api.nvim_exec_autocmds("User", { pattern = "TidalLaunch" })
end

function M.start_event_highlighting(args)
  highlight.start(args.highlight)
end

function M.stop_event_highlighting()
  highlight.stop()
end

--- Quit Tidal session
function M.exit_tidal()
  if not state.launched then
    notify.warn("Tidal is not running. Launch with ':TidalLaunch'")
    return
  end

  if state.ghci then
    state.ghci:exit()
  end

  state.launched = false
end

---@return message.TidalRepl
local function ft_to_repl()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  if ft == "haskell" or ft == "tidal" then
    return message.tidal
  end
  -- default to tidal repl
  return message.tidal
end

--- Send text to the interpreter for the current filetype
--- @param text string
function M.send(text)
  local repl = ft_to_repl()
  if repl then
    repl.send_line(text)
  end
end

-- Send 'd{count} silence' to tidal interpreter to silence a pattern d1-d16
function M.send_silence()
  message.tidal.send_line(string.format("d%d silence", vim.v.count1))
end

--- Send multiline to the interpreter for the current filetype
--- @param lines string[]
function M.send_multiline(lines)
  local repl = ft_to_repl()
  if repl then
    repl.send_multiline(lines)
  end
end

--- Send the current line to the interpreter for the current filetype
function M.send_line()
  local line = select.get_current_line()
  local text = line.lines[1]
  if #text > 0 then
    require("tidal.core.highlight").apply_highlight(line.start, line.finish)
    local repl = ft_to_repl()
    if repl then
      marker.cleanUpMarkers(line.start[1] + 1, line.start[1] + 1)

      repl.send_line(text, line.start)
    end
  end
end

--- Send the last visual selection to the interpreter for the current filetype
function M.send_visual()
  local visual = select.get_visual()
  if visual then
    require("tidal.core.highlight").apply_highlight(visual.start, visual.finish)
    local repl = ft_to_repl()
    if repl then
      repl.send_multiline(visual.lines, visual.start)
    end
  end
end

--- Send the current block to the interpreter for the current filetype
function M.send_block()
  if util.is_empty(vim.api.nvim_get_current_line()) then
    return
  end
  local block = select.get_block()
  require("tidal.core.highlight").apply_highlight(block.start, block.finish)
  local repl = ft_to_repl()
  if repl then
    repl.send_multiline(block.lines, block.start)
  end
end

--- Send current expression node to the interpreter for the current filetype
function M.send_node()
  local block = select.get_node()
  if block then
    require("tidal.core.highlight").apply_highlight(block.start, block.finish)
    local repl = ft_to_repl()
    if repl then
      repl.send_multiline(block.lines)
    end
  end
end

return M

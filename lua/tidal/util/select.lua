local notify = require("tidal.util.notify")
local util = require("tidal.util")

local M = {}

---@class TextRange
---@field lines string[] lines of text in the range
---@field start { [1]: integer, [2]: integer } Start position {line, col} (zero-indexed)
---@field finish { [1]: integer, [2]: integer } Finish position {line, col} (zero-indexed)

--- Get a range from either the 'visual' or 'motion' marks
---@param mode "visual" | "motion"
---@return TextRange
local function get_mark(mode)
  local start_char, end_char = unpack(({
    visual = { "<", ">" },
    motion = { "[", "]" },
  })[mode])

  -- Get the start and the end of the selection
  local start_line, start_col = unpack(vim.api.nvim_buf_get_mark(0, start_char))
  local end_line, end_col = unpack(vim.api.nvim_buf_get_mark(0, end_char))
  local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return {
    start = { start_line - 1, start_col },
    finish = { end_line - 1, end_col },
    lines = selected_lines,
  }
end

--- Get the last visual selection
---@return TextRange | nil
function M.get_visual()
  local mode = vim.fn.visualmode()
  local range = get_mark("visual")
  -- line-wise visual
  if mode == "V" then
    return range
  end

  if mode == "v" then
    -- character-wise visual
    -- return the buffer text encompassed by the selection
    local start_line, start_col = unpack(range.start)
    local finish_line, finish_col = unpack(range.finish)
    -- exclude the last char in text if "selection" is set to "exclusive"
    if vim.opt.selection:get() == "exclusive" then
      finish_col = finish_col - 1
    end
    return {
      lines = vim.api.nvim_buf_get_text(0, start_line, start_col, finish_line, finish_col + 1, {}),
      start = { start_line, start_col },
      finish = { finish_line, finish_col },
    }
  end

  -- block-wise visual
  -- return the lines encompassed by the selection, each truncated by the start and end columns
  -- selene: allow(bad_string_escape) - see :h visualmode
  if mode == "\x16" then
    error("Blockwise visual selection not implemented", vim.log.levels.ERROR)
    -- local _, start_col = unpack(range.start)
    -- local _, end_col = unpack(range.finish)
    -- -- exclude the last col of the block if "selection" is set to "exclusive"
    -- if vim.opt.selection:get() == "exclusive" then
    --   end_col = end_col - 1
    -- end
    -- -- exchange start and end columns for proper substring indexing if needed
    -- -- e.g. instead of str:sub(10, 5), do str:sub(5, 10)
    -- if start_col > end_col then
    --   start_col, end_col = end_col, start_col
    -- end
    -- -- iterate over lines, truncating each one
    -- return {
    --   start = range.start,
    --   finish = range.finish,
    --   lines = vim.tbl_map(function(line)
    --     return line:sub(start_col, end_col)
    --   end, range.lines),
    -- }
  end
end

--- Get the current line
---@return TextRange
function M.get_current_line()
  local line = unpack(vim.api.nvim_win_get_cursor(0), 1) - 1
  local text = vim.api.nvim_get_current_line()
  return {
    lines = { text },
    start = { line, 0 },
    finish = { line, #text },
  }
end

--- Get contiguous block of non-blank lines
---@return TextRange
function M.get_block()
  -- row is 1-indexed
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

  -- block_start/end are zero indexed for nvim_buf_get_lines
  local block_start = row - 1
  while block_start > 0 and not util.line_empty(block_start - 1) do
    block_start = block_start - 1
  end

  local block_end = row
  local n_lines = vim.api.nvim_buf_line_count(0)
  while block_end < n_lines and not util.line_empty(block_end) do
    block_end = block_end + 1
  end
  local lines = vim.api.nvim_buf_get_lines(0, block_start, block_end, true)
  return {
    lines = lines,
    start = { block_start, 0 },
    finish = { block_end, #lines[#lines] },
  }
end

---@class LangSpec
---@field expression string[]
---@field skip? string[] Node types to skip selection

--- @type table<string, LangSpec>
local node_types = {
  haskell = {
    expression = {
      "top_splice",
      "exp",
      "bind",
      "function",
    },
    skip = {
      "haskell",
      "declarations",
    },
  },
}

--- Get top level TS node at current position
---@return TextRange | nil
function M.get_node()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local lang = vim.treesitter.language.get_lang(ft)

  if lang == nil then
    notify.error("No treesitter parser for '" .. ft .. "'")
    return
  end

  local nodes = node_types[lang]
  local node = vim.treesitter.get_node()
  if not node or vim.tbl_contains(nodes.skip or {}, node:type()) then
    return
  end

  local root
  root = node:tree():root()

  if not root then
    return
  end
  local parent
  parent = node:parent()
  local break_nodes = nodes.expression or {}
  while node ~= nil and not node:equal(root) do
    local node_t = node:type()
    if vim.list_contains(break_nodes, node_t) then
      break
    end
    node = parent
    if node then
      parent = node:parent()
    end
  end
  assert(node, "node cannot be nil")

  local start_row, start_col, finish_row, finish_col = vim.treesitter.get_node_range(node)
  local bufnr = 0

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if finish_row >= line_count then
    finish_row = line_count - 1
    local last_line = vim.api.nvim_buf_get_lines(bufnr, finish_row, finish_row + 1, false)[1] or ""
    finish_col = #last_line
  end

  local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, finish_row, finish_col, {})
  return {
    start = { start_row, start_col },
    finish = { finish_row, finish_col },
    lines = lines,
  }
end

return M

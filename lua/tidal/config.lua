local M = {}

---@class TidalBootConfig
---@field tidal TidalProcConfig
---@field sclang TidalProcConfig
---@field split "v" | nil

---@class TidalProcConfig
---@field cmd string
---@field file string
---@field args table<string>
---@field enabled boolean

---@class TidalConfig
local defaults = {
  --- Configure TidalLaunch command
  boot = {
    tidal = {
      --- Command to launch ghci with tidal installation
      cmd = "ghci",
      args = {
        "-v0",
      },
      --- Tidal boot file path
      file = vim.api.nvim_get_runtime_file("bootfiles/BootTidal.hs", false)[1],
      enabled = true,
      highlight = {
        type = "stdio",
        styles = {
          osc = {
            ip = "127.0.0.1",
            port = 3335,
          },
          custom = {},
          global = { baseName = "CodeHighlight", style = { bg = "#7eaefc", foreground = "#000000" } },
        },
        events = {
          osc = {
            ip = "127.0.0.1",
            port = 6013,
          },
        },
        fps = 60,
        onSamChange = function() end,
        onPlayStateChange = function() end,
        onParsedOutputChange = function() end,
      },
    },
    sclang = {
      --- Command to launch SuperCollider
      cmd = "sclang",
      args = {},
      --- SuperCollider boot file
      file = vim.api.nvim_get_runtime_file("bootfiles/BootSuperDirt.scd", false)[1],
      enabled = false,
    },
    split = "v",
  },
  --- Default keymaps
  --- Set to false to disable all default mappings
  --- @type table | nil
  mappings = {
    send_line = { mode = { "i", "n" }, key = "<S-CR>" },
    send_visual = { mode = { "x" }, key = "<S-CR>" },
    send_block = { mode = { "i", "n", "x" }, key = "<M-CR>" },
    send_node = { mode = "n", key = "<leader><CR>" },
    send_silence = { mode = "n", key = "<leader>d" },
    send_hush = { mode = "n", key = "<leader>h" },
  },
  ---- Configure highlight applied to selections sent to tidal interpreter
  selection_highlight = {
    --- Highlight definition table
    --- see ':h nvim_set_hl' for details
    --- @type vim.api.keyset.highlight
    highlight = { link = "IncSearch" },
    --- Duration to apply the highlight for
    timeout = 150,
  },
}

---@type TidalConfig
M.options = defaults

M.namespace = vim.api.nvim_create_namespace("Tidal")

---Configure Tidal plugin
---@param options TidalConfig | nil
function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M

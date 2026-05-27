local api = require("tidal.api")
local config = require("tidal.config")
local message = require("tidal.core.message")
local notify = require("tidal.util.notify")
local state = require("tidal.core.state")

local Tidal = {}

local keymaps = {
  send_line = { callback = api.send_line, desc = "Send current line to tidal" },
  send_visual = {
    callback = [[<Esc><Cmd>lua require("tidal").api.send_visual()<CR>gv]],
    desc = "Send current visual selection to tidal",
  },
  send_block = { callback = api.send_block, desc = "Send current block to tidal" },
  send_node = { callback = api.send_node, desc = "Send current TS node to tidal" },
  send_silence = { callback = api.send_silence, desc = "Send 'd{count} silence' to tidal" },
  send_hush = {
    callback = function()
      message.tidal.send_line("hush", { 0, 0 })
      vim.api.nvim_exec_autocmds("User", { pattern = "TidalHush", modeline = false })
    end,
    desc = "Send 'hush' to tidal",
  },
}

local function setup_user_commands()
  vim.api.nvim_create_user_command("TidalLaunch", function()
    api.launch_tidal(config.options.boot)
  end, { desc = "Launch Tidal instance" })
  vim.api.nvim_create_user_command("TidalNotification", function()
    if state.ghci then
      state.ghci:showNotificationBuffer("tidal_post")
    end
  end, { desc = "Launch Tidal Notification Buffer" })
  vim.api.nvim_create_user_command("TidalQuit", api.exit_tidal, { desc = "Quit Tidal instance" })

  vim.api.nvim_create_user_command("Tidal", function()
    api.launch_tidal(config.options.boot)
  end, { desc = "Launch Tidal instance" })
  vim.api.nvim_create_user_command("TidalQuit", api.exit_tidal, { desc = "Quit Tidal instance" })
end

local function setup_autocmds()
  vim.api.nvim_create_augroup("Tidal", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = "Tidal",
    pattern = { "*.tidal" },
    callback = function()
      for name, mapping in pairs(config.options.mappings or {}) do
        if mapping then
          local command = keymaps[name]
          vim.keymap.set(mapping.mode, mapping.key, command.callback, { buffer = true, desc = command.desc })
        end
      end
    end,
  })
end

local MIN_VERSION = "0.8.0"

---Configure Tidal plugin
---@param options TidalConfig | nil
function Tidal.setup(options)
  if vim.fn.has("nvim-" .. MIN_VERSION) == 0 then
    notify.error("tidal.nvim requires nvim >= " .. MIN_VERSION)
    return
  end

  config.setup(options)
  setup_autocmds()
  setup_user_commands()
end

vim.treesitter.language.register("haskell", "tidal")

vim.filetype.add({
  extension = {
    tidal = "tidal",
  },
})

Tidal.api = api

return Tidal

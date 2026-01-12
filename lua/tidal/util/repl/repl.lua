local Buffer = require("tidal.util.buffer")

---@class Repl
---@field buf Buffer
---@field proc? integer
---@field opts ReplOpts
---@field onDataProcessed? fun(self, table<string>)
---@field playstate table<string>
local Repl = {}
Repl.__index = Repl

---@class ReplOpts
---@field cmd string
---@field args? table<string> additional arguments to for GHCi
---@field name? string repl buffer name
---@field on_exit fun(code: number, signal: number)?

--- Create a new REPL
--- @generic T - generic type for type inference on child 'classes'
--- @param self T
--- @param opts? ReplOpts
--- @return T for method chaining
function Repl:new(opts)
  opts = opts or {}
  local obj = {}
  setmetatable(obj, self)
  obj.opts = opts
  obj.stdout = {}
  obj.stderr = {}
  obj.stdin = {}
  obj.proc = nil
  obj.playstate = {}

  return obj
end

local uv, api, _ = vim.loop, vim.api, vim.fn

local marker = require("tidal.highlighting.marker")
local tokenizer = require("tidal.highlighting.tokenizer")

local LOCK_START = "LOCK_REPL_START"
local LOCK_END = "LOCK_REPL_END"

function Repl:attach(pipe, label)
  local buf_acc = ""
  local isLocked = false

  pipe:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify(("[tidal-fast] %s error: %s"):format(label, err), vim.log.levels.ERROR)
      end)
      return
    end
    if not data then
      return
    end

    vim.schedule(function()
      buf_acc = buf_acc .. data
      local lines = vim.split(buf_acc, "\n", { plain = true })
      local complete, remainder = {}, ""

      if buf_acc:sub(-1) == "\n" then
        if #lines > 0 and lines[#lines] == "" then
          table.remove(lines)
        end
        complete, buf_acc = lines, ""
      else
        remainder = table.remove(lines)
        complete, buf_acc = lines, remainder
      end

      for _, line in ipairs(complete) do
        if line == LOCK_START then
          isLocked = true
        end
      end

      if isLocked then
        for _, line in ipairs(complete) do
          table.insert(self.playstate, line)

          if line == LOCK_END then
            self:onDataProcessed(self.playstate)
            self.playstate = {}
            isLocked = false
          end
        end
      else
        if self.buf then
          for _, line in ipairs(complete) do
            self.buf:append(line .. "\n")
          end
        end
      end
    end)
  end)
end

--- Start the REPL
--- @param opts table|nil Window options
---  - split: string|nil - Split type ('', 'v', 'h')
---  - win: number|nil - Window to use (default: current window)
--- @generic T
--- @return T for method chaining
function Repl:start(opts)
  if self.proc and self.proc:is_active() then
    return vim.notify("[repl] Command " .. self.opts.cmd .. "already running", vim.log.levels.INFO)
  end

  self.opts = vim.tbl_deep_extend("force", {}, self.opts, opts or {})

  self.stdin = uv.new_pipe(false)
  self.stdout, self.stderr = uv.new_pipe(false), uv.new_pipe(false)

  self.proc = uv.spawn(
    self.opts.cmd,
    { args = self.opts.args, stdio = { self.stdin, self.stdout, self.stderr } },
    function(code, signal)
      for _, p in ipairs({ self.stdin, self.stdout, self.stderr }) do
        if p and not p:is_closing() then
          p:close()
        end
      end
      self.proc = nil
      vim.schedule(function()
        vim.notify(("[tidal] ghci exited (code=%d, signal=%d)"):format(code, signal), vim.log.levels.WARN)
      end)
    end
  )

  if not self.proc then
    return vim.notify("[tidal] failed to spawn " .. self.opts.cmd, vim.log.levels.ERROR)
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(buf, "tidal-fast://" .. self.opts.cmd)
  vim.notify("[tidal] " .. self.opts.cmd .. " started (pipe mode)", vim.log.levels.INFO)

  self:attach(self.stdout, "stdout")
  self:attach(self.stderr, "stderr")

  return self
end

function Repl:showNotificationBuffer(filetype)
  if self.buf == nil then
    self.buf = Buffer.new({
      name = self.opts.name,
      scratch = true,
      listed = false,
    })
  end

  self.buf:show(self.opts or {})

  self.buf:set_option("filetype", filetype)
end

--- Send text to REPL
--- @generic T
--- @return T for method chaining
function Repl:send(text, start, isLocked)
  isLocked = isLocked or false

  if start then
    local enrichedText = {}
    local rowIndex = 0
    local rowStart = start[1] + 1

    for line in text:gmatch("[^\r\n]+") do
      local enrichedLine = tokenizer.addMetadata(line, rowStart + rowIndex)
      table.insert(enrichedText, enrichedLine)
      rowIndex = rowIndex + 1

      if line:match("^hush") ~= nil then
        marker.deleteAllMarkers()
        tokenizer.lastEventId = 0
        vim.api.nvim_exec_autocmds("User", { pattern = "TidalHush", modeline = false })
      end
    end

    text = table.concat(enrichedText, "\n") .. "\n"
  end

  -- vim.notify("[tidal-fast] Repl send received", vim.log.levels.INFO)
  if self.stdin and not self.stdin:is_closing() then
    if isLocked then
      self.stdin:write('\n:{\nputStrLn "LOCK_REPL_START"\n:}\n')
      self.stdin:write(text)
      self.stdin:write('\n:{\nputStrLn "LOCK_REPL_END"\n:}\n')
    else
      self.stdin:write(text)
    end
  end

  if self.proc == nil then
    -- not running - error?
    return self
  end

  --vim.api.nvim_chan_send(self.proc, text)
  --self.buf:scroll_to_bottom()
  return self
end

--- Send line of text to REPL
---@param text string
--- @generic T
--- @return T for method chaining
function Repl:send_line(text, start)
  return self:send(text .. "\n", start)
end

--- Send multi-line text to REPL
--- @param lines string[]
--- @generic T
--- @return T for method chaining
function Repl:send_multiline(lines, start)
  return self:send_line(table.concat(lines, "\n"), start)
end

--- Close the REPL
--- @return self for method chaining
function Repl:exit()
  if self.proc then
    -- Removes buffers and closes windows
    vim.fn.jobstop(self.proc)
  end
  return self
end

return Repl

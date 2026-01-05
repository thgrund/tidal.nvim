--- @diagnostic disable: undefined-field
--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: inject-field
---
local mock = require("luassert.mock")
local stub = require("luassert.stub")

describe("Repl", function()
  local Repl

  -- Shared mocks
  local spawn_called
  local spawned_opts
  local fake_proc
  local fake_pipe

  before_each(function()
    --------------------------------------------------------------------------
    -- Reset global vim -------------------------------------------------------
    --------------------------------------------------------------------------
    -- _G.vim = {
    --   loop = {},
    --   api = {},
    --   fn = {},
    --   notify = function() end,
    --   schedule = function(cb)
    --     cb()
    --   end,
    --   log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    --   tbl_deep_extend = function(_, ...)
    --     local result = {}
    --     for _, t in ipairs({ ... }) do
    --       for k, v in pairs(t) do
    --         result[k] = v
    --       end
    --     end
    --     return result
    --   end,
    --   split = function(str, sep)
    --     local t = {}
    --     for s in string.gmatch(str, "([^" .. sep .. "]+)") do
    --       table.insert(t, s)
    --     end
    --     return t
    --   end,
    -- }

    --------------------------------------------------------------------------
    -- Mock libuv -------------------------------------------------------------
    --------------------------------------------------------------------------
    fake_pipe = {
      closed = false,
      read_start = function(_, _) end,
      write = function(_, _) end,
      is_closing = function(self)
        return self.closed
      end,
      close = function(self)
        self.closed = true
      end,
    }

    spawn_called = false
    spawned_opts = nil

    fake_proc = {
      is_active = function()
        return true
      end,
    }

    vim.loop.new_pipe = function()
      return vim.deepcopy(fake_pipe)
    end

    vim.loop.spawn = function(cmd, opts, on_exit)
      spawn_called = true
      spawned_opts = { cmd = cmd, opts = opts }
      return fake_proc
    end

    -- --------------------------------------------------------------------------
    -- -- Mock vim.api -----------------------------------------------------------
    -- --------------------------------------------------------------------------
    vim.api.nvim_create_buf = function(_, _)
      return 99
    end
    vim.api.nvim_buf_set_name = function() end
    vim.api.nvim_exec_autocmds = function() end

    -- --------------------------------------------------------------------------
    -- -- Mock vim.fn ------------------------------------------------------------
    -- --------------------------------------------------------------------------
    -- vim.fn.jobstop = function() end

    -- --------------------------------------------------------------------------
    -- -- Mock Buffer ------------------------------------------------------------
    -- --------------------------------------------------------------------------
    package.loaded["tidal.util.buffer"] = {
      new = function()
        return {
          append = function() end,
          show = function() end,
          set_option = function() end,
        }
      end,
    }

    --------------------------------------------------------------------------
    -- Mock tokenizer & marker ------------------------------------------------
    --------------------------------------------------------------------------
    package.loaded["tidal.highlighting.tokenizer"] = {
      lastEventId = 42,
      addMetadata = function(line, row)
        return string.format("%s@%d", line, row)
      end,
    }

    package.loaded["tidal.highlighting.marker"] = {
      deleteAllMarkers = function() end,
    }

    --------------------------------------------------------------------------
    -- Load module ------------------------------------------------------------
    --------------------------------------------------------------------------
    package.loaded["tidal.util.repl.repl"] = nil
    Repl = require("tidal.util.repl.repl")
  end)

  describe("new", function()
    it("creates a new Repl with defaults", function()
      local r = Repl:new({ cmd = "ghci" })

      assert.is_table(r)
      assert.equals("ghci", r.opts.cmd)
      assert.is_nil(r.proc)
      assert.is_table(r.stdin)
      assert.is_table(r.stdout)
      assert.is_table(r.stderr)
    end)
  end)

  describe("start", function()
    it("spawns a process when started", function()
      local r = Repl:new({ cmd = "ghci" })

      r:start()

      assert.is_true(spawn_called)
      assert.equals("ghci", spawned_opts.cmd)
      assert.is_not_nil(r.proc)
    end)

    it("does not spawn if process is already active", function()
      local r = Repl:new({ cmd = "ghci" })
      r.proc = fake_proc

      r:start()

      assert.is_false(spawn_called)
    end)

    it("handles spawn failure", function()
      vim.loop.spawn = function()
        return nil
      end

      local r = Repl:new({ cmd = "ghci" })
      local result = r:start()

      assert.is_nil(r.proc)
      assert.is_nil(result)
    end)
  end)

  describe("showNotificationBuffer", function()
    it("creates and shows a notification buffer", function()
      local r = Repl:new({ cmd = "ghci", name = "repl" })
      r.stdout = vim.loop.new_pipe()
      r.stderr = vim.loop.new_pipe()

      r:showNotificationBuffer("haskell")

      assert.is_not_nil(r.buf)
    end)
  end)

  describe("send", function()
    it("writes text to stdin", function()
      local written
      fake_pipe.write = function(_, txt)
        written = txt
      end

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send("1 + 1\n")
      assert.equals("1 + 1\n", written)
    end)

    it("enriches text when start metadata is provided", function()
      local written
      fake_pipe.write = function(_, txt)
        written = txt
      end

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send("foo\nbar", { 0 })

      assert.matches("foo@1", written)
      assert.matches("bar@2", written)
    end)

    it("handles hush by clearing markers and firing autocmd", function()
      local marker = mock(require("tidal.highlighting.marker"), true)
      local autocmd_stub = stub(vim.api, "nvim_exec_autocmds")
      local tokenizer = require("tidal.highlighting.tokenizer")

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send("hush", { 0 })

      assert.stub(marker.deleteAllMarkers).was_called()
      assert.equals(0, tokenizer.lastEventId)
      assert.stub(autocmd_stub).was_called()
    end)
  end)

  describe("send helpers", function()
    it("send_line appends newline", function()
      local written
      fake_pipe.write = function(_, txt)
        written = txt
      end

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send_line("foo")

      assert.equals("foo\n", written)
    end)

    it("send_multiline concatenates lines", function()
      local written
      fake_pipe.write = function(_, txt)
        written = txt
      end

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send_multiline({ "a", "b" })

      assert.matches("a\nb", written)
    end)
  end)

  ---------------------------------------------------------------------------
  -- exit -------------------------------------------------------------------
  ---------------------------------------------------------------------------
  describe("exit", function()
    it("stops the job on exit", function()
      local jobstop_stub = stub(vim.fn, "jobstop")

      local r = Repl:new({ cmd = "ghci" })
      r.proc = 123

      r:exit()

      assert.stub(jobstop_stub).was_called_with(123)

      jobstop_stub:revert()
    end)
  end)
end)

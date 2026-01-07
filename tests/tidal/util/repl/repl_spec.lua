--- @diagnostic disable: undefined-field
--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: inject-field
---
---

local mock = require("luassert.mock")
local stub = require("luassert.stub")

-- Save original functions
local orig_get_buf = vim.api.nvim_get_current_buf
local orig_get_lines = vim.api.nvim_buf_get_lines
local orig_set_lines = vim.api.nvim_buf_set_lines
local orig_cmd = vim.cmd

vim.api.nvim_get_current_buf = function()
  return 1 -- always return a valid buffer number
end

vim.api.nvim_buf_get_lines = function()
  return { "mocked line 1", "mocked line 2" } -- must be a table
end

vim.api.nvim_buf_set_lines = function(_, _, _, _, lines)
  return lines -- return a table (or true)
end

vim.cmd = function(cmd)
  -- optionally just log or do nothing
  print("Mocked vim.cmd:", cmd)
end

describe("Repl", function()
  local Repl

  -- Shared mocks
  local spawn_called
  local spawned_opts
  local fake_proc
  local fake_pipe

  before_each(function()
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

    vim.loop.spawn = function(cmd, opts)
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

  -- Restore the original vim after tests
  after_each(function()
    vim.api.nvim_get_current_buf = orig_get_buf
    vim.api.nvim_buf_get_lines = orig_get_lines
    vim.api.nvim_buf_set_lines = orig_set_lines
    vim.cmd = orig_cmd
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

    it("writes locked text with proper markers", function()
      local written
      fake_pipe.write = function(_, txt)
        written = written or ""
        written = written .. txt
      end

      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      r:send("locked text", nil, true)

      assert.matches(
        [[
:{
putStrLn "LOCK_REPL_START"
:}
locked text
:{
putStrLn "LOCK_REPL_END"
:}
]],
        written
      )
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

  describe("attach", function()
    it("captures playstate between LOCK_REPL_START and LOCK_REPL_END", function()
      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      -- Mock the attach function to simulate receiving playstate data
      local onDataProcessed_called = false
      r.onDataProcessed = function(_, playstate)
        onDataProcessed_called = true
        assert.is_table(playstate)
        assert.equals("LOCK_REPL_START", playstate[1])
        assert.equals("playstate line 1", playstate[2])
        assert.equals("playstate line 2", playstate[3])
        assert.equals("LOCK_REPL_END", playstate[4])
      end

      -- Simulate receiving playstate data
      fake_pipe = {
        read_start = function(_, callback)
          callback(nil, "LOCK_REPL_START\nplaystate line 1\nplaystate line 2\nLOCK_REPL_END\n")
        end,
      }

      r:attach(fake_pipe, "stdout")

      vim.wait(100, function()
        return onDataProcessed_called
      end)

      assert.is_true(onDataProcessed_called)
    end)
    it("should not trigger onDataProcessed callback when there are no LOCK_REPL_START and LOCK_REPL_END", function()
      local r = Repl:new({ cmd = "ghci" })
      r.stdin = vim.loop.new_pipe()
      r.proc = fake_proc

      -- Mock the attach function to simulate receiving playstate data
      local onDataProcessed_called = false
      r.onDataProcessed = function(_, _)
        onDataProcessed_called = true
      end

      -- Simulate receiving playstate data
      local fake_pipe = {
        read_start = function(_, callback)
          callback(nil, "playstate line 1\nplaystate line 2\n")
        end,
      }

      r:attach(fake_pipe, "stdout")

      vim.wait(100, function()
        return onDataProcessed_called
      end)

      assert.is_false(onDataProcessed_called)
    end)
  end)
end)

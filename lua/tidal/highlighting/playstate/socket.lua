local uv = vim.loop
local socket_path = "/tmp/tidal.sock"

-- 20:45:05 msg_show.lua_print {
--   events = {
--     XmCy9yA6U = {
--       colStart = 2,
--       eventId = 1,
--       id = "1",
--       whole = {
--         start = 0,
--         stop = 1,
--       },
--     },
--     w3YitDZAk = {
--       colStart = 1,
--       eventId = 1,
--       id = "1",
--       whole = {
--         start = 0,
--         stop = 1,
--       },
--     },
--   },
--   type = "bubu",
-- }

-- Remove old socket if it exists
if vim.fn.filereadable(socket_path) == 1 then
  os.remove(socket_path)
end

local server = uv.new_pipe(false)

server:bind(socket_path)

server:listen(128, function(err)
  assert(not err, err)

  local client = uv.new_pipe(false)

  server:accept(client)

  client:read_start(function(err, data)
    assert(not err, err)

    if data then
      -- React to message
      vim.schedule(function()
        print("Tidal says: ")
        print(vim.inspect(vim.mpack.decode(data)))
      end)
    else
      client:close()
    end
  end)
end)

print("Tidal socket server listening on " .. socket_path)

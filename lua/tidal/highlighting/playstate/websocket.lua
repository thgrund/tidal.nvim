local uv = vim.loop
local bit = require("bit")

local WebSocket = {}
WebSocket.__index = WebSocket

-- ======================
-- Utilities
-- ======================

-- Base64 encode a string
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64_encode(data)
  local bytes = { data:byte(1, #data) }
  local result = {}
  local pad = 0

  for i = 1, #bytes, 3 do
    local a = bytes[i]
    local b = bytes[i + 1] or 0
    local c = bytes[i + 2] or 0

    if i + 1 > #bytes then
      pad = 2
    elseif i + 2 > #bytes then
      pad = 1
    end

    local n = bit.bor(bit.lshift(a, 16), bit.lshift(b, 8), c)

    result[#result + 1] = b64chars:sub(bit.rshift(n, 18) % 64 + 1, bit.rshift(n, 18) % 64 + 1)
    result[#result + 1] = b64chars:sub(bit.rshift(n, 12) % 64 + 1, bit.rshift(n, 12) % 64 + 1)
    result[#result + 1] = b64chars:sub(bit.rshift(n, 6) % 64 + 1, bit.rshift(n, 6) % 64 + 1)
    result[#result + 1] = b64chars:sub(n % 64 + 1, n % 64 + 1)
  end

  if pad > 0 then
    for i = 1, pad do
      result[#result - i + 1] = "="
    end
  end

  return table.concat(result)
end

local function random_key()
  local bytes = {}
  for i = 1, 16 do
    bytes[i] = string.char(math.random(0, 255))
  end
  return base64_encode(table.concat(bytes))
end

local function mask_payload(payload, mask)
  local out = {}
  for i = 1, #payload do
    out[i] = string.char(bit.bxor(payload:byte(i), mask:byte(((i - 1) % 4) + 1)))
  end
  return table.concat(out)
end

-- ======================
-- Frame encoding
-- ======================

local function encode_frame(payload)
  local fin_opcode = 0x81 -- FIN + text frame
  local mask_bit = 0x80
  local len = #payload

  local header = string.char(fin_opcode)
  local mask = ""
  local ext = ""

  if len < 126 then
    header = header .. string.char(mask_bit + len)
  elseif len < 65536 then
    header = header .. string.char(mask_bit + 126)
    ext = string.char(bit.rshift(len, 8), bit.band(len, 0xff))
  else
    error("Payload too large")
  end

  for _ = 1, 4 do
    mask = mask .. string.char(math.random(0, 255))
  end

  payload = mask_payload(payload, mask)
  return header .. ext .. mask .. payload
end

-- ======================
-- Constructor
-- ======================

function WebSocket.new(opts)
  local self = setmetatable({}, WebSocket)

  self.host = opts.host
  self.port = opts.port or 80
  self.path = opts.path or "/"

  self.on_open = opts.on_open
  self.on_message = opts.on_message
  self.on_close = opts.on_close
  self.on_error = opts.on_error

  self.sock = uv.new_tcp()
  self.buffer = ""

  return self
end

-- ======================
-- Connect
-- ======================

function WebSocket:connect()
  local key = random_key()

  print(self.host .. " " .. self.port)

  self.sock:connect(self.host, self.port, function(err)
    if err then
      if self.on_error then
        self.on_error(err)
      end
      return
    end

    local req = table.concat({
      "GET " .. self.path .. " HTTP/1.1",
      "Host: " .. self.host,
      "Upgrade: websocket",
      "Connection: Upgrade",
      "Sec-WebSocket-Key: " .. key,
      "Sec-WebSocket-Version: 13",
      "",
      "",
    }, "\r\n")

    self.sock:write(req)

    self.sock:read_start(function(err, chunk)
      if err then
        if self.on_error then
          self.on_error(err)
        end
        return
      end

      if not chunk then
        if self.on_close then
          self.on_close()
        end
        return
      end

      self.buffer = self.buffer .. chunk

      -- Handshake response ends with double CRLF
      if self.buffer:find("\r\n\r\n") then
        self.buffer = ""
        if self.on_open then
          self.on_open()
        end

        -- Switch to frame mode
        self.sock:read_stop()
        self:_read_frames()
      end
    end)
  end)
end

-- ======================
-- Frame reader
-- ======================

function WebSocket:_read_frames()
  self.sock:read_start(function(err, chunk)
    if err then
      if self.on_error then
        self.on_error(err)
      end
      return
    end

    if not chunk then
      if self.on_close then
        self.on_close()
      end
      return
    end

    self.buffer = self.buffer .. chunk

    while #self.buffer >= 2 do
      local b1, b2 = self.buffer:byte(1, 2)
      local opcode = bit.band(b1, 0x0f)
      local len = bit.band(b2, 0x7f)
      local offset = 3

      if len == 126 then
        if #self.buffer < 4 then
          return
        end
        len = self.buffer:byte(3) * 256 + self.buffer:byte(4)
        offset = 5
      end

      if #self.buffer < offset + len - 1 then
        return
      end

      local payload = self.buffer:sub(offset, offset + len - 1)
      self.buffer = self.buffer:sub(offset + len)

      if opcode == 0x1 and self.on_message then
        self.on_message(payload)
      end
    end
  end)
end

-- ======================
-- Send
-- ======================

function WebSocket:send(text)
  self.sock:write(encode_frame(text))
end

-- ======================
-- Close
-- ======================

function WebSocket:close()
  self.sock:close()
end

return WebSocket

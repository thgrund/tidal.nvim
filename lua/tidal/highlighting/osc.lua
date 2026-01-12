local OSC = {}

local losc = require("losc.src.losc")
local pluginLibUv = require("losc.src.losc.plugins.udp-libuv")

local events = require("tidal.highlighting.events")
local highlight = require("tidal.highlighting.highlights")
local marker = require("tidal.highlighting.marker")

local messageBuffer = {}
local activeMessages = {}

OSC.timer = nil

local handleMessageCallback = nil

local uv = vim.uv

local function startServer(host, port)
  local transport = pluginLibUv.new({ recvAddr = host, recvPort = port })
  local osc = losc.new({ plugin = transport })

  osc:add_handler("/editor/highlights", function(data)
    vim.schedule(function()
      local msg = data.message
      local id = msg[1]
      local colStart = msg[4] + 1
      local eventId = msg[5] - 1
      if marker.extMarks[eventId] and marker.extMarks[eventId][colStart] then
        local extmark = marker.extMarks[eventId][colStart]
        extmark.id = id
        table.insert(messageBuffer, extmark)
      else
        -- Drops -> Maybe count them?
        -- print(string.format("No extmark found at colStart=%s eventId=%s", tostring(colStart), tostring(eventId)))
      end
    end)
  end)

  osc:open()
end

local function startStyleServer(host, port)
  local transport = pluginLibUv.new({ recvAddr = host, recvPort = port })
  local osc = losc.new({ plugin = transport })

  osc:add_handler("/neovim/eventhighlighting/addstyle", function(data)
    vim.schedule(function()
      local msg = data.message
      local id = msg[1]
      local color = msg[2]
      highlight.addHl(id, color)
    end)
  end)

  osc:open()
end

local function handleMessages()
  local diff = events.diffEventLists(activeMessages, messageBuffer)

  for _, evt in ipairs(diff.added) do
    highlight.addHighlight(evt.id, evt.buf, evt.markerId)
  end

  for _, evt in ipairs(diff.removed) do
    highlight.removeHighlight(evt.buf, evt.markerId)
  end

  activeMessages = events.merge(diff.active, diff.added)

  if handleMessageCallback then
    handleMessageCallback(activeMessages)
  end

  messageBuffer = {}
end

function OSC.launch(highlightConf)
  local eventOsc = highlightConf.events.osc
  local styleOsc = highlightConf.styles.osc

  startServer(eventOsc.ip, eventOsc.port)
  startStyleServer(styleOsc.ip, styleOsc.port)
end

function OSC.setInterval(interval)
  OSC.timer = uv.new_timer()
  OSC.timer:start(interval, interval, function()
    vim.schedule(handleMessages)
  end)
end

function OSC.clearInterval()
  if OSC.timer ~= nil then
    OSC.timer:stop()
    OSC.timer:close()
    OSC.timer = nil
  end
  messageBuffer = {}
end

OSC._messageBuffer = messageBuffer

return OSC

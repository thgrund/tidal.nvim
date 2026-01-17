local OSC = {}

local losc = require("losc.src.losc")
local pluginLibUv = require("losc.src.losc.plugins.udp-libuv")

local highlight = require("tidal.highlighting.highlights")
local process = require("tidal.highlighting.playstate.process")

local function startServer(host, port)
  local transport = pluginLibUv.new({ recvAddr = host, recvPort = port })
  local osc = losc.new({ plugin = transport })

  osc:add_handler("/ping", function(data)
    vim.schedule(function()
      local msg = data.message
      local cyclePos = tonumber(msg[8])

      process.setSam(cyclePos)
      process.handleEvents()
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

function OSC.launch(highlightConf)
  local eventOsc = highlightConf.events.osc
  local styleOsc = highlightConf.styles.osc

  startServer(eventOsc.ip, eventOsc.port)
  startStyleServer(styleOsc.ip, styleOsc.port)
end

return OSC

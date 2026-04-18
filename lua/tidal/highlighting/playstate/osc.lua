local OSC = {}

local losc = require("losc.src.losc")
local pluginLibUv = require("losc.src.losc.plugins.udp-libuv")
local process = require("tidal.highlighting.playstate.process")
local socket = require("tidal.highlighting.playstate.socket")

local highlight = require("tidal.highlighting.highlights")
local processor = nil

local state = require("tidal.core.state")

local function startServer(host, port)
  local transport = pluginLibUv.new({ recvAddr = host, recvPort = port })
  local osc = losc.new({ plugin = transport })

  osc:add_handler("/ping", function(data)
    vim.schedule(function()
      local msg = data.message
      local cyclePos = tonumber(msg[8])

      if processor ~= nil then
        processor.setSam(cyclePos)
        processor.handleEvents()
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
  osc:add_handler("/neovim/ctrl", function(data)
    vim.schedule(function()
      local msg = data.message
      local controlName = msg[1]
      local controlVal = msg[2]
      local controlType = msg[3]

      if #controlName > 0 and #controlVal > 0 and #controlType > 0 then
        local remoteControlCommand =
          string.format([[streamSet tidal "%s" ("%s"::Pattern %s)]], controlName, controlVal, controlType)

        state.ghci:send(remoteControlCommand)

        if processor ~= nil then
          processor.reset()
        end
      end
    end)
  end)

  osc:add_handler("/neovim/reset", function()
    vim.schedule(function()
      if processor ~= nil then
        processor.reset()
      end
    end)
  end)

  osc:open()
end

function OSC.launch(highlightConf)
  local eventOsc = highlightConf.events.osc
  local styleOsc = highlightConf.styles.osc

  if highlightConf.type == "stdio" then
    processor = process
  elseif highlightConf.type == "socket" then
    processor = socket
  end

  startServer(eventOsc.ip, eventOsc.port)
  startStyleServer(styleOsc.ip, styleOsc.port)
end

return OSC

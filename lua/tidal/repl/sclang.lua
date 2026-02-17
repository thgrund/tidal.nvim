local Repl = require("tidal.repl.repl")

---@class Sclang : Repl
---@field buf Buffer
---@field proc integer
local Sclang = Repl:new()
Sclang.__index = Sclang

local keycodes = {
  interpret_print = string.char(0x0c),
  interpret = string.char(0x1b),
  recompile = string.char(0x18),
}

---@param text string
function Sclang:send_line(text)
  self:send(text .. keycodes.interpret_print .. "\n")
end

return Sclang

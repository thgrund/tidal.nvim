local M = {}

function M.mapCtx(str)
  local result = {}
  local n = 0
  for x, y in str:gmatch("%((%d+),(%d+)%)") do
    n = n + 1
    result[n] = { tonumber(x), tonumber(y) }
  end

  return result
end

function M.genEventId()
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local id = {}
  for _ = 1, 9 do
    local idx = math.random(#chars)
    id[#id + 1] = chars:sub(idx, idx)
  end
  return table.concat(id)
end

function M.mapEvent(plain)
  local result = {}

  -- 1. Extract the leading id (before first comma)
  local id = plain:match("^([^,]+),")

  local plainCtx = (plain:match("%[(.-)%]"))

  if plainCtx == nil then
    return {}
  end

  -- 2. Extract the event list inside [ ... ]
  local wrappedPlainCtx = ("[" .. plainCtx .. "]")
  local ctxs = M.mapCtx(wrappedPlainCtx)

  -- 3. Extract all remaining numeric fields AFTER the event list
  local afterEvents = plain:match("%]%s*,(.*)")
  local numbers = {}

  if afterEvents then
    for num in afterEvents:gmatch("([^,]+)") do
      local n = tonumber(num)
      if n then
        table.insert(numbers, n)
      end
    end
  end

  -- We only care about:
  -- numbers[1] / numbers[2] = start
  -- numbers[3] / numbers[4] = stop
  local startNum = numbers[1] or 0
  local startDen = numbers[2] or 1
  local stopNum = numbers[3] or 0
  local stopDen = numbers[4] or 1

  local wholeStart = startNum / startDen
  local wholeStop = stopNum / stopDen

  -- 4. Parse each (col, len) pair inside the event list
  for _, ctx in ipairs(ctxs) do
    local eventKey = M.genEventId()

    result[eventKey] = {
      id = id,
      eventId = ctx[2] - 1,
      colStart = ctx[1] + 1,
      whole = {
        start = wholeStart,
        stop = wholeStop,
      },
    }
  end

  return result
end

---@return TidalEvent[]
function M.parse(line)
  return M.mapEvent(line)
end

return M

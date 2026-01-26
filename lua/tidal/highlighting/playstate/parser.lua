local M = {}

---@param input string
---@return string[] # {col, whole, id}
function M.extract(input)
  local col = input:match("^(%b[])")
  if not col then
    return { "", "", "" }
  end

  local after_col = input:sub(#col + 1)
  local whole = after_col:match("^(.-)|")
  whole = whole or ""

  local id = input:match('_id_:%s*"([^"]+)"') or ""

  return { col, whole, id }
end

local function tupleToNumber(tuple)
  -- remove surrounding parentheses
  local inner = tuple:sub(2, -2)

  -- split "cycle,fraction"
  local cycle, frac = inner:match("^%s*(-?%d+)%s*,%s*(%d+/%d+)%s*$")
  if not cycle or not frac then
    return nil
  end

  local num, den = frac:match("^(%d+)%/(%d+)$")
  if not num or not den then
    return nil
  end

  return tonumber(cycle) + tonumber(num) / tonumber(den)
end

function M.mapWhole(plain)
  if not plain then
    return nil
  end

  local first, last

  for tuple in plain:gmatch("%(%s*-?%d+%s*,%s*%d+/%d+%s*%)") do
    if not first then
      first = tuple
    end
    last = tuple
  end

  if not first or not last then
    return nil
  end

  return {
    start = tupleToNumber(first),
    stop = tupleToNumber(last),
  }
end

function M.mapPos(str)
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

---@return TidalEvent[]
function M.parse(line)
  local extracted = M.extract(line)
  local pos = M.mapPos(extracted[1])
  local result = {}

  if #line > 0 then
    for i = 1, #pos, 2 do
      local colStart = pos[i][1] + 1
      local eventId = pos[i][2] - 1
      local whole = M.mapWhole(extracted[2])
      result[M.genEventId()] = {
        id = extracted[3],
        colStart = colStart,
        eventId = eventId,
        whole = whole,
      }
    end
  end

  return result
end

return M

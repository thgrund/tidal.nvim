local M = {}

function M.extract(input)
  local col = {}
  local whole = {}
  local id = {}

  local i = 1

  while i <= #input do
    local ch = string.sub(input, i, i)

    -- parse col: [((8,2),(18,2)))]
    if ch == "[" then
      table.insert(col, ch)
      i = i + 1
      repeat
        ch = string.sub(input, i, i)
        table.insert(col, ch)
        i = i + 1
      until ch == "]"

      -- parse whole: everything until '|'
      while i <= #input do
        ch = string.sub(input, i, i)
        if ch == "|" then
          break
        end
        table.insert(whole, ch)
        i = i + 1
      end

    -- parse id: after '_id_: "' until closing quote
    elseif string.sub(input, i, i + 4) == "_id_:" then
      -- skip to the first quote
      i = i + 6
      while string.sub(input, i, i) ~= '"' do
        i = i + 1
      end
      i = i + 1 -- skip opening quote
      repeat
        ch = string.sub(input, i, i)
        table.insert(id, ch)
        i = i + 1
      until ch == '"'
      table.remove(id, #id) -- remove the closing quote
    else
      i = i + 1
    end
  end

  return {
    table.concat(col),
    table.concat(whole),
    table.concat(id),
  }
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

  local tuples = {}

  for tuple in plain:gmatch("%(%s*-?%d+%s*,%s*%d+/%d+%s*%)") do
    table.insert(tuples, tuple)
  end

  if #tuples < 2 then
    return nil
  end

  return {
    start = tupleToNumber(tuples[1]),
    stop = tupleToNumber(tuples[#tuples]),
  }
end

function M.mapPos(str)
  local result = {}

  -- match every (number,number) inside the string
  for x, y in str:gmatch("%((%d+),(%d+)%)") do
    table.insert(result, { tonumber(x), tonumber(y) })
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

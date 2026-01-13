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

local function split(str, seps)
  local result = {}

  -- convert single string separator to table
  if type(seps) == "string" then
    seps = { seps }
  end

  -- escape special pattern characters
  local pattern_seps = {}
  for _, s in ipairs(seps) do
    s = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    table.insert(pattern_seps, s)
  end

  -- build pattern: match sequences not containing any separator
  local pattern = "[^" .. table.concat(pattern_seps) .. "]+"

  -- match all parts
  for part in string.gmatch(str, pattern) do
    -- remove all brackets from the part
    part = part:gsub("[%[%]%(%)]", "")
    table.insert(result, part)
  end

  return result
end

local fractionToDecimal = {
  ["½"] = 0.5,
  ["⅓"] = 0.333,
  ["⅔"] = 0.666,
  ["¼"] = 0.25,
  ["¾"] = 0.75,
  ["⅕"] = 0.2,
  ["⅖"] = 0.4,
  ["⅗"] = 0.6,
  ["⅘"] = 0.8,
  ["⅙"] = 0.166,
  ["⅚"] = 0.833,
  ["⅐"] = 0.142,
  ["⅛"] = 0.125,
  ["⅜"] = 0.375,
  ["⅝"] = 0.625,
  ["⅞"] = 0.875,
  ["⅑"] = 0.111,
  ["⅒"] = 0.1,
}

local function replaceFractions(str)
  for unicode, decimal in pairs(fractionToDecimal) do
    str = str:gsub(unicode, tostring(decimal))
  end
  return str:gsub("0%.", ".")
end

function M.mapWhole(plain)
  -- split string based on space
  --
  --

  plain = replaceFractions(plain)

  local splitted = split(plain, { "-", ">" })

  if #splitted >= 2 then
    return { start = tonumber(splitted[1]), stop = tonumber(splitted[#splitted]) }
  end
end
function M.mapPos(str)
  local result = {}

  -- match every (number,number) inside the string
  for x, y in str:gmatch("%((%d+),(%d+)%)") do
    table.insert(result, { tonumber(x), tonumber(y) })
  end

  return result
end

function M.parse(line)
  local extracted = M.extract(line)
  local pos = M.mapPos(extracted[1])
  local result = {}

  for i = 1, #pos, 2 do
    table.insert(result, {
      id = extracted[3],
      colStart = pos[i][1],
      eventId = pos[i][2],
      whole = M.mapWhole(extracted[2]),
    })
  end

  return result
end

M._replaceFractions = replaceFractions

return M

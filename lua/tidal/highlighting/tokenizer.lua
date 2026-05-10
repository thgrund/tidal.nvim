local Tokenizer = {}

local lineProcessor = require("tidal.highlighting.lineprocessor")
local marker = require("tidal.highlighting.marker")

Tokenizer.eventIdBase = 0
Tokenizer.lastEventId = Tokenizer.eventIdBase

-- Public function to transform control patterns into deltaContext format
-- @param line string: The input line to process
-- @param eventId number: The event ID to use in deltaContext
-- @return string: The transformed line with deltaContext format
function Tokenizer.addDeltaContext(line, eventId)
  -- Ignore lines that start with a colon (e.g., :load "test.hs")
  if line:match("^:") then
    return line
  end

  local result = line:gsub(lineProcessor.controlPatternsRegex(), function(startPos, content, _)
    local before = line:sub(1, startPos - 1)

    if before:match(lineProcessor.exceptedFunctionPatterns()) then
      return '"' .. content .. '"'
    end

    return string.format('(deltaContext %i %i "%s")', startPos - 1, eventId, content)
  end)

  return result
end

local function findReplacementRanges(line)
  local replacements = {}
  lineProcessor.findTidalWordRanges(line, function(replacement)
    table.insert(replacements, replacement)
  end)

  return replacements
end

local function updateEventId()
  Tokenizer.lastEventId = Tokenizer.lastEventId + 1
end

function Tokenizer.addMetadata(line, lineNumber)
  local replacements = findReplacementRanges(line)

  if #replacements > 0 then
    -- 1. cleanUpMarkers
    -- 2. updateEventId
    -- 3. create position markers
    -- 4. addDeltaContext
    --
    updateEventId()
    marker.createMarkers(replacements, lineNumber, Tokenizer.lastEventId)
    return Tokenizer.addDeltaContext(line, Tokenizer.lastEventId)
  else
    return line
  end
end

return Tokenizer

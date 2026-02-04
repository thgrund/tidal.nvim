local PlayStateProcessor = {}

local highlight = require("tidal.highlighting.highlights")
local marker = require("tidal.highlighting.marker")
local state = require("tidal.core.state")

local INIT_PLAYSTATE = "init"
local EXTEND_PLAYSTATE = "extend"

---@type table<string, TidalEvent>
local currentPlayState = {}

--- @type table<string, TidalEvent>
local activeEvents = {}

PlayStateProcessor.sam = 0
PlayStateProcessor.interval = nil
PlayStateProcessor._lastReceivedPlayState = nil
PlayStateProcessor._currentPlayState = {}

PlayStateProcessor.handleMessageCallback = nil

local uv = vim.loop
local socket_path = "/tmp/tidal.sock"

---
--- @param sam number
--- @param prevActive table<string, TidalEvent>
--- @param current table<string, TidalEvent>
local function diff(sam, prevActive, current)
  local remove = {}
  local add = {}
  local active = {}

  if sam ~= nil then
    if next(current) ~= nil then
      for key, _ in pairs(prevActive) do
        if current[key] == nil then
          table.insert(remove, key)
        end
      end
    end
    for key, tidalEvent in pairs(current) do
      if tidalEvent ~= nil and tidalEvent.whole ~= nil then
        if tidalEvent.whole.stop <= sam then
          table.insert(remove, key)
        end

        if tidalEvent.whole.start <= sam and tidalEvent.whole.stop >= sam then
          if prevActive[key] == nil then
            table.insert(add, key)
          end

          if prevActive[key] ~= nil then
            table.insert(active, key)
          end
        end
      end
    end
  end

  return {
    remove = remove,
    add = add,
    active = active,
  }
end

--- @param active table<string, TidalEvent>
--- @param current table<string, TidalEvent>
local function updateActive(active, current)
  local removable = {}
  local keepable = {}
  local currentLookup = {}

  -- Build a lookup table for current events using a composite key
  -- This reduces complexity from O(n²) to O(n + m)
  for currentId, currentEvent in pairs(current) do
    if currentEvent and currentEvent.whole then
      local key = string.format(
        "%d_%d_%.6f_%.6f_%s",
        currentEvent.eventId,
        currentEvent.colStart,
        currentEvent.whole.start,
        currentEvent.whole.stop,
        currentEvent.id or ""
      )
      currentLookup[key] = { id = currentId, event = currentEvent }
    end
  end

  -- Check each active event against the lookup table
  for activeId, activeEvent in pairs(active) do
    if activeEvent and activeEvent.whole then
      local key = string.format(
        "%d_%d_%.6f_%.6f_%s",
        activeEvent.eventId,
        activeEvent.colStart,
        activeEvent.whole.start,
        activeEvent.whole.stop,
        activeEvent.id or ""
      )

      local found = currentLookup[key]
      if found then
        keepable[found.id] = found.event
      else
        removable[activeId] = activeEvent
      end
    else
      removable[activeId] = activeEvent
    end
  end

  return { removable = removable, active = keepable }
end

---@param id string
---@return TidalExtMark?
local function getExtMark(id, playState)
  local extmark

  if playState[id] ~= nil then
    local eventId = playState[id].eventId
    local colStart = playState[id].colStart

    if marker.extMarks[eventId] and marker.extMarks[eventId][colStart] then
      extmark = marker.extMarks[eventId][colStart]
      extmark.id = playState[id].id
    end
  end

  return extmark
end

local function cleanHighlights(removableEvents)
  for id, _ in pairs(removableEvents) do
    local extmark = getExtMark(id, removableEvents)

    if extmark ~= nil then
      highlight.removeHighlight(extmark.buf, extmark.markerId)
    end
  end
end

function PlayStateProcessor.setSam(sam)
  if sam == nil then
    return
  end

  local prevSam = PlayStateProcessor.sam

  PlayStateProcessor.sam = sam

  if prevSam == nil then
    PlayStateProcessor.init()
  end

  local intSam = math.floor(sam)

  if prevSam ~= nil and math.floor(prevSam) ~= intSam and next(currentPlayState) ~= nil then
    PlayStateProcessor.getPlayState(intSam + 3, intSam + 4, EXTEND_PLAYSTATE)
  end
end

function PlayStateProcessor.handleEvents()
  local events = diff(PlayStateProcessor.sam, activeEvents, currentPlayState)

  local activeMessages = {}

  for _, id in ipairs(events.remove) do
    local removeCandidate = activeEvents[id]
    local shallBeRemoved = true

    if removeCandidate == nil then
      shallBeRemoved = false
    else
      for _, event in pairs(activeEvents) do
        if
          event ~= nil
          and event.whole ~= nil
          and removeCandidate.whole ~= nil
          and event.colStart == removeCandidate.colStart
          and event.eventId == removeCandidate.eventId
          and event.whole.stop > removeCandidate.whole.stop
        then
          shallBeRemoved = false
        end
      end
    end

    if shallBeRemoved then
      local extmark = getExtMark(id, activeEvents)

      if extmark ~= nil then
        highlight.removeHighlight(extmark.buf, extmark.markerId)
      end
    end

    activeEvents[id] = nil
    currentPlayState[id] = nil
  end

  for _, id in ipairs(events.add) do
    local extmark = getExtMark(id, currentPlayState)

    activeEvents[id] = currentPlayState[id]

    if extmark ~= nil then
      highlight.addHighlight(extmark.id, extmark.buf, extmark.markerId)
      table.insert(activeMessages, extmark)
    end
  end

  for _, id in ipairs(events.active) do
    local extmark = getExtMark(id, currentPlayState)

    if extmark ~= nil then
      table.insert(activeMessages, extmark)
    end
  end

  if PlayStateProcessor.handleMessageCallback then
    PlayStateProcessor.handleMessageCallback(activeMessages)
  end
end

local function handleInit(events)
  currentPlayState = events

  local updatedEvents = updateActive(activeEvents, currentPlayState)
  cleanHighlights(updatedEvents.removable)

  activeEvents = updatedEvents.active

  PlayStateProcessor._currentPlayState = currentPlayState

  marker.cleanUpMarkers()
end

local function handleExtend(events)
  for key, parsed in pairs(events) do
    currentPlayState[key] = parsed
  end
end

function PlayStateProcessor.launch()
  if vim.fn.filereadable(socket_path) == 1 then
    os.remove(socket_path)
  end

  local server = uv.new_pipe(false)
  server:bind(socket_path)

  server:listen(128, function(err)
    assert(not err, err)

    local client = uv.new_pipe(false)
    server:accept(client)

    local buffer = ""
    local expected_len = nil

    client:read_start(function(err, data)
      assert(not err, err)

      if not data then
        client:close()
        return
      end

      buffer = buffer .. data

      while true do
        -- Read 4-byte big-endian length prefix
        if not expected_len then
          if #buffer < 4 then
            return
          end

          local b1, b2, b3, b4 = buffer:byte(1, 4)
          expected_len = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4

          buffer = buffer:sub(5)
        end

        -- Wait for full payload
        if #buffer < expected_len then
          return
        end

        local payload = buffer:sub(1, expected_len)
        buffer = buffer:sub(expected_len + 1)
        expected_len = nil

        vim.schedule(function()
          local decodedData = vim.mpack.decode(payload)

          if decodedData.type == INIT_PLAYSTATE then
            handleInit(decodedData.events)
          elseif decodedData.type == EXTEND_PLAYSTATE then
            handleExtend(decodedData.events)
          end
        end)
      end
    end)
  end)

  print("Tidal socket server listening on " .. socket_path)
end
--   -- EXTEND
--       PlayStateProcessor._lastReceivedPlayState = output
--
--       local parsedOutput = PlayStateProcessor.parse(output)
--
--       for key, parsed in pairs(parsedOutput) do
--         currentPlayState[key] = parsed
--       end
--
--       PlayStateProcessor._currentPlayState = currentPlayState
--
--       return
--
--   ----
--   ---INIT
--
--       PlayStateProcessor._lastReceivedPlayState = output
--
--       local parsedOutput = PlayStateProcessor.parse(output)
--
--       currentPlayState = parsedOutput
--
--       local updatedEvents = updateActive(activeEvents, currentPlayState)
--       cleanHighlights(updatedEvents.removable)
--
--       activeEvents = updatedEvents.active
--
--       PlayStateProcessor._currentPlayState = currentPlayState
--
--       marker.cleanUpMarkers()
--
-- end

function PlayStateProcessor.init()
  local sam = PlayStateProcessor.sam

  if sam ~= nil and next(currentPlayState) == nil then
    local intSam = math.floor(sam)
    PlayStateProcessor.getPlayState(intSam, intSam + 5, INIT_PLAYSTATE)
  end
end

function PlayStateProcessor.reset()
  currentPlayState = {}
  PlayStateProcessor.sam = nil
end

---Requests the playstate from TidalCycles
---@param start integer
---@param stop integer
function PlayStateProcessor.getPlayState(start, stop, lock)
  if start and stop then
    --print(string.format([[sendMessage $ createMsgPack (Arc %f %f) "%s" ]], start, stop, lock))
    state.ghci.stdin:write(string.format('\n:{\nsendMessage $ createMsgPack (Arc %f %f) "%s"\n:}\n', start, stop, lock))
  end
end

PlayStateProcessor._updateActive = updateActive
return PlayStateProcessor

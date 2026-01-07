local Events = {}

function Events.merge(t1, t2)
  local res = {}
  for _, v in ipairs(t1) do
    table.insert(res, v)
  end
  for _, v in ipairs(t2) do
    table.insert(res, v)
  end
  return res
end

local function buildMap(events)
  local map = {}
  for _, evt in ipairs(events) do
    local key = evt.buf .. ":" .. evt.markerId
    map[key] = evt
  end
  return map
end

function Events.diffEventLists(prevEvents, currentEvents)
  local removed = {}
  local added = {}
  local active = {}

  local prevMap = buildMap(prevEvents)
  local currMap = buildMap(currentEvents)

  -- Check removed and active
  for key, prevEvt in pairs(prevMap) do
    local currEvt = currMap[key]
    if currEvt then
      table.insert(active, prevEvt) -- still valid
    else
      table.insert(removed, prevEvt)
    end
  end

  -- Check added
  for key, currEvt in pairs(currMap) do
    if not prevMap[key] then
      table.insert(added, currEvt)
    end
  end

  return {
    removed = removed,
    added = added,
    active = active,
  }
end

return Events

-- Capped SavedVariables ring buffer for /cs debug events.
-- Production detection does not depend on this module.

CrusaderStrikeDebugEvents = CrusaderStrikeDebugEvents or {}
local DE = CrusaderStrikeDebugEvents

local MAX_ENTRIES = 500
local enabled = false

local function db()
  CrusaderStrikeDB = CrusaderStrikeDB or {}
  CrusaderStrikeDB.debugEvents = CrusaderStrikeDB.debugEvents or {
    enabled = false,
    entries = {},
  }
  return CrusaderStrikeDB.debugEvents
end

function DE.IsEnabled()
  return db().enabled and true or false
end

function DE.SetEnabled(on)
  local d = db()
  d.enabled = on and true or false
  enabled = d.enabled
  if not d.entries then
    d.entries = {}
  end
  return d.enabled
end

function DE.Clear()
  db().entries = {}
end

function DE.Note(eventName, unixTime, args)
  local d = db()
  if not d.enabled then
    return
  end
  d.entries = d.entries or {}
  local entry = {
    event = eventName,
    t = unixTime,
    args = args or {},
  }
  d.entries[#d.entries + 1] = entry
  while #d.entries > MAX_ENTRIES do
    table.remove(d.entries, 1)
  end
end

function DE.Count()
  local e = db().entries
  return e and #e or 0
end

function DE.Entries()
  return db().entries or {}
end

-- Compact one-line summary suitable for chat / screenshot.
function DE.Summarize(limit)
  limit = limit or 40
  local entries = DE.Entries()
  local lines = {}
  local start = math.max(1, #entries - limit + 1)
  local counts = {}
  for _, e in ipairs(entries) do
    counts[e.event] = (counts[e.event] or 0) + 1
  end
  lines[#lines + 1] = string.format("debugEvents n=%d enabled=%s", #entries, tostring(DE.IsEnabled()))
  local keys = {}
  for k in pairs(counts) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = k .. "=" .. counts[k]
  end
  lines[#lines + 1] = "counts: " .. table.concat(parts, ", ")
  for i = start, #entries do
    local e = entries[i]
    local a = e.args or {}
    local detail = {}
    if a.encounterID then detail[#detail + 1] = "id=" .. tostring(a.encounterID) end
    if a.encounterName then detail[#detail + 1] = tostring(a.encounterName) end
    if a.success ~= nil then detail[#detail + 1] = "success=" .. tostring(a.success) end
    if a.npcId then detail[#detail + 1] = "npc=" .. tostring(a.npcId) end
    if a.name then detail[#detail + 1] = tostring(a.name) end
    if a.unit then detail[#detail + 1] = tostring(a.unit) end
    if a.cleuCallable ~= nil then detail[#detail + 1] = "cleu=" .. tostring(a.cleuCallable) end
    if a.detail then detail[#detail + 1] = tostring(a.detail) end
    if a.subevent then detail[#detail + 1] = tostring(a.subevent) end
    lines[#lines + 1] = string.format("%d %s %s", e.t or 0, e.event or "?", table.concat(detail, " "))
  end
  return table.concat(lines, "\n")
end

-- Bridge used by DungeonLog (CS.DebugEvents.Note).
CrusaderStrike = CrusaderStrike or {}
CrusaderStrike.DebugEvents = {
  Note = function(eventName, unixTime, args)
    DE.Note(eventName, unixTime, args)
  end,
  IsEnabled = DE.IsEnabled,
  SetEnabled = DE.SetEnabled,
  Summarize = DE.Summarize,
  Clear = DE.Clear,
  Count = DE.Count,
}

return DE

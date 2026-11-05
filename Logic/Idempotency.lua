-- Pure helpers for run identity. Safe to unit-test without WoW APIs.

CrusaderStrikeIdempotency = CrusaderStrikeIdempotency or {}

local SEP = "|"

-- Idempotency key: realm + character + start time + instance id
-- startTimeUnix is integer seconds (GetServerTime / time()).
function CrusaderStrikeIdempotency.MakeKey(realm, character, startTimeUnix, instanceId)
  assert(realm and realm ~= "", "realm required")
  assert(character and character ~= "", "character required")
  assert(type(startTimeUnix) == "number", "startTimeUnix must be number")
  assert(instanceId ~= nil, "instanceId required")
  return table.concat({
    tostring(realm),
    tostring(character),
    tostring(math.floor(startTimeUnix)),
    tostring(instanceId),
  }, SEP)
end

function CrusaderStrikeIdempotency.ParseKey(key)
  if type(key) ~= "string" then
    return nil
  end
  local realm, character, startTime, instanceId = key:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
  if not realm then
    return nil
  end
  return {
    realm = realm,
    character = character,
    startTimeUnix = tonumber(startTime),
    instanceId = tonumber(instanceId) or instanceId,
  }
end

-- Platform ingest uses addon_run_id; we use the idempotency key as that id.
function CrusaderStrikeIdempotency.ToAddonRunId(key)
  return key
end

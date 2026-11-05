--[[
  CSGEAR1 encode/decode + validation (pure Lua 5.1).
  Envelope: CSGEAR1:<base64(compact UTF-8 JSON, sorted keys)>|c=<8 hex FNV-1a>

  Forever 1.60.1 |Hitem:| field order (best-effort; confirm in game — addon#26):
    [1] item_id
    [2] enchant_id
    [3] gem1 / jewel1 (often 0 on Forever)
    [4] gem2
    [5] gem3
    [6] gem4
    [7] suffix_id (random-property suffix; 0 if none)
    [8] unique_id / creation context
    [9] link_level (optional; may be absent on short links)
  Parsing is defensive: only [1] and [2] are required for CSGEAR1 equipped export.
  Suffix/gems are documented here so #26 can confirm positions without guessing.
]]

CrusaderStrikeGearEncoder = CrusaderStrikeGearEncoder or {}
local GE = CrusaderStrikeGearEncoder

local PREFIX = "CSGEAR1:"
local CSGEAR_VERSION = 1
local PASTE_MAX = 24 * 1024
local JSON_MAX = 16 * 1024
local REGION_ALLOW = {
  us = true, eu = true, kr = true, tw = true, cn = true,
}

-- Best-effort Forever |Hitem:| indices (1-based). Confirm in game (addon#26).
GE.ITEM_LINK_FIELDS = {
  item_id = 1,
  enchant_id = 2,
  gem1 = 3,
  gem2 = 4,
  gem3 = 5,
  gem4 = 6,
  suffix_id = 7,
  unique_id = 8,
  link_level = 9,
}

--[[
  Parse a WoW item link / chat hyperlink. Returns {item_id, enchant_id?} or nil.
  Never trusts display names. Suffix/gems are not exported in CSGEAR1 v1.
]]
function GE.ParseItemLink(link)
  if type(link) ~= "string" then
    return nil
  end
  local body = link:match("|Hitem:([^|]+)|h")
  if not body then
    return nil
  end
  local parts = {}
  for part in (body .. ":"):gmatch("([^:]*):") do
    parts[#parts + 1] = part
  end
  local itemId = tonumber(parts[GE.ITEM_LINK_FIELDS.item_id])
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) or itemId > 2147483647 then
    return nil
  end
  local out = { item_id = itemId }
  local enchant = tonumber(parts[GE.ITEM_LINK_FIELDS.enchant_id])
  if enchant and enchant >= 0 and enchant == math.floor(enchant) then
    out.enchant_id = enchant
  end
  return out
end

-- Player-facing reject / reason strings for /cs import, gear UI, and companion sync.
local REJECT_MESSAGES = {
  bad_prefix = "Not a CSGEAR1 string (wrong prefix).",
  wrong_version = "Gear string version is not supported (this addon reads CSGEAR1 only) — update the addon or export again.",
  truncated = "Gear string is incomplete or truncated — copy the whole CSGEAR1 line including the |c= checksum.",
  unknown_item = "Gear string has an unknown item ID — remove it on the website and export again.",
  bad_checksum = "Gear string checksum failed — copy the whole CSGEAR1 line.",
  too_large = "Gear string is too large to import.",
  bad_json = "Gear string is corrupted or not valid JSON.",
  schema = "Gear string schema/game version is not supported (need forever, schema 1).",
  character_mismatch = "This gear string is for a different character. Log into that character, or export again from the website for this one.",
  item_not_forever = "A gear set includes an item that is not a WoW Forever item. Remove it on the website and export again.",
  list_limit_reached = "You already have 20 gear sets on this character. Delete one before creating or importing more.",
  validation = "Gear string failed validation (name, slots, levels, or ids).",
  encoder = "Gear encoder is unavailable.",
  -- until_level / create (Forever rules)
  until_level_required = "Leveling sets need an Up to level above your current level.",
  until_level_out_of_range = "Up to level must be between 1 and 60.",
  until_level_not_above_current_level = "Up to level must be above your current character level.",
  until_level_must_be_null = "Max-level sets do not use an Up to level.",
  leveling_set_at_max_level = "At level 60 only max-level gear sets can be created.",
  -- companion /sync transport + session (no silent fail; pending kept for retry)
  api_unavailable = "Crusader Strike API is unreachable. Gear changes are saved locally and will retry.",
  api_down = "Crusader Strike API is unreachable. Gear changes are saved locally and will retry.",
  network_error = "Network error reaching Crusader Strike. Gear changes are saved locally and will retry.",
  session_expired = "Your website session expired. Sign in again on crusaderstrike.com; local gear changes are kept.",
  token_expired = "Your website session expired. Sign in again on crusaderstrike.com; local gear changes are kept.",
  unauthorized = "Not signed in to Crusader Strike. Sign in on the website; local gear changes are kept.",
  unauthenticated = "Not signed in to Crusader Strike. Sign in on the website; local gear changes are kept.",
  -- platform#51/#52 stable codes (gear-lists /ops /sync, selection, items)
  upstream_unavailable = "Crusader Strike or Battle.net is temporarily unavailable. Gear changes are saved locally and will retry.",
  rate_limited = "Crusader Strike rate limit reached. Gear changes are saved locally; try again soon.",
  version_mismatch = "This gear set changed on the website. Local changes are kept — sync again to reload and retry.",
  -- Client-side alias for the live x-error-code version_mismatch (also stale_base_version
  -- op conflicts). Not itself a live x-error-code.
  version_conflict = "This gear set changed on the website. Local changes are kept — sync again to reload and retry.",
  -- Client-side code for soft-ignored op keys (GearOpsResult.ignored[] on a 2xx); not a live
  -- x-error-code and never a FailSync by itself.
  ignored_op = "The server ignored some fields on a gear sync op. Local gear changes are kept.",
  -- character_mismatch (listed above) is an import / run-upload reject; gear /ops does not
  -- currently return it as a 409, but reuse the copy if a companion ever surfaces it.
  internal_error = "Crusader Strike hit an unexpected error. Gear changes are saved locally and will retry.",
  -- platform#54 field-map (validation / malformed JSON) — non-retryable
  invalid_json = "Crusader Strike rejected the sync payload (invalid JSON). Gear changes are saved locally; update the companion/addon and try again.",
  validation_error = "Crusader Strike rejected the sync request (validation). Gear changes are saved locally; fix the request or update and try again.",
}

function GE.RejectMessage(code)
  if code == nil then
    return "Import rejected."
  end
  local msg = REJECT_MESSAGES[code]
  if msg then
    return msg
  end
  return "Import rejected (" .. tostring(code) .. ")."
end

-- One-line chat text for a failed /cs import: "Import failed: <what> (<detail>)".
function GE.ImportErrorLine(code, detail)
  local msg = GE.RejectMessage(code)
  if detail ~= nil and detail ~= "" then
    msg = msg .. " (" .. tostring(detail) .. ")"
  end
  msg = msg:gsub("[\r\n]+", " ")
  return "Import failed: " .. msg
end

-- Companion /sync player-facing text (sync-specific fallback; not "Import rejected").
function GE.SyncErrorMessage(code)
  local msg = REJECT_MESSAGES[code]
  if msg then
    return msg
  end
  if code == nil or code == "" then
    return REJECT_MESSAGES.api_unavailable
  end
  return "Crusader Strike sync failed (" .. tostring(code) .. "). Gear changes are saved locally and will retry."
end

local MONTHS = {
  jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
  jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
}

-- Days since 1970-01-01 for a proleptic Gregorian civil date (UTC, no os.time TZ).
local function days_from_civil(y, m, d)
  if m <= 2 then
    y = y - 1
  end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

--[[
  Parse an HTTP-date (RFC 9110 §5.6.7) into a UTC epoch. Accepts IMF-fixdate
  ("Sun, 06 Nov 1994 08:49:37 GMT"), obsolete RFC 850
  ("Sunday, 06-Nov-94 08:49:37 GMT") and asctime ("Sun Nov  6 08:49:37 1994").
]]
function GE.ParseHttpDate(v)
  if type(v) ~= "string" then
    return nil
  end
  local d, mon, y, hh, mm, ss = v:match("^%a+,%s*(%d%d?)%s+(%a%a%a)%s+(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s+GMT$")
  if not d then
    d, mon, y, hh, mm, ss = v:match("^%a+,%s*(%d%d?)%-(%a%a%a)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)%s+GMT$")
    if d then
      y = tonumber(y)
      y = (y < 70) and (2000 + y) or (1900 + y)
    end
  end
  if not d then
    mon, d, hh, mm, ss, y = v:match("^%a+%s+(%a%a%a)%s+(%d%d?)%s+(%d%d):(%d%d):(%d%d)%s+(%d%d%d%d)$")
  end
  if not d then
    return nil
  end
  local m = MONTHS[string.lower(mon)]
  d, y, hh, mm, ss = tonumber(d), tonumber(y), tonumber(hh), tonumber(mm), tonumber(ss)
  if not m or d < 1 or d > 31 or hh > 23 or mm > 59 or ss > 60 then
    return nil
  end
  local dim = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local leap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
  if d > ((m == 2 and leap) and 29 or dim[m]) then
    return nil
  end
  return days_from_civil(y, m, d) * 86400 + hh * 3600 + mm * 60 + ss
end

local function current_time()
  if type(GetServerTime) == "function" then
    local t = GetServerTime()
    if type(t) == "number" then
      return t
    end
  end
  if type(time) == "function" then
    return time()
  end
  return os and os.time and os.time() or nil
end

-- Retry-After: delta-seconds (non-negative integer) or HTTP-date → seconds from now.
GE.MAX_RETRY_AFTER = 3600

local function parse_retry_after_raw(v, now)
  if type(v) == "number" and v == math.floor(v) and v >= 0 then
    return v
  end
  if type(v) == "string" then
    v = v:match("^%s*(.-)%s*$")
    local n = tonumber(v)
    if n and v:match("^%d+$") then
      return n
    end
    if n then
      return nil
    end
    local at = GE.ParseHttpDate(v)
    if at then
      now = now or current_time()
      if type(now) ~= "number" then
        return nil
      end
      local delta = at - math.floor(now)
      if delta < 0 then
        delta = 0
      end
      return delta
    end
  end
  return nil
end

-- Clamp to MAX_RETRY_AFTER so a far-future date or huge delta can't stall sync forever.
local function parse_retry_after(v, now)
  local r = parse_retry_after_raw(v, now)
  if r and r > GE.MAX_RETRY_AFTER then
    return GE.MAX_RETRY_AFTER
  end
  return r
end
GE.ParseRetryAfter = parse_retry_after

-- Case-insensitive header lookup (HTTP header names are case-insensitive).
local function header_retry_after(headers, now)
  if type(headers) ~= "table" then
    return nil
  end
  local v = headers["Retry-After"]
  if v == nil then
    for k, hv in pairs(headers) do
      if type(k) == "string" and string.lower(k:match("^%s*(.-)%s*$")) == "retry-after" then
        v = hv
        break
      end
    end
  end
  if type(v) == "table" then
    v = v[1]
  end
  return parse_retry_after(v, now)
end

local function default_retryable(code)
  if code == "unauthenticated" or code == "unauthorized"
      or code == "session_expired" or code == "token_expired"
      or code == "invalid_json" or code == "validation_error"
      or code == "character_mismatch" or code == "ignored_op" then
    return false
  end
  if code == "upstream_unavailable" or code == "api_unavailable"
      or code == "api_down" or code == "network_error"
      or code == "rate_limited" or code == "version_mismatch"
      or code == "version_conflict"
      or code == "internal_error" then
    return true
  end
  return false
end

local function infer_code_from_status(status, hint)
  if status == 401 then
    if type(hint) == "string" then
      local h = string.lower(hint)
      if h:find("expir", 1, true) or h:find("revok", 1, true) or h:find("token", 1, true) then
        return "session_expired"
      end
    end
    return "unauthenticated"
  end
  if status == 400 then
    if type(hint) == "string" then
      local h = string.lower(hint)
      if h:find("invalid_json", 1, true) then
        return "invalid_json"
      end
    end
    return "validation_error"
  end
  if status == 429 then
    return "rate_limited"
  end
  if status == 500 then
    return "internal_error"
  end
  if status == 502 or status == 503 or status == 504 then
    return "upstream_unavailable"
  end
  -- 409 has several stable codes (version_mismatch, character_not_displayed,
  -- list_limit_reached; version_conflict is a client alias and character_mismatch
  -- is not a gear 409 today, but both are matched defensively); only infer
  -- when the hint clearly points at version or character mismatch.
  if status == 409 and type(hint) == "string" then
    local h = string.lower(hint)
    if h:find("character_mismatch", 1, true)
        or (h:find("character", 1, true) and h:find("mismatch", 1, true)) then
      return "character_mismatch"
    end
    if h:find("version", 1, true) or h:find("mismatch", 1, true)
        or h:find("concurrent", 1, true) or h:find("conflict", 1, true) then
      return "version_mismatch"
    end
  end
  return nil
end

--[[
  Normalize platform#51/#52/#54 error envelopes for FailSync / companion /sync.

  Contract (platform#52 / docs/api-errors.md):
    {"error": {"code": "<stable_code>", "message": "...", "retryable": bool, "request_id": "req_…"}}
  Field-map (platform#54 validation / malformed JSON — not the #52 envelope):
    {"errors": {"<field>": "<reason>"}}  e.g. {"errors":{"body":"invalid_json"}}
  Also tolerates legacy shapes (string code, {reason=}, bare http_status / Retry-After).

  input: string code | error table | full body with .error / .errors | nil
  meta:  optional { http_status|status=, retry_after=, headers=, request_id=, retryable= }

  Returns { code, message, retryable, retry_after, request_id, limit, server_message }
  (retry_after / request_id / limit may be nil; meta.now overrides clock for HTTP-date Retry-After). Field-map codes are non-retryable.
]]
function GE.ParseErrorEnvelope(input, meta)
  if type(meta) ~= "table" then
    meta = {}
  end

  local err = input
  local field_map = nil
  if type(input) == "table" and input.error ~= nil then
    err = input.error
  elseif type(input) == "table" and type(input.errors) == "table" then
    -- platform#54 field-map (no nested .error). Prefer over treating the whole
    -- body as a legacy {code/reason} table.
    field_map = input.errors
    err = nil
  end

  local code, server_message, retryable
  local server_detail -- platform#56 top-level human message on field-map 400s
  if field_map ~= nil then
    if type(input.message) == "string" and #input.message > 0 then
      server_detail = input.message
    end
    -- Prefer body=invalid_json → invalid_json; else first field reason (sorted
    -- keys, so the hint is deterministic) / validation_error. Accepts both
    -- string-keyed field-maps and numbered lists ({"errors":["...", ...]}).
    if field_map.body == "invalid_json" then
      code = "invalid_json"
      server_message = "invalid_json"
    else
      code = "validation_error"
      local keys = {}
      for k in pairs(field_map) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta == "number" end
        if ta == "number" or ta == "string" then return a < b end
        return tostring(a) < tostring(b)
      end)
      for _, k in ipairs(keys) do
        local reason = field_map[k]
        if type(reason) == "string" and #reason > 0 then
          server_message = reason
          if reason == "invalid_json" then
            code = "invalid_json"
          end
          break
        end
      end
    end
    retryable = false
  elseif type(err) == "string" then
    code = err
  elseif type(err) == "table" then
    code = err.code or err.reason
    if type(err.message) == "string" and #err.message > 0 then
      server_message = err.message
    end
    if err.retryable ~= nil then
      retryable = not not err.retryable
    end
  elseif err ~= nil then
    code = tostring(err)
  end

  local status = meta.http_status or meta.status
  if type(input) == "table" then
    status = status or input.http_status or input.status
  end
  if type(status) == "string" then
    status = tonumber(status)
  end

  local hint = server_message
  if type(err) == "table" and type(err.reason) == "string" then
    hint = hint or err.reason
  end
  if (code == nil or code == "") and type(status) == "number" then
    code = infer_code_from_status(status, hint)
  end
  if code == nil or code == "" then
    code = "api_unavailable"
  end

  -- Alias legacy / alternate names onto stable codes (api_down/network_error stay distinct).
  if code == "unauthorized" then
    code = "unauthenticated"
  elseif code == "token_expired" then
    code = "session_expired"
  elseif code == "version_conflict" then
    -- platform#62 ops smoke name; HTTP 409 envelope stays version_mismatch.
    code = "version_mismatch"
  end

  local now = meta.now
  local retry_after = parse_retry_after(meta.retry_after, now)
  if retry_after == nil and type(input) == "table" then
    retry_after = parse_retry_after(input.retry_after, now)
  end
  if retry_after == nil and type(err) == "table" then
    retry_after = parse_retry_after(err.retry_after, now)
  end
  if retry_after == nil then
    retry_after = header_retry_after(meta.headers, now)
  end
  if retry_after == nil and type(input) == "table" then
    retry_after = header_retry_after(input.headers, now)
  end

  -- details.limit (e.g. list_limit_reached) when the server provides it.
  local limit
  if type(err) == "table" and type(err.details) == "table" then
    local l = tonumber(err.details.limit)
    if l and l == math.floor(l) and l > 0 then
      limit = l
    end
  end

  -- Explicit retryable from envelope wins; else meta; else code defaults.
  if retryable == nil and meta.retryable ~= nil then
    retryable = not not meta.retryable
  end
  if retryable == nil and type(input) == "table" and input.retryable ~= nil then
    retryable = not not input.retryable
  end
  if retryable == nil then
    retryable = default_retryable(code)
  end

  local request_id
  if type(meta.request_id) == "string" and #meta.request_id > 0 then
    request_id = meta.request_id
  end
  if request_id == nil and type(err) == "table" and type(err.request_id) == "string" and #err.request_id > 0 then
    request_id = err.request_id
  end
  if request_id == nil and type(input) == "table" and type(input.request_id) == "string" and #input.request_id > 0 then
    request_id = input.request_id
  end

  local message = GE.SyncErrorMessage(code)
  -- Prefer catalog copy for known codes; unknown codes may use server message.
  if REJECT_MESSAGES[code] == nil and server_message then
    message = server_message
  end
  if code == "invalid_json" and server_detail then
    message = message .. " Server: " .. server_detail
  end
  if code == "upstream_unavailable" then
    if retry_after ~= nil then
      message = GE.SyncErrorMessage("upstream_unavailable")
        .. " Try again in " .. tostring(retry_after) .. " seconds."
    elseif not retryable then
      message = "Crusader Strike or Battle.net is unavailable right now. Gear changes are saved locally; try again later."
    end
  elseif code == "rate_limited" and retry_after ~= nil then
    message = GE.SyncErrorMessage("rate_limited")
      .. " Try again in " .. tostring(retry_after) .. " seconds."
  elseif code == "internal_error" and retry_after ~= nil then
    message = GE.SyncErrorMessage("internal_error")
      .. " Try again in " .. tostring(retry_after) .. " seconds."
  elseif code == "list_limit_reached" and limit ~= nil then
    message = "You already have " .. tostring(limit)
      .. " gear sets on this character. Delete one before creating or importing more."
  end

  return {
    code = code,
    message = message,
    retryable = retryable,
    retry_after = retry_after,
    request_id = request_id,
    limit = limit,
    server_message = server_detail,
  }
end

local function u32(n)
  n = n % 4294967296
  if n < 0 then
    n = n + 4294967296
  end
  return n
end

local function bxor(a, b)
  a, b = u32(a), u32(b)
  local r, p = 0, 1
  for _ = 1, 32 do
    local abit, bbit = a % 2, b % 2
    if abit ~= bbit then
      r = r + p
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    p = p * 2
  end
  return r
end

-- 32x32 -> 32 multiply without overflowing Lua doubles (mantissa 53 bits).
local function umul32(a, b)
  a, b = u32(a), u32(b)
  local a_lo, a_hi = a % 65536, math.floor(a / 65536)
  local b_lo, b_hi = b % 65536, math.floor(b / 65536)
  local lo = a_lo * b_lo
  local mid = a_hi * b_lo + a_lo * b_hi
  -- (mid << 16) mod 2^32 only needs mid's low 16 bits; a_hi*b_hi << 32 == 0.
  return u32(lo + (mid % 65536) * 65536)
end

function GE.Fnv1a32(data)
  if type(data) ~= "string" then
    return 0
  end
  local h = 2166136261
  for i = 1, #data do
    h = bxor(h, data:byte(i))
    h = umul32(h, 16777619)
  end
  return h
end

function GE.ChecksumHex(data)
  return string.format("%08x", GE.Fnv1a32(data))
end

local function has_control(s)
  if type(s) ~= "string" then
    return true
  end
  for i = 1, #s do
    local b = s:byte(i)
    if b < 32 or b == 127 then
      return true
    end
  end
  return false
end

local function valid_char_name(s)
  if type(s) ~= "string" or s == "" or #s > 48 then
    return false
  end
  if has_control(s) then
    return false
  end
  return s:match("^[A-Za-z0-9 _%-]+$") ~= nil
end

local function valid_local_id(s)
  return type(s) == "string" and s:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

local function valid_uuid(s)
  if s == nil then
    return true
  end
  return type(s) == "string"
    and s:match("^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$") ~= nil
    and #s == 36
end

local function valid_item_id(n)
  return type(n) == "number" and n == math.floor(n) and n >= 1 and n <= 2147483647
end

local function valid_iso(s)
  return type(s) == "string" and s:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil
end

local function validate_slots_map(slots, allow_null, item_known)
  if slots == nil then
    return true
  end
  if type(slots) ~= "table" then
    return false, "validation"
  end
  local GS = CrusaderStrikeGearSlots
  for k, v in pairs(slots) do
    if not GS or not GS.IsValidName(k) then
      return false, "validation"
    end
    if v == nil then
      if not allow_null then
        return false, "validation"
      end
    elseif not valid_item_id(v) then
      return false, "unknown_item", tostring(k) .. "=" .. tostring(v)
    elseif item_known and not item_known(v) then
      return false, "unknown_item", tostring(k) .. "=" .. tostring(v)
    end
  end
  return true
end

local function validate_equipped(equipped)
  if equipped == nil then
    return true
  end
  if type(equipped) ~= "table" then
    return false, "validation"
  end
  local GS = CrusaderStrikeGearSlots
  for k, v in pairs(equipped) do
    if not GS or not GS.IsValidName(k) then
      return false, "validation"
    end
    if type(v) ~= "table" or not valid_item_id(v.item_id) then
      return false, "validation"
    end
    if v.enchant_id ~= nil then
      if type(v.enchant_id) ~= "number" or v.enchant_id < 0 or v.enchant_id ~= math.floor(v.enchant_id) then
        return false, "validation"
      end
    end
  end
  return true
end

local function validate_removes(removes)
  if removes == nil then
    return true
  end
  if type(removes) ~= "table" then
    return false, "validation"
  end
  if #removes > 20 then
    return false, "validation"
  end
  local GS = CrusaderStrikeGearSlots
  for _, op in ipairs(removes) do
    if type(op) ~= "table" or type(op.op) ~= "string" then
      return false, "validation"
    end
    if op.op == "clear_slot" then
      if not GS or not GS.IsValidName(op.slot) then
        return false, "validation"
      end
    elseif op.op == "remove_item" then
      if not GS or not GS.IsValidName(op.slot) or not valid_item_id(op.item_id) then
        return false, "validation"
      end
    else
      return false, "validation"
    end
  end
  return true
end

local function validate_list(list, item_known)
  if type(list) ~= "table" then
    return false, "validation"
  end
  if not valid_local_id(list.local_id) then
    return false, "validation"
  end
  if not valid_uuid(list.id) then
    return false, "validation"
  end
  if type(list.name) ~= "string" then
    return false, "validation"
  end
  local name = list.name:match("^%s*(.-)%s*$") or ""
  if #name < 1 or #name > 64 or has_control(name) then
    return false, "validation"
  end
  if list.type ~= "leveling" and list.type ~= "max_level" then
    return false, "validation"
  end
  if list.type == "leveling" then
    if type(list.until_level) ~= "number"
      or list.until_level ~= math.floor(list.until_level)
      or list.until_level < 1
      or list.until_level > 60 then
      return false, "validation"
    end
  else
    if list.until_level ~= nil then
      return false, "validation"
    end
  end
  if list.role_spec ~= nil then
    if type(list.role_spec) ~= "string" or has_control(list.role_spec) then
      return false, "validation"
    end
    -- Soft-normalize empty / whitespace to null (schema §5).
    local trimmed = list.role_spec:match("^%s*(.-)%s*$") or ""
    if trimmed == "" then
      list.role_spec = nil
    else
      if #trimmed > 32 then
        return false, "validation"
      end
      list.role_spec = trimmed
    end
  end
  if list.edited_at ~= nil and not valid_iso(list.edited_at) then
    return false, "validation"
  end
  if list.edited_in ~= nil and list.edited_in ~= "game" and list.edited_in ~= "web" then
    return false, "validation"
  end
  local ok, code, detail = validate_slots_map(list.slots, true, item_known)
  if not ok then
    return false, code, detail and (tostring(list.name) .. ": " .. detail)
  end
  ok, code = validate_removes(list.removes)
  if not ok then
    return false, code
  end
  return true
end

function GE.ValidatePayload(payload, opts)
  opts = opts or {}
  if type(payload) ~= "table" then
    return false, "bad_json"
  end
  if payload.schema_version ~= 1 then
    return false, "schema"
  end
  if payload.game_version ~= "forever" then
    return false, "schema"
  end
  if type(payload.region) ~= "string" or not REGION_ALLOW[payload.region] then
    return false, "validation"
  end
  if not valid_char_name(payload.realm) or not valid_char_name(payload.character) then
    return false, "validation"
  end
  if opts.expect_realm and opts.expect_character then
    if payload.realm ~= opts.expect_realm or payload.character ~= opts.expect_character then
      return false, "character_mismatch"
    end
  end
  if payload.character_id ~= nil and type(payload.character_id) ~= "string" then
    return false, "validation"
  end
  if payload.exported_at ~= nil and not valid_iso(payload.exported_at) then
    return false, "validation"
  end
  local ok, code = validate_equipped(payload.equipped)
  if not ok then
    return false, code
  end
  if type(payload.lists) ~= "table" then
    return false, "validation"
  end
  if #payload.lists > 20 then
    return false, "validation"
  end
  local seen_names = {}
  for _, list in ipairs(payload.lists) do
    local detail
    ok, code, detail = validate_list(list, opts.item_known)
    if not ok then
      return false, code, detail
    end
    local n = (list.name:match("^%s*(.-)%s*$") or ""):lower()
    if seen_names[n] then
      return false, "validation"
    end
    seen_names[n] = true
  end
  if payload.deleted_lists ~= nil then
    if type(payload.deleted_lists) ~= "table" then
      return false, "validation"
    end
    for _, d in ipairs(payload.deleted_lists) do
      if type(d) ~= "table" then
        return false, "validation"
      end
      local has_id = d.id ~= nil and valid_uuid(d.id) and d.id ~= nil
      local has_local = d.local_id ~= nil and valid_local_id(d.local_id)
      if not has_id and not has_local then
        -- allow id null? schema says {id} or {local_id}
        if d.id ~= nil and not valid_uuid(d.id) then
          return false, "validation"
        end
        if d.local_id ~= nil and not valid_local_id(d.local_id) then
          return false, "validation"
        end
        if d.id == nil and d.local_id == nil then
          return false, "validation"
        end
      end
    end
  end
  -- Optional web echo of server rejections (soft; unknown keys ignored elsewhere).
  -- Shape: rejects: [{ code, item_id?, slot?, message? }, ...]
  if payload.rejects ~= nil then
    if type(payload.rejects) ~= "table" then
      return false, "validation"
    end
    for _, r in ipairs(payload.rejects) do
      if type(r) ~= "table" or type(r.code) ~= "string" or r.code == "" then
        return false, "validation"
      end
      if r.item_id ~= nil and not valid_item_id(r.item_id) then
        return false, "validation"
      end
      if r.slot ~= nil then
        local GS = CrusaderStrikeGearSlots
        if not GS or not GS.IsValidName(r.slot) then
          return false, "validation"
        end
      end
      if r.message ~= nil and (type(r.message) ~= "string" or has_control(r.message) or #r.message > 200) then
        return false, "validation"
      end
    end
  end
  return true
end

-- Normalize CSGEAR1 payload for the live wire schema (explicit nulls + {} maps).
-- Does not mutate the caller's table.
local function wire_null(v)
  local Null = CrusaderStrikeEncoder and CrusaderStrikeEncoder.Null
  if v == nil and Null then
    return Null
  end
  return v
end

local function wire_object(t)
  local AsObject = CrusaderStrikeEncoder and CrusaderStrikeEncoder.AsObject
  if type(t) ~= "table" then
    t = {}
  end
  if AsObject then
    return AsObject(t)
  end
  return t
end

local function wire_payload(payload)
  if type(payload) ~= "table" then
    return payload
  end
  local out = {}
  for k, v in pairs(payload) do
    out[k] = v
  end
  out.character_id = wire_null(payload.character_id)
  -- Game export always carries equipped (possibly {}); web import strings omit it.
  if payload.equipped ~= nil then
    out.equipped = wire_object(payload.equipped)
  else
    out.equipped = nil
  end
  local lists = {}
  for i, list in ipairs(payload.lists or {}) do
    local wl = {}
    for k, v in pairs(list) do
      wl[k] = v
    end
    wl.id = wire_null(list.id)
    wl.until_level = wire_null(list.until_level)
    wl.role_spec = wire_null(list.role_spec)
    local slots = {}
    if type(list.slots) == "table" then
      for sk, sv in pairs(list.slots) do
        slots[sk] = wire_null(sv)
      end
    end
    wl.slots = wire_object(slots)
    if type(list.removes) ~= "table" then
      wl.removes = {}
    end
    lists[i] = wl
  end
  out.lists = lists
  if payload.deleted_lists == nil then
    out.deleted_lists = {}
  end
  return out
end

function GE.Encode(payload)
  if not CrusaderStrikeEncoder or not CrusaderStrikeEncoder.ToJson then
    return nil, "encoder"
  end
  local json = CrusaderStrikeEncoder.ToJson(wire_payload(payload))
  if type(json) ~= "string" then
    return nil, "bad_json"
  end
  if #json > JSON_MAX then
    return nil, "too_large"
  end
  local b64 = CrusaderStrikeEncoder.Base64Encode(json)
  local c = GE.ChecksumHex(json)
  return PREFIX .. b64 .. "|c=" .. c
end

function GE.Decode(exportString, opts)
  if type(exportString) ~= "string" then
    return nil, "bad_prefix"
  end
  exportString = exportString:gsub("^%s+", ""):gsub("%s+$", "")
  -- Allow multi-line paste: pick the CSGEAR1 line
  if not exportString:find("^" .. PREFIX) then
    local line = exportString:match("(CSGEAR1:[^\r\n]+)")
    if line then
      exportString = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
  end
  if #exportString > PASTE_MAX then
    return nil, "too_large"
  end
  if exportString:sub(1, #PREFIX) ~= PREFIX then
    local ver = exportString:match("^CSGEAR(%w*):")
    if ver then
      return nil, "wrong_version", "CSGEAR" .. ver
    end
    return nil, "bad_prefix"
  end
  local rest = exportString:sub(#PREFIX + 1)
  local b64, hex = rest:match("^(.-)|c=([0-9a-fA-F]*)$")
  if not b64 or not hex or #hex ~= 8 then
    return nil, "truncated"
  end
  hex = hex:lower()
  if not CrusaderStrikeEncoder or not CrusaderStrikeEncoder.Base64Decode then
    return nil, "encoder"
  end
  local json, err = CrusaderStrikeEncoder.Base64Decode(b64)
  if not json or #b64 % 4 ~= 0 then
    return nil, "truncated"
  end
  if #json > JSON_MAX then
    return nil, "too_large"
  end
  if GE.ChecksumHex(json) ~= hex then
    return nil, "bad_checksum"
  end
  local payload, jerr = CrusaderStrikeEncoder.FromJson(json)
  if not payload then
    return nil, "bad_json"
  end
  local ok, code, detail = GE.ValidatePayload(payload, opts)
  if not ok then
    return nil, code, detail
  end
  return payload
end

GE.PREFIX = PREFIX
GE.CSGEAR_VERSION = CSGEAR_VERSION
GE.PASTE_MAX = PASTE_MAX
GE.JSON_MAX = JSON_MAX

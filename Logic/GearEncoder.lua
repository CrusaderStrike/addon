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
  bad_checksum = "Gear string checksum failed — copy the whole CSGEAR1 line.",
  too_large = "Gear string is too large to import.",
  bad_json = "Gear string is corrupted or not valid JSON.",
  schema = "Gear string schema/game version is not supported (need forever, schema 1).",
  character_mismatch = "This gear string is for a different character. Log into that character, or export again from the website for this one.",
  item_not_forever = "A gear set includes an item that is not a WoW Forever item. Remove it on the website and export again.",
  list_limit_reached = "You already have 20 gear sets on this character. Delete one before importing more.",
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

local function parse_retry_after(v)
  if type(v) == "number" and v == math.floor(v) and v >= 0 then
    return v
  end
  if type(v) == "string" then
    local n = tonumber(v)
    if n and n == math.floor(n) and n >= 0 then
      return n
    end
  end
  return nil
end

local function header_retry_after(headers)
  if type(headers) ~= "table" then
    return nil
  end
  local v = headers["Retry-After"] or headers["retry-after"] or headers["RETRY-AFTER"]
  return parse_retry_after(v)
end

local function default_retryable(code)
  if code == "unauthenticated" or code == "unauthorized"
      or code == "session_expired" or code == "token_expired"
      or code == "invalid_json" or code == "validation_error" then
    return false
  end
  if code == "upstream_unavailable" or code == "api_unavailable"
      or code == "api_down" or code == "network_error"
      or code == "rate_limited" or code == "version_mismatch"
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
      if h:find("invalid_json", 1, true) or h == "invalid_json" then
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
  -- list_limit_reached); only infer when the hint clearly points at version.
  if status == 409 and type(hint) == "string" then
    local h = string.lower(hint)
    if h:find("version", 1, true) or h:find("mismatch", 1, true) or h:find("concurrent", 1, true) then
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

  Returns { code, message, retryable, retry_after, request_id }
  (retry_after / request_id may be nil). Field-map codes are non-retryable.
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
  if field_map ~= nil then
    -- Prefer body=invalid_json → invalid_json; else first field reason / validation_error.
    local body_reason = field_map.body
    if body_reason == "invalid_json" then
      code = "invalid_json"
      server_message = "invalid_json"
    else
      code = "validation_error"
      -- Surface the first field reason as a hint (stable codes stay validation_error).
      for _, reason in pairs(field_map) do
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

  -- Alias legacy auth names onto platform#51 codes (api_down/network_error stay distinct).
  if code == "unauthorized" then
    code = "unauthenticated"
  elseif code == "token_expired" then
    code = "session_expired"
  end

  local retry_after = parse_retry_after(meta.retry_after)
  if retry_after == nil and type(input) == "table" then
    retry_after = parse_retry_after(input.retry_after)
  end
  if retry_after == nil and type(err) == "table" then
    retry_after = parse_retry_after(err.retry_after)
  end
  if retry_after == nil then
    retry_after = header_retry_after(meta.headers)
  end
  if retry_after == nil and type(input) == "table" then
    retry_after = header_retry_after(input.headers)
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
  end

  return {
    code = code,
    message = message,
    retryable = retryable,
    retry_after = retry_after,
    request_id = request_id,
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

local function validate_slots_map(slots, allow_null)
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
      return false, "validation"
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
  if #removes > 19 then
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

local function validate_list(list)
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
  local ok, code = validate_slots_map(list.slots, true)
  if not ok then
    return false, code
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
    ok, code = validate_list(list)
    if not ok then
      return false, code
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

function GE.Encode(payload)
  if not CrusaderStrikeEncoder or not CrusaderStrikeEncoder.ToJson then
    return nil, "encoder"
  end
  local json = CrusaderStrikeEncoder.ToJson(payload)
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
    return nil, "bad_prefix"
  end
  local rest = exportString:sub(#PREFIX + 1)
  local b64, hex = rest:match("^(.-)|c=([0-9a-fA-F]+)$")
  if not b64 or not hex or #hex ~= 8 then
    return nil, "bad_checksum"
  end
  hex = hex:lower()
  if not CrusaderStrikeEncoder or not CrusaderStrikeEncoder.Base64Decode then
    return nil, "encoder"
  end
  local json, err = CrusaderStrikeEncoder.Base64Decode(b64)
  if not json then
    return nil, "bad_json"
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
  local ok, code = GE.ValidatePayload(payload, opts)
  if not ok then
    return nil, code
  end
  return payload
end

GE.PREFIX = PREFIX
GE.PASTE_MAX = PASTE_MAX
GE.JSON_MAX = JSON_MAX

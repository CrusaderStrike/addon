--[[
  CSGEAR1 encode/decode + validation (pure Lua 5.1).
  Envelope: CSGEAR1:<base64(compact UTF-8 JSON, sorted keys)>|c=<8 hex FNV-1a>
]]

CrusaderStrikeGearEncoder = CrusaderStrikeGearEncoder or {}
local GE = CrusaderStrikeGearEncoder

local PREFIX = "CSGEAR1:"
local PASTE_MAX = 24 * 1024
local JSON_MAX = 16 * 1024
local REGION_ALLOW = {
  us = true, eu = true, kr = true, tw = true, cn = true,
}

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

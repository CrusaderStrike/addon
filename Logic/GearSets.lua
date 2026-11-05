--[[
  Per-character gear sets (CSGEAR1). Stored on CrusaderStrikeCharDB.gearSets.
  Pure helpers where possible; import merge + until_level rules live here.
]]

CrusaderStrikeGearSets = CrusaderStrikeGearSets or {}
local G = CrusaderStrikeGearSets

G.MAX_SETS = 20
G.NAME_MAX = 64
G.ROLE_SPEC_MAX = 32

local function now_iso()
  local t = (GetServerTime and GetServerTime()) or (time and time()) or 0
  -- UTC ISO-8601 Z. os.date("!*t") works under tests; in-game time() is server-ish.
  local d
  if os and os.date then
    d = os.date("!*t", t)
  end
  if not d then
    return string.format("%d-01-01T00:00:00Z", 1970)
  end
  return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", d.year, d.month, d.day, d.hour, d.min, d.sec)
end

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$")) or ""
end

local function has_control(s)
  for i = 1, #s do
    local b = s:byte(i)
    if b < 32 or b == 127 then
      return true
    end
  end
  return false
end

local function new_local_id(existing)
  existing = existing or {}
  for _ = 1, 64 do
    -- Keep ranges small: some Lua 5.1 builds overflow math.random on large spans.
    local id = string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535))
    if not existing[id] then
      return id
    end
  end
  local t = (time and time() or 0) % 65535
  return string.format("%04x%04x", t, (t * 1103515245 + 12345) % 65536)
end

function G.EnsureDB(charDB)
  if type(charDB) ~= "table" then
    return nil
  end
  charDB.gearSets = charDB.gearSets or {
    character_id = nil,
    region = "us",
    lists = {}, -- array
    deleted = {}, -- array of {id=} or {local_id=}
  }
  local bucket = charDB.gearSets
  if type(bucket.lists) ~= "table" then
    bucket.lists = {}
  end
  if type(bucket.deleted) ~= "table" then
    bucket.deleted = {}
  end
  return bucket
end

function G.CountActive(charDB)
  local bucket = G.EnsureDB(charDB)
  if not bucket then
    return 0
  end
  return #bucket.lists
end

function G.FindByLocalId(charDB, local_id)
  local bucket = G.EnsureDB(charDB)
  if not bucket then
    return nil, nil
  end
  for i, list in ipairs(bucket.lists) do
    if list.local_id == local_id then
      return list, i
    end
  end
  return nil, nil
end

function G.FindById(charDB, id)
  if id == nil then
    return nil, nil
  end
  local bucket = G.EnsureDB(charDB)
  if not bucket then
    return nil, nil
  end
  for i, list in ipairs(bucket.lists) do
    if list.id == id then
      return list, i
    end
  end
  return nil, nil
end

function G.ValidateUntilLevel(set_type, until_level, player_level)
  if set_type == "max_level" then
    if until_level ~= nil then
      return false, "until_level_must_be_null"
    end
    return true
  end
  if set_type ~= "leveling" then
    return false, "validation"
  end
  if type(until_level) ~= "number" or until_level ~= math.floor(until_level) then
    return false, "until_level_required"
  end
  if until_level < 1 or until_level > 60 then
    return false, "until_level_out_of_range"
  end
  if type(player_level) == "number" then
    if player_level >= 60 then
      return false, "leveling_set_at_max_level"
    end
    if until_level <= player_level then
      return false, "until_level_not_above_current_level"
    end
  end
  return true
end

function G.NormalizeName(name)
  name = trim(name)
  if #name < 1 or #name > G.NAME_MAX or has_control(name) then
    return nil, "validation"
  end
  return name
end

function G.NormalizeRoleSpec(role_spec)
  if role_spec == nil then
    return nil
  end
  local s = trim(tostring(role_spec))
  if s == "" then
    return nil
  end
  if #s > G.ROLE_SPEC_MAX or has_control(s) then
    return nil, "validation"
  end
  return s
end

local function name_taken(lists, name, except_local_id)
  local lower = name:lower()
  for _, list in ipairs(lists) do
    if list.local_id ~= except_local_id and trim(list.name):lower() == lower then
      return true
    end
  end
  return false
end

function G.CreateSet(charDB, fields, player_level)
  local bucket = G.EnsureDB(charDB)
  if not bucket then
    return nil, "validation"
  end
  if #bucket.lists >= G.MAX_SETS then
    return nil, "list_limit_reached"
  end
  local name, nerr = G.NormalizeName(fields and fields.name)
  if not name then
    return nil, nerr or "validation"
  end
  if name_taken(bucket.lists, name, nil) then
    return nil, "validation"
  end
  local set_type = (fields and fields.type) or "leveling"
  if player_level and player_level >= 60 then
    set_type = "max_level"
  end
  if set_type ~= "leveling" and set_type ~= "max_level" then
    return nil, "validation"
  end
  local until_level = fields and fields.until_level
  if set_type == "max_level" then
    until_level = nil
  end
  local ok, code = G.ValidateUntilLevel(set_type, until_level, player_level)
  if not ok then
    return nil, code
  end
  local role_spec, rerr = G.NormalizeRoleSpec(fields and fields.role_spec)
  if rerr then
    return nil, rerr
  end
  local existing = {}
  for _, list in ipairs(bucket.lists) do
    existing[list.local_id] = true
  end
  local list = {
    id = nil,
    local_id = new_local_id(existing),
    name = name,
    type = set_type,
    until_level = until_level,
    role_spec = role_spec,
    slots = {},
    removes = {},
    edited_at = now_iso(),
    edited_in = "game",
  }
  if type(fields and fields.slots) == "table" then
    for slot, item_id in pairs(fields.slots) do
      if CrusaderStrikeGearSlots and CrusaderStrikeGearSlots.IsValidName(slot) then
        if item_id == nil then
          list.slots[slot] = nil
        elseif type(item_id) == "number" and item_id == math.floor(item_id) and item_id >= 1 then
          list.slots[slot] = item_id
        end
      end
    end
  end
  bucket.lists[#bucket.lists + 1] = list
  return list
end

function G.UpdateSet(charDB, local_id, patch, player_level)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  local bucket = G.EnsureDB(charDB)
  patch = patch or {}

  -- Validate on a draft first so a failed update never partially mutates SV.
  local draft_name = list.name
  local draft_type = list.type
  local draft_until = list.until_level
  local draft_role = list.role_spec

  if patch.name ~= nil then
    local name, nerr = G.NormalizeName(patch.name)
    if not name then
      return nil, nerr or "validation"
    end
    if name_taken(bucket.lists, name, local_id) then
      return nil, "validation"
    end
    draft_name = name
  end
  if patch.type ~= nil then
    if patch.type ~= "leveling" and patch.type ~= "max_level" then
      return nil, "validation"
    end
    draft_type = patch.type
  end
  if draft_type == "max_level" then
    draft_until = nil
  elseif patch.until_level ~= nil then
    draft_until = patch.until_level
  end
  local ok, code = G.ValidateUntilLevel(draft_type, draft_until, player_level)
  if not ok then
    return nil, code
  end
  if patch.role_spec ~= nil then
    local role_spec, rerr = G.NormalizeRoleSpec(patch.role_spec)
    if rerr then
      return nil, rerr
    end
    draft_role = role_spec
  end

  list.name = draft_name
  list.type = draft_type
  list.until_level = draft_until
  list.role_spec = draft_role
  list.edited_at = now_iso()
  list.edited_in = "game"
  return list
end

function G.SetSlot(charDB, local_id, slot, item_id)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  if not CrusaderStrikeGearSlots or not CrusaderStrikeGearSlots.IsValidName(slot) then
    return nil, "validation"
  end
  list.slots = list.slots or {}
  list.removes = list.removes or {}
  if item_id == nil then
    local prev = list.slots[slot]
    list.slots[slot] = nil
    -- explicit clear_slot for sync
    local found = false
    for _, op in ipairs(list.removes) do
      if op.op == "clear_slot" and op.slot == slot then
        found = true
        break
      end
    end
    if not found then
      list.removes[#list.removes + 1] = { op = "clear_slot", slot = slot }
    end
    if prev ~= nil then
      -- also record remove_item when we knew the prior id
      list.removes[#list.removes + 1] = { op = "remove_item", slot = slot, item_id = prev }
    end
  else
    if type(item_id) ~= "number" or item_id ~= math.floor(item_id) or item_id < 1 or item_id > 2147483647 then
      return nil, "validation"
    end
    list.slots[slot] = item_id
    -- drop pending clears for this slot
    local kept = {}
    for _, op in ipairs(list.removes) do
      if not (op.slot == slot and (op.op == "clear_slot" or op.op == "remove_item")) then
        kept[#kept + 1] = op
      end
    end
    list.removes = kept
  end
  list.edited_at = now_iso()
  list.edited_in = "game"
  return list
end

function G.DeleteSet(charDB, local_id)
  local list, idx = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  local bucket = G.EnsureDB(charDB)
  table.remove(bucket.lists, idx)
  if list.id then
    bucket.deleted[#bucket.deleted + 1] = { id = list.id }
  else
    bucket.deleted[#bucket.deleted + 1] = { local_id = list.local_id }
  end
  return true
end

local function copy_list(src)
  local slots = {}
  if type(src.slots) == "table" then
    for k, v in pairs(src.slots) do
      slots[k] = v
    end
  end
  local removes = {}
  if type(src.removes) == "table" then
    for i, op in ipairs(src.removes) do
      removes[i] = {
        op = op.op,
        slot = op.slot,
        item_id = op.item_id,
      }
    end
  end
  return {
    id = src.id,
    local_id = src.local_id,
    name = src.name,
    type = src.type,
    until_level = src.until_level,
    role_spec = src.role_spec,
    slots = slots,
    removes = removes,
    edited_at = src.edited_at,
    edited_in = src.edited_in,
  }
end

function G.BuildExportPayload(charDB, meta)
  local bucket = G.EnsureDB(charDB)
  meta = meta or {}
  local lists = {}
  for i, list in ipairs(bucket.lists) do
    lists[i] = copy_list(list)
  end
  local deleted = {}
  for i, d in ipairs(bucket.deleted) do
    deleted[i] = { id = d.id, local_id = d.local_id }
  end
  local equipped = meta.equipped
  if equipped == nil and CrusaderStrikeEquippedGear then
    equipped = CrusaderStrikeEquippedGear.ScanNow()
  end
  return {
    schema_version = 1,
    game_version = "forever",
    region = bucket.region or meta.region or "us",
    realm = meta.realm or "",
    character = meta.character or "",
    character_id = bucket.character_id,
    exported_at = now_iso(),
    equipped = equipped or {},
    lists = lists,
    deleted_lists = deleted,
  }
end

local function apply_removes_to_slots(slots, removes)
  slots = slots or {}
  if type(removes) ~= "table" then
    return slots
  end
  for _, op in ipairs(removes) do
    if op.op == "clear_slot" and op.slot then
      slots[op.slot] = nil
    elseif op.op == "remove_item" and op.slot and op.item_id then
      if slots[op.slot] == op.item_id then
        slots[op.slot] = nil
      end
    end
  end
  return slots
end

-- Import: validate already done by GearEncoder.Decode. Never touch equipped.
-- Match by id else local_id; last-edited-wins on edited_at; explicit removes only.
function G.ApplyImport(charDB, payload)
  local bucket = G.EnsureDB(charDB)
  if not bucket or type(payload) ~= "table" then
    return false, "validation"
  end

  -- Build the merge on a snapshot first. Reject must leave SavedVariables
  -- untouched — including character_id and region.
  local new_lists = {}
  for _, list in ipairs(bucket.lists) do
    new_lists[#new_lists + 1] = copy_list(list)
  end

  local function find_in(arr, incoming)
    if incoming.id then
      for i, list in ipairs(arr) do
        if list.id == incoming.id then
          return list, i
        end
      end
    end
    if incoming.local_id then
      for i, list in ipairs(arr) do
        if list.local_id == incoming.local_id then
          return list, i
        end
      end
    end
    return nil, nil
  end

  local function normalize_incoming_role(role_spec)
    local normalized, rerr = G.NormalizeRoleSpec(role_spec)
    if rerr then
      return nil, rerr
    end
    return normalized
  end

  for _, incoming in ipairs(payload.lists or {}) do
    local existing = find_in(new_lists, incoming)
    if not existing then
      if #new_lists >= G.MAX_SETS then
        return false, "list_limit_reached"
      end
      local copied = copy_list(incoming)
      local role_spec, rerr = normalize_incoming_role(incoming.role_spec)
      if rerr then
        return false, rerr
      end
      copied.role_spec = role_spec
      copied.slots = apply_removes_to_slots(copied.slots, incoming.removes)
      copied.removes = {} -- consumed
      new_lists[#new_lists + 1] = copied
    else
      local remote_at = incoming.edited_at or ""
      local local_at = existing.edited_at or ""
      if remote_at >= local_at then
        -- last-edited-wins: take remote fields, apply removes
        local role_spec, rerr = normalize_incoming_role(incoming.role_spec)
        if rerr then
          return false, rerr
        end
        existing.id = incoming.id ~= nil and incoming.id or existing.id
        existing.local_id = incoming.local_id or existing.local_id
        existing.name = incoming.name
        existing.type = incoming.type
        existing.until_level = incoming.until_level
        existing.role_spec = role_spec
        existing.edited_at = incoming.edited_at
        existing.edited_in = incoming.edited_in or "web"
        if type(incoming.slots) == "table" then
          for k, v in pairs(incoming.slots) do
            existing.slots[k] = v
          end
        end
        existing.slots = apply_removes_to_slots(existing.slots, incoming.removes)
        existing.removes = {}
      else
        -- keep local; still link server id if provided
        if incoming.id and not existing.id then
          existing.id = incoming.id
        end
      end
    end
  end

  -- deleted_lists: remove matching active sets
  if type(payload.deleted_lists) == "table" then
    local keep = {}
    for _, list in ipairs(new_lists) do
      local drop = false
      for _, d in ipairs(payload.deleted_lists) do
        if (d.id and list.id == d.id) or (d.local_id and list.local_id == d.local_id) then
          drop = true
          break
        end
      end
      if not drop then
        keep[#keep + 1] = list
      end
    end
    new_lists = keep
  end

  if #new_lists > G.MAX_SETS then
    return false, "list_limit_reached"
  end

  -- Success only: commit character_id / region / lists / deleted together.
  if payload.character_id ~= nil then
    bucket.character_id = payload.character_id
  end
  if type(payload.region) == "string" then
    bucket.region = payload.region
  end
  bucket.lists = new_lists
  -- Clear local deleted queue once sync string applied (web has them).
  bucket.deleted = {}
  return true
end

function G.NowISO()
  return now_iso()
end

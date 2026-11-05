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
  -- Match platform/web: null/missing character level is treated as 0.
  local level = 0
  if type(player_level) == "number" then
    level = player_level
  end
  if level >= 60 then
    return false, "leveling_set_at_max_level"
  end
  if until_level <= level then
    return false, "until_level_not_above_current_level"
  end
  return true
end

-- Forever create defaults for /cs gearsets dropdown + form.
-- Below 60: default leveling with until_level = min(60, max(1, level+1)); max_level also allowed.
-- At 60+: max_level only (no leveling / until_level).
-- Missing/0 level matches web CSGearSetRules.minUntil (level null → 0 → until 1).
function G.CreateDefaults(player_level)
  local lvl = 0
  if type(player_level) == "number" then
    lvl = math.floor(player_level)
  end
  if lvl >= 60 then
    return { type = "max_level", until_level = nil, allow_leveling = false }
  end
  if lvl < 0 then
    lvl = 0
  end
  return {
    type = "leveling",
    until_level = math.min(60, math.max(1, lvl + 1)),
    allow_leveling = true,
  }
end

function G.AllowedSetTypes(player_level)
  local d = G.CreateDefaults(player_level)
  if d.allow_leveling then
    return { "leveling", "max_level" }
  end
  return { "max_level" }
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
    pending_ops = {}, -- OpenAPI GearOp queue for companion /sync (platform#46)
    version = 0, -- last observed list version (base_version for ops)
    edited_at = now_iso(),
    edited_in = "game",
  }
  if type(fields and fields.slots) == "table" then
    for slot, item_id in pairs(fields.slots) do
      if CrusaderStrikeGearSlots and CrusaderStrikeGearSlots.IsValidName(slot) then
        if item_id == nil then
          list.slots[slot] = nil
        elseif type(item_id) == "number" and item_id == math.floor(item_id) and item_id >= 1 then
          local allow = true
          if CrusaderStrikeGearEquip and CrusaderStrikeGearEquip.CanPlace then
            allow = CrusaderStrikeGearEquip.CanPlace(item_id, slot, CrusaderStrikeGearEquip.PlayerClass(), fields.slots)
          end
          if allow then
            list.slots[slot] = item_id
          end
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

local function drop_removes_for_slot(removes, slot)
  local kept = {}
  for _, op in ipairs(removes or {}) do
    if not (op.slot == slot and (op.op == "clear_slot" or op.op == "remove_item")) then
      kept[#kept + 1] = op
    end
  end
  return kept
end

local function drop_pending_for_slot(pending, slot)
  local kept = {}
  for _, op in ipairs(pending or {}) do
    if op.slot ~= slot then
      kept[#kept + 1] = op
    end
  end
  return kept
end

-- In-game slot pick/clear. Emits OpenAPI set_slot/clear_slot into list.pending_ops
-- (platform#46). CSGEAR1 removes stay clear_slot-only.
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
  list.pending_ops = list.pending_ops or {}
  if type(list.version) ~= "number" then
    list.version = 0
  end

  local prev = list.slots[slot]
  local prior = {}
  if prev ~= nil then
    prior[1] = prev
  end

  if item_id ~= nil then
    if type(item_id) ~= "number" or item_id ~= math.floor(item_id) or item_id < 1 or item_id > 2147483647 then
      return nil, "validation"
    end
    if CrusaderStrikeGearEquip and CrusaderStrikeGearEquip.CanPlace then
      local classToken = CrusaderStrikeGearEquip.PlayerClass()
      local okPlace, placeReason = CrusaderStrikeGearEquip.CanPlace(item_id, slot, classToken, list.slots)
      if not okPlace then
        return nil, placeReason or "wrong_slot"
      end
    elseif slot == "off_hand" and CrusaderStrikeGearSlots.OffhandRejects(item_id) then
      return nil, "wrong_slot"
    end
  end

  local ops = nil
  if CrusaderStrikeGearOps and CrusaderStrikeGearOps.BuildSlotOps then
    local err
    ops, err = CrusaderStrikeGearOps.BuildSlotOps({
      slot = slot,
      item_id = item_id,
      base_version = list.version,
      prior_item_ids = prior,
      force_clear = (item_id == nil and prev ~= nil),
    })
    if not ops then
      return nil, err or "validation"
    end
  end

  -- Apply local slot state
  if item_id == nil then
    list.slots[slot] = nil
    list.removes = drop_removes_for_slot(list.removes, slot)
    -- CSGEAR1 explicit clear (always).
    list.removes[#list.removes + 1] = { op = "clear_slot", slot = slot }
  else
    list.slots[slot] = item_id
    list.removes = drop_removes_for_slot(list.removes, slot)
  end

  -- Queue OpenAPI ops for companion /sync (replace any prior pending for this slot).
  -- prior_item_id is local-only (for revert on hard reject); stripped on send.
  if ops then
    list.pending_ops = drop_pending_for_slot(list.pending_ops, slot)
    for _, op in ipairs(ops) do
      op.prior_item_id = prev
      list.pending_ops[#list.pending_ops + 1] = op
    end
  end

  list.edited_at = now_iso()
  list.edited_in = "game"
  return list, ops
end

-- Wire-clean copy of one pending op (no local-only fields like prior_item_id/source).
local function wire_op(op)
  local out = {
    op_id = op.op_id,
    type = op.type,
    slot = op.slot,
    base_version = op.base_version,
  }
  if op.item_id ~= nil then
    out.item_id = op.item_id
  end
  if op.priority ~= nil then
    out.priority = op.priority
  end
  return out
end

local function wire_ops(pending)
  local out = {}
  for i, op in ipairs(pending or {}) do
    out[i] = wire_op(op)
  end
  return out
end

-- Peek queued OpenAPI ops as wire payloads (does NOT clear). Retries keep the same op_id.
function G.PeekPendingOps(charDB, local_id)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  return wire_ops(list.pending_ops)
end

-- Companion drain: peek only. Ops stay queued until ApplyOpsResult / AckPendingOps.
-- (Previously cleared before send, which broke op_id dedupe on retry.)
function G.DrainPendingOps(charDB, local_id)
  return G.PeekPendingOps(charDB, local_id)
end

-- Remove pending ops whose op_id is in op_ids (applied / rejected / duplicates).
function G.AckPendingOps(charDB, local_id, op_ids)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  local drop = {}
  if type(op_ids) == "table" then
    for _, id in ipairs(op_ids) do
      if type(id) == "string" then
        drop[id] = true
      elseif type(id) == "table" and type(id.op_id) == "string" then
        drop[id.op_id] = true
      end
    end
  end
  local kept = {}
  for _, op in ipairs(list.pending_ops or {}) do
    if not drop[op.op_id] then
      kept[#kept + 1] = op
    end
  end
  list.pending_ops = kept
  return kept
end

function G.SetListVersion(charDB, local_id, version)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  if type(version) == "number" and version == math.floor(version) and version >= 0 then
    list.version = version
  end
  return list
end

local function normalize_op_ids(arr)
  local out = {}
  if type(arr) ~= "table" then
    return out
  end
  for _, v in ipairs(arr) do
    if type(v) == "string" then
      out[#out + 1] = v
    elseif type(v) == "table" and type(v.op_id) == "string" then
      out[#out + 1] = v.op_id
    end
  end
  return out
end

local function find_pending(list, op_id)
  for _, op in ipairs(list.pending_ops or {}) do
    if op.op_id == op_id then
      return op
    end
  end
  return nil
end

local function reject_message(reason, slot, item_id)
  local msg
  -- Prefer FailSync / SyncErrorMessage catalog when available (version_conflict etc.).
  local catalog_code = reason
  if reason == "stale_base_version" or reason == "version_conflict" then
    catalog_code = "version_conflict"
  end
  if CrusaderStrikeGearEncoder and CrusaderStrikeGearEncoder.SyncErrorMessage
      and (catalog_code == "version_conflict" or catalog_code == "version_mismatch"
        or catalog_code == "character_mismatch" or catalog_code == "ignored_op"
        or catalog_code == "item_not_forever") then
    msg = CrusaderStrikeGearEncoder.SyncErrorMessage(catalog_code)
  elseif reason == "item_not_in_slot" then
    msg = "Item is not valid for that slot"
  elseif reason == "list_items_limit" then
    msg = "Gear list item limit reached"
  elseif reason == "stale_base_version" or reason == "version_conflict" then
    msg = "This gear set changed on the website. Local changes are kept — sync again to reload and retry."
  elseif reason == "item_not_forever" then
    msg = "Item is not available in Forever"
  else
    msg = tostring(reason or "rejected")
  end
  if slot then
    msg = msg .. " [" .. tostring(slot) .. "]"
  end
  if item_id then
    msg = msg .. " (item " .. tostring(item_id) .. ")"
  end
  return msg
end

local function revert_slot(list, slot, prior_item_id)
  list.slots = list.slots or {}
  list.removes = drop_removes_for_slot(list.removes, slot)
  if prior_item_id == nil then
    list.slots[slot] = nil
  else
    list.slots[slot] = prior_item_id
  end
end

--[[
  Apply a GearOpsResult (openapi) / companion ops response to local state.
  Accepts conflicts[] (contract name) or rejected[] (alias from review notes).
  - applied[] / duplicates[]: ack op_ids; take result.version (no-ops stay applied, may not bump).
  - conflicts stale_base_version: refresh version, rebuild op with a NEW op_id.
  - conflicts item_not_in_slot / list_items_limit: revert local slot + return error for UI.
  - ignored[]: returned for logging (source etc.).
]]
function G.ApplyOpsResult(charDB, local_id, result)
  local list = G.FindByLocalId(charDB, local_id)
  if not list or type(result) ~= "table" then
    return nil, "validation"
  end
  -- Top-level transport / auth / validation failure from companion
  -- (platform#51/#52 envelope, platform#54 field-map, or legacy).
  -- Do not touch pending_ops; clear syncing and surface a player-visible message.
  if result.error ~= nil then
    local err = result.error
    local request_id = result.request_id
    if type(err) == "table" and type(err.request_id) == "string" then
      request_id = request_id or err.request_id
    end
    return G.FailSync(charDB, local_id, err, {
      http_status = result.http_status or result.status,
      retry_after = result.retry_after,
      headers = result.headers,
      retryable = result.retryable,
      request_id = request_id,
    })
  end
  -- platform#54 field-map: {"errors":{"body":"invalid_json"}} (and other field reasons).
  -- Not the #52 envelope — must not fall through as a successful empty ops response.
  if type(result.errors) == "table" then
    -- Array-shaped summary.errors from a nested call is numeric; field-maps use string keys.
    local is_field_map = false
    for k, v in pairs(result.errors) do
      if type(k) == "string" and type(v) == "string" then
        is_field_map = true
        break
      end
    end
    if is_field_map then
      return G.FailSync(charDB, local_id, { errors = result.errors, message = result.message }, {
        http_status = result.http_status or result.status or 400,
        retry_after = result.retry_after,
        headers = result.headers,
        retryable = false,
        request_id = result.request_id,
      })
    end
  end
  list.pending_ops = list.pending_ops or {}
  if type(list.version) ~= "number" then
    list.version = 0
  end

  local applied_ids = normalize_op_ids(result.applied)
  local dup_ids = normalize_op_ids(result.duplicates)
  local conflicts = result.conflicts
  if type(conflicts) ~= "table" then
    conflicts = result.rejected
  end
  if type(conflicts) ~= "table" then
    conflicts = {}
  end
  local ignored = result.ignored
  if type(ignored) ~= "table" then
    ignored = {}
  end

  -- Refresh list version from the response (and optional nested list).
  local new_version = result.version
  if type(result.list) == "table" then
    if result.list.id ~= nil then
      list.id = result.list.id
    end
    if type(result.list.version) == "number" then
      new_version = result.list.version
    end
  end
  if type(new_version) == "number" and new_version == math.floor(new_version) and new_version >= 0 then
    list.version = new_version
  end

  local ack = {}
  for _, id in ipairs(applied_ids) do
    ack[#ack + 1] = id
  end
  for _, id in ipairs(dup_ids) do
    ack[#ack + 1] = id
  end

  local rebuilt = {}
  local errors = {}

  for _, c in ipairs(conflicts) do
    if type(c) == "table" and type(c.op_id) == "string" then
      ack[#ack + 1] = c.op_id
      local pending = find_pending(list, c.op_id)
      local reason = c.reason
      if type(c.winning_version) == "number" and c.winning_version > (list.version or 0) then
        list.version = c.winning_version
      end
      if reason == "stale_base_version" and pending then
        -- Drop stale op (via ack), rebuild with new op_id + refreshed base_version.
        local item_id = pending.item_id
        if pending.type == "clear_slot" or pending.type == "remove_item" then
          item_id = nil
        end
        local prior = {}
        if pending.prior_item_id ~= nil then
          prior[1] = pending.prior_item_id
        elseif list.slots and list.slots[pending.slot] ~= nil and item_id == nil then
          -- clearing: prior already applied locally; force_clear
        end
        local force_clear = (item_id == nil)
        if CrusaderStrikeGearOps and CrusaderStrikeGearOps.BuildSlotOps then
          local ops = CrusaderStrikeGearOps.BuildSlotOps({
            slot = pending.slot,
            item_id = item_id,
            base_version = list.version,
            prior_item_ids = prior,
            force_clear = force_clear,
          })
          if ops then
            for _, op in ipairs(ops) do
              op.prior_item_id = pending.prior_item_id
              rebuilt[#rebuilt + 1] = op
            end
          end
        end
      elseif reason == "item_not_in_slot" or reason == "list_items_limit" then
        local slot = (pending and pending.slot) or c.slot
        local prior = pending and pending.prior_item_id or nil
        local item_id = (pending and pending.item_id) or c.item_id
        if slot then
          revert_slot(list, slot, prior)
        end
        errors[#errors + 1] = {
          op_id = c.op_id,
          reason = reason,
          slot = slot,
          item_id = item_id,
          message = reject_message(reason, slot, item_id),
        }
      elseif pending then
        errors[#errors + 1] = {
          op_id = c.op_id,
          reason = reason,
          slot = pending.slot or c.slot,
          item_id = pending.item_id or c.item_id,
          message = reject_message(reason, pending.slot or c.slot, pending.item_id or c.item_id),
        }
      end
    end
  end

  G.AckPendingOps(charDB, local_id, ack)
  -- Append rebuilt ops (new op_ids) grouped by slot, replacing any leftover same-slot pending.
  local by_slot = {}
  local slot_order = {}
  for _, op in ipairs(rebuilt) do
    if not by_slot[op.slot] then
      by_slot[op.slot] = {}
      slot_order[#slot_order + 1] = op.slot
    end
    local bucket = by_slot[op.slot]
    bucket[#bucket + 1] = op
  end
  for _, slot in ipairs(slot_order) do
    list.pending_ops = drop_pending_for_slot(list.pending_ops, slot)
    for _, op in ipairs(by_slot[slot]) do
      list.pending_ops[#list.pending_ops + 1] = op
    end
  end

  local ignored_out = {}
  for i, ig in ipairs(ignored) do
    ignored_out[i] = ig
  end

  local ignored_message
  if #ignored_out > 0 then
    if CrusaderStrikeGearEncoder and CrusaderStrikeGearEncoder.SyncErrorMessage then
      ignored_message = CrusaderStrikeGearEncoder.SyncErrorMessage("ignored_op")
    else
      ignored_message = "The server ignored some fields on a gear sync op. Local gear changes are kept."
    end
  end

  -- Successful ops response: leave retryable pending (rebuilt) but clear syncing flag.
  list.syncing = false
  if #errors == 0 and #(list.pending_ops or {}) == 0 then
    -- Ops applied and queue drained: clear any prior error. ignored[] is a soft,
    -- one-shot notice via the returned ignored_message (UI prints it once); it is
    -- not stored as a sticky last_sync_error (addon#57, #56 review nit).
    list.last_sync_error = nil
  elseif #errors > 0 then
    list.last_sync_error = {
      code = errors[1].reason,
      message = errors[1].message,
      at = now_iso(),
    }
  end

  return {
    version = list.version,
    acked = ack,
    rebuilt = wire_ops(rebuilt),
    errors = errors,
    ignored = ignored_out,
    ignored_message = ignored_message,
    syncing = false,
  }
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
  local pending_ops = {}
  if type(src.pending_ops) == "table" then
    for i, op in ipairs(src.pending_ops) do
      pending_ops[i] = {
        op_id = op.op_id,
        type = op.type,
        slot = op.slot,
        item_id = op.item_id,
        priority = op.priority,
        base_version = op.base_version,
        prior_item_id = op.prior_item_id, -- local-only
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
    pending_ops = pending_ops,
    version = src.version or 0,
    edited_at = src.edited_at,
    edited_in = src.edited_in,
  }
end

function G.BuildExportPayload(charDB, meta)
  local bucket = G.EnsureDB(charDB)
  meta = meta or {}
  local lists = {}
  for i, list in ipairs(bucket.lists) do
    local copied = copy_list(list)
    -- pending_ops / version are local companion-sync state, not CSGEAR1 wire fields.
    copied.pending_ops = nil
    copied.version = nil
    lists[i] = copied
  end
  local deleted = {}
  for i, d in ipairs(bucket.deleted) do
    deleted[i] = { id = d.id, local_id = d.local_id }
  end
  local equipped = meta.equipped
  if equipped == nil and not meta.omit_equipped and CrusaderStrikeEquippedGear then
    equipped = CrusaderStrikeEquippedGear.ScanNow()
  end
  return {
    schema_version = 1,
    game_version = "forever",
    region = bucket.region or meta.region or "us",
    realm = meta.realm or "",
    character = meta.character or "",
    character_id = bucket.character_id,
    exported_at = meta.exported_at or now_iso(),
    equipped = (not meta.omit_equipped) and (equipped or {}) or nil,
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
      if CrusaderStrikeGearEquip and CrusaderStrikeGearEquip.DropIllegal then
        CrusaderStrikeGearEquip.DropIllegal(copied.slots)
      elseif type(copied.slots) == "table" and CrusaderStrikeGearSlots.OffhandRejects(copied.slots.off_hand) then
        copied.slots.off_hand = nil
      end
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
        -- Never wipe a known server id with null; web re-import links local_id→id.
        if incoming.id ~= nil then
          existing.id = incoming.id
        end
        existing.local_id = incoming.local_id or existing.local_id
        existing.name = incoming.name
        existing.type = incoming.type
        existing.until_level = incoming.until_level
        existing.role_spec = role_spec
        existing.edited_at = incoming.edited_at
        existing.edited_in = incoming.edited_in or "web"
        if type(incoming.version) == "number" and incoming.version == math.floor(incoming.version) and incoming.version >= 0 then
          existing.version = incoming.version
        end
        if type(incoming.slots) == "table" then
          for k, v in pairs(incoming.slots) do
            local accept = true
            if CrusaderStrikeGearEquip and CrusaderStrikeGearEquip.CanPlace then
              accept = CrusaderStrikeGearEquip.CanPlace(v, k, CrusaderStrikeGearEquip.PlayerClass(), incoming.slots)
            elseif k == "off_hand" and CrusaderStrikeGearSlots.OffhandRejects(v) then
              accept = false
            end
            if accept then
              existing.slots[k] = v
            end
          end
        end
        existing.slots = apply_removes_to_slots(existing.slots, incoming.removes)
        if CrusaderStrikeGearEquip and CrusaderStrikeGearEquip.DropIllegal then
          CrusaderStrikeGearEquip.DropIllegal(existing.slots)
        elseif type(existing.slots) == "table" and CrusaderStrikeGearSlots.OffhandRejects(existing.slots.off_hand) then
          existing.slots.off_hand = nil
        end
        existing.removes = {}
      else
        -- keep local; still link server id when web echoes local_id→id
        if incoming.id ~= nil then
          existing.id = incoming.id
        end
        if incoming.local_id and not existing.local_id then
          existing.local_id = incoming.local_id
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

--[[
  Companion /sync transport lifecycle.
  BeginSync marks the list as syncing (UI). FailSync clears syncing, keeps
  pending_ops for retry, and stores a player-visible last_sync_error.
  CompleteSync clears syncing + error after a clean ack with empty queue.
]]
function G.BeginSync(charDB, local_id)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  list.syncing = true
  list.last_sync_error = nil
  return list
end

--[[
  Fail a companion /sync attempt.
  code_or_detail: platform#51/#52 envelope / error table / string code (see ParseErrorEnvelope).
  meta: optional { http_status, retry_after, headers, retryable, request_id }.
  Keeps pending_ops; clears syncing; stores last_sync_error for UI.
]]
function G.FailSync(charDB, local_id, code_or_detail, meta)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  list.syncing = false

  local parsed
  if CrusaderStrikeGearEncoder and CrusaderStrikeGearEncoder.ParseErrorEnvelope then
    parsed = CrusaderStrikeGearEncoder.ParseErrorEnvelope(code_or_detail, meta)
  else
    local code = code_or_detail
    if type(code_or_detail) == "table" then
      code = code_or_detail.code or code_or_detail.reason or "api_unavailable"
    end
    local msg
    if CrusaderStrikeGearEncoder and CrusaderStrikeGearEncoder.SyncErrorMessage then
      msg = CrusaderStrikeGearEncoder.SyncErrorMessage(code)
    else
      msg = tostring(code or "api_unavailable")
    end
    parsed = { code = code, message = msg, retryable = false, retry_after = nil }
  end

  local err = {
    code = parsed.code,
    message = parsed.message,
    retryable = parsed.retryable,
    retry_after = parsed.retry_after,
    request_id = parsed.request_id,
    limit = parsed.limit,
    server_message = parsed.server_message,
    at = now_iso(),
  }
  list.last_sync_error = err
  local bucket = G.EnsureDB(charDB)
  if bucket then
    bucket.last_sync_error = err
  end
  local pending_n = 0
  if type(list.pending_ops) == "table" then
    pending_n = #list.pending_ops
  end
  return {
    code = parsed.code,
    message = parsed.message,
    retryable = parsed.retryable,
    retry_after = parsed.retry_after,
    request_id = parsed.request_id,
    limit = parsed.limit,
    server_message = parsed.server_message,
    pending_kept = pending_n,
    syncing = false,
  }
end

function G.CompleteSync(charDB, local_id)
  local list = G.FindByLocalId(charDB, local_id)
  if not list then
    return nil, "validation"
  end
  list.syncing = false
  list.last_sync_error = nil
  return list
end

function G.NowISO()
  return now_iso()
end

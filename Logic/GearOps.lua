--[[
  OpenAPI GearOp builders for armory slot pick/clear (platform#46).
  Primary (only) path: set_slot / clear_slot (live in prod).

  Contract: openapi/v1.yaml GearOp — required [op_id, type, slot, base_version];
  set_slot also needs item_id; clear_slot omits item_id.
]]

CrusaderStrikeGearOps = CrusaderStrikeGearOps or {}
local GO = CrusaderStrikeGearOps

-- UUID v4 string (Lua 5.1). Used as GearOp.op_id for server dedupe.
function GO.NewOpId()
  local b = {}
  for i = 1, 16 do
    b[i] = math.random(0, 255)
  end
  -- version 4
  b[7] = (b[7] % 16) + 64
  -- variant 10xx
  b[9] = (b[9] % 64) + 128
  return string.format(
    "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8],
    b[9], b[10], b[11], b[12], b[13], b[14], b[15], b[16]
  )
end

local function valid_slot(slot)
  return CrusaderStrikeGearSlots and CrusaderStrikeGearSlots.IsValidName(slot)
end

local function valid_item_id(n)
  return type(n) == "number" and n == math.floor(n) and n >= 1 and n <= 2147483647
end

local function base_ver(v)
  if type(v) ~= "number" or v ~= math.floor(v) or v < 0 then
    return 0
  end
  return v
end

--[[
  Build OpenAPI ops for one slot write.
  opts = {
    slot = string,
    item_id = number|nil,          -- nil = clear
    base_version = number,         -- list.version last observed
    prior_item_ids = {number,...}, -- items currently in the slot (clear detection)
    force_clear = bool|nil,        -- emit clear_slot even if prior empty
    op_id = string|nil,            -- optional fixed id (tests / replay)
  }
  Returns ops array (may be empty when clear of already-empty slot).
  Note: do not put `source` on the wire — server soft-ignores it into ignored[].
]]
function GO.BuildSlotOps(opts)
  opts = opts or {}
  local slot = opts.slot
  if not valid_slot(slot) then
    return nil, "validation"
  end
  local bv = base_ver(opts.base_version)
  local item_id = opts.item_id
  local prior = opts.prior_item_ids
  if type(prior) ~= "table" then
    prior = {}
  end
  local ops = {}

  local function push(op)
    if opts.op_id and #ops == 0 then
      op.op_id = opts.op_id
    else
      op.op_id = GO.NewOpId()
    end
    op.slot = slot
    op.base_version = bv
    -- intentionally omit source (lands in ignored[] on the server)
    ops[#ops + 1] = op
  end

  -- set_slot / clear_slot only (platform#46)
  if item_id ~= nil then
    if not valid_item_id(item_id) then
      return nil, "validation"
    end
    push({ type = "set_slot", item_id = item_id })
    return ops
  end
  -- clear: only emit when something was in the slot (mirror web)
  if #prior > 0 or opts.force_clear then
    push({ type = "clear_slot" })
  end
  return ops
end

-- True when an OpenAPI op_id looks like a UUID (dedupe key shape).
function GO.IsOpId(s)
  if type(s) ~= "string" then
    return false
  end
  return s:match(
    "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
  ) ~= nil
end

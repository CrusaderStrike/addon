--[[
  OpenAPI GearOp builders for armory slot pick/clear (platform#46).
  Primary path: set_slot / clear_slot (live in prod).
  Short Option A fallback ("legacy"): remove_item (+ add_item) for older fixtures/tests only.

  Contract: openapi/v1.yaml GearOp — required [op_id, type, slot, base_version];
  set_slot also needs item_id; clear_slot omits item_id; add_item needs priority 1.
]]

CrusaderStrikeGearOps = CrusaderStrikeGearOps or {}
local GO = CrusaderStrikeGearOps

-- Default matches live platform#46. Tests may flip to "legacy" briefly.
GO.MODE_SET_SLOT = "set_slot"
GO.MODE_LEGACY = "legacy"
GO._mode = GO.MODE_SET_SLOT

function GO.GetMode()
  return GO._mode or GO.MODE_SET_SLOT
end

function GO.SetMode(mode)
  if mode == GO.MODE_LEGACY then
    GO._mode = GO.MODE_LEGACY
  else
    GO._mode = GO.MODE_SET_SLOT
  end
  return GO._mode
end

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
    prior_item_ids = {number,...}, -- items currently in the slot (legacy clear/replace)
    mode = "set_slot"|"legacy"|nil,
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
  local mode = opts.mode or GO.GetMode()
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

  if mode == GO.MODE_LEGACY then
    for _, pid in ipairs(prior) do
      if valid_item_id(pid) then
        push({ type = "remove_item", item_id = pid })
      end
    end
    if item_id ~= nil then
      if not valid_item_id(item_id) then
        return nil, "validation"
      end
      push({ type = "add_item", item_id = item_id, priority = 1 })
    end
    return ops
  end

  -- Primary: set_slot / clear_slot (platform#46)
  if item_id ~= nil then
    if not valid_item_id(item_id) then
      return nil, "validation"
    end
    push({ type = "set_slot", item_id = item_id })
    return ops
  end
  -- clear: only emit when something was in the slot (mirror web-optb)
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

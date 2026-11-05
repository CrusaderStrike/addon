-- Shared equip rules for the gear planner.
-- UI clicks, SetSlot, CSGEAR1 import, and set load all call CanPlace.

CrusaderStrikeGearEquip = CrusaderStrikeGearEquip or {}
local E = CrusaderStrikeGearEquip

-- cloth=1 < leather=2 < mail=3 < plate=4. Subclass id matches the tier.
E.CLASS_ARMOR_MAX = {
  MAGE = 1, PRIEST = 1, WARLOCK = 1,
  DRUID = 2, ROGUE = 2,
  HUNTER = 3, SHAMAN = 3,
  WARRIOR = 4, PALADIN = 4,
}

-- Off-hand weapons (INVTYPE_WEAPONOFFHAND) only. Not generic one-handers.
E.OFFHAND_WEAPON_CLASS = { ROGUE = true, WARRIOR = true, HUNTER = true }

-- Shields. Hunter is not a shield class.
E.SHIELD_CLASS = { WARRIOR = true, PALADIN = true, SHAMAN = true }

E.ARMOR_SLOTS = {
  head = true, shoulder = true, chest = true, waist = true,
  legs = true, feet = true, wrist = true, hands = true,
}

function E.PlayerClass()
  if type(UnitClass) ~= "function" then
    return nil
  end
  local ok, _, token = pcall(UnitClass, "player")
  if not ok or type(token) ~= "string" or token == "" then
    return nil
  end
  return token:upper()
end

function E.ArmorAllowed(classToken, subClassID)
  subClassID = tonumber(subClassID)
  if not subClassID or subClassID < 1 or subClassID > 4 then
    return true
  end
  if type(classToken) == "string" then
    classToken = classToken:upper()
  end
  local maxTier = classToken and E.CLASS_ARMOR_MAX[classToken]
  if not maxTier then
    return true
  end
  return subClassID <= maxTier
end

local function armor_tier(itemId)
  if type(GetItemInfoInstant) ~= "function" then
    return nil
  end
  local ok, _, itemType, itemSubType, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemId)
  if not ok then
    return nil
  end
  local isArmor = classID == 4 or (type(itemType) == "string" and itemType:lower() == "armor")
  if type(subClassID) == "number" and subClassID >= 1 and subClassID <= 4 and isArmor then
    return subClassID
  end
  if isArmor and type(itemSubType) == "string" then
    local key = itemSubType:lower()
    if key:find("plate", 1, true) then
      return 4
    elseif key:find("mail", 1, true) then
      return 3
    elseif key:find("leather", 1, true) then
      return 2
    elseif key:find("cloth", 1, true) then
      return 1
    end
  end
  return nil
end

local function equip_loc(itemId)
  if type(GetItemInfoInstant) == "function" then
    local ok, _, _, _, loc = pcall(GetItemInfoInstant, itemId)
    if ok and type(loc) == "string" and loc ~= "" then
      return loc:upper()
    end
  end
  if type(GetItemInfo) == "function" then
    local ok, _, _, _, _, _, _, _, _, loc = pcall(GetItemInfo, itemId)
    if ok and type(loc) == "string" and loc ~= "" then
      return loc:upper()
    end
  end
  return nil
end

-- true, or false, reason. Unknown equip loc in the off hand fails closed.
function E.CanPlace(itemId, slot, classToken, previewSlots)
  itemId = tonumber(itemId)
  if not itemId or type(slot) ~= "string" then
    return false, "validation"
  end
  if type(classToken) ~= "string" or classToken == "" then
    classToken = E.PlayerClass()
  else
    classToken = classToken:upper()
  end
  previewSlots = type(previewSlots) == "table" and previewSlots or {}

  if E.ARMOR_SLOTS[slot] then
    local tier = armor_tier(itemId)
    if tier and classToken and E.CLASS_ARMOR_MAX[classToken] and tier > E.CLASS_ARMOR_MAX[classToken] then
      return false, "class_armor"
    end
  end

  if slot ~= "off_hand" then
    return true
  end

  local loc = equip_loc(itemId)
  if loc == nil then
    return false, "wrong_slot"
  end
  if loc == "INVTYPE_HOLDABLE" then
    return true
  end
  if loc == "INVTYPE_SHIELD" then
    if classToken and E.SHIELD_CLASS[classToken] then
      return true
    end
    return false, "wrong_slot"
  end
  if loc == "INVTYPE_WEAPONOFFHAND" then
    if classToken and E.OFFHAND_WEAPON_CLASS[classToken] then
      return true
    end
    return false, "wrong_slot"
  end
  -- Main-hand, two-hand, generic one-hand, and anything else stay out.
  return false, "wrong_slot"
end

function E.DropIllegal(slots, classToken)
  if type(slots) ~= "table" then
    return slots
  end
  if type(classToken) ~= "string" or classToken == "" then
    classToken = E.PlayerClass()
  end
  for slot, itemId in pairs(slots) do
    if itemId ~= nil then
      local ok, reason = E.CanPlace(itemId, slot, classToken, slots)
      if ok then
        -- keep
      elseif reason == "class_armor" then
        slots[slot] = nil
      elseif slot == "off_hand" and equip_loc(itemId) then
        -- Known-illegal off-hand. An item the client cannot classify stays
        -- so a CSGEAR1 round-trip is not stripped. New equips still fail closed.
        slots[slot] = nil
      end
    end
  end
  return slots
end

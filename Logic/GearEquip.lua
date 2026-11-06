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

-- English tokens plus common localized class names. UnitClass's second
-- return is the token; some callers only have the displayed name.
local CLASS_ALIAS = {
  warrior = "WARRIOR", guerrier = "WARRIOR", guerrero = "WARRIOR", krieger = "WARRIOR",
  paladin = "PALADIN",
  hunter = "HUNTER", chasseur = "HUNTER", cazador = "HUNTER", jaeger = "HUNTER",
  rogue = "ROGUE", voleur = "ROGUE", picaro = "ROGUE", schurke = "ROGUE",
  priest = "PRIEST", pretre = "PRIEST", sacerdote = "PRIEST", priester = "PRIEST",
  mage = "MAGE", mago = "MAGE", magier = "MAGE",
  warlock = "WARLOCK", demoniste = "WARLOCK", brujo = "WARLOCK", hexenmeister = "WARLOCK",
  druid = "DRUID", druide = "DRUID", druida = "DRUID",
  shaman = "SHAMAN", chaman = "SHAMAN", chaman = "SHAMAN", schamane = "SHAMAN",
}

function E.NormalizeClass(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local upper = value:upper()
  if E.CLASS_ARMOR_MAX[upper] or E.OFFHAND_WEAPON_CLASS[upper] or E.SHIELD_CLASS[upper] then
    return upper
  end
  return CLASS_ALIAS[value:lower()]
end

function E.PlayerClass()
  if type(UnitClass) ~= "function" then
    return nil
  end
  local ok, localized, token = pcall(UnitClass, "player")
  if not ok then
    return nil
  end
  return E.NormalizeClass(token) or E.NormalizeClass(localized)
end

function E.ArmorAllowed(classToken, subClassID)
  subClassID = tonumber(subClassID)
  if not subClassID or subClassID < 1 or subClassID > 4 then
    return true
  end
  classToken = E.NormalizeClass(classToken)
  local maxTier = classToken and E.CLASS_ARMOR_MAX[classToken]
  if not maxTier then
    return false
  end
  return subClassID <= maxTier
end

local function tier_from_text(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local key = text:lower()
  if key:find("plate", 1, true) or key:find("platte", 1, true) or key:find("plaque", 1, true) then
    return 4
  end
  if key:find("mail", 1, true) or key:find("kette", 1, true) or key:find("maglia", 1, true) or key:find("malla", 1, true) then
    return 3
  end
  if key:find("leather", 1, true) or key:find("leder", 1, true) or key:find("cuir", 1, true) or key:find("cuero", 1, true) or key:find("couro", 1, true) then
    return 2
  end
  if key:find("cloth", 1, true) or key:find("stoff", 1, true) or key:find("tissu", 1, true) or key:find("tela", 1, true) or key:find("pano", 1, true) then
    return 1
  end
  if key:find("misc", 1, true) or key:find("divers", 1, true) then
    return 0
  end
  return nil
end

-- "unknown" when the client has no item data (fail closed).
-- "none" when the item is known and is not cloth/leather/mail/plate.
-- 1..4 for those tiers. Subclass 0 is miscellaneous, not a tier.
local function armor_tier(itemId)
  local saw = false
  local itemType, itemSubType, classID, subClassID

  if type(GetItemInfoInstant) == "function" then
    local ok, a, b, c, d, e, f, g = pcall(GetItemInfoInstant, itemId)
    if ok and a ~= nil then
      if type(a) == "number" then
        -- Retail: id, type, subtype, equipLoc, icon, classID, subClassID.
        -- Some builds omit icon: id, type, subtype, equipLoc, classID, subClassID.
        if type(f) == "number" and type(g) == "number" then
          itemType, itemSubType, classID, subClassID = b, c, f, g
        elseif type(e) == "number" and type(f) == "number" then
          itemType, itemSubType, classID, subClassID = b, c, e, f
        else
          itemType, itemSubType = b, c
          if type(f) == "number" then
            classID = f
          end
          if type(g) == "number" then
            subClassID = g
          end
        end
        -- An id with no type is still uncached.
        if itemType ~= nil or classID ~= nil then
          saw = true
        end
      elseif type(a) == "string" then
        itemType, itemSubType = a, b
        saw = true
      end
    end
  end

  if type(GetItemInfo) == "function" then
    local ok, _, _, _, _, _, classStr, subStr = pcall(GetItemInfo, itemId)
    if ok and (classStr ~= nil or subStr ~= nil) then
      saw = true
      if type(classStr) == "string" and itemType == nil then
        itemType = classStr
      end
      if type(subStr) == "string" and itemSubType == nil then
        itemSubType = subStr
      end
    end
  end

  local function bundled_tier()
    if not CrusaderStrikeLoot or not CrusaderStrikeLoot.LookupItem then
      return nil
    end
    local it = CrusaderStrikeLoot.LookupItem("forever", itemId)
    if type(it) ~= "table" or type(it.armor) ~= "string" then
      return nil
    end
    local key = it.armor:lower()
    if key == "cloth" then
      return 1
    elseif key == "leather" then
      return 2
    elseif key == "mail" then
      return 3
    elseif key == "plate" then
      return 4
    end
    return nil
  end

  if not saw then
    return bundled_tier() or "unknown"
  end

  local isArmor = classID == 4 or (type(itemType) == "string" and itemType:lower() == "armor")
  if isArmor and type(subClassID) == "number" then
    if subClassID >= 1 and subClassID <= 4 then
      return subClassID
    end
    return "none"
  end
  local fromText = tier_from_text(itemSubType)
  if fromText == 0 then
    return "none"
  end
  if fromText then
    return fromText
  end
  if isArmor then
    -- Armor with no readable subclass (still caching). Bundled loot type wins
    -- over a guess; otherwise fail closed.
    return bundled_tier() or "unknown"
  end
  if itemType ~= nil or classID ~= nil then
    return "none"
  end
  return "unknown"
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
  classToken = E.NormalizeClass(classToken) or E.PlayerClass()
  previewSlots = type(previewSlots) == "table" and previewSlots or {}

  if E.ARMOR_SLOTS[slot] then
    local tier = armor_tier(itemId)
    if tier == "unknown" then
      return false, "unknown_item"
    end
    if type(tier) == "number" then
      local maxTier = classToken and E.CLASS_ARMOR_MAX[classToken]
      if not maxTier or tier > maxTier then
        return false, "class_armor"
      end
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

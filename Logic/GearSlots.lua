--[[
  Platform GearSlot wire names (20), matching CSGEAR1 / platform GearSlot.
  invSlot 1..19 → snake_case name. `ammo` is the 20th wire slot (arrows/bullets).
  Shirt and tabard are always valid on the wire.
]]

CrusaderStrikeGearSlots = CrusaderStrikeGearSlots or {}
local GS = CrusaderStrikeGearSlots

GS.BY_INV = {
  [1] = "head",
  [2] = "neck",
  [3] = "shoulder",
  [4] = "shirt",
  [5] = "chest",
  [6] = "waist",
  [7] = "legs",
  [8] = "feet",
  [9] = "wrist",
  [10] = "hands",
  [11] = "finger1",
  [12] = "finger2",
  [13] = "trinket1",
  [14] = "trinket2",
  [15] = "back",
  [16] = "main_hand",
  [17] = "off_hand",
  [18] = "ranged",
  [19] = "tabard",
  [20] = "ammo",
}

GS.NAMES = {}
GS.BY_NAME = {}
for inv, name in pairs(GS.BY_INV) do
  GS.BY_NAME[name] = inv
  GS.NAMES[#GS.NAMES + 1] = name
end
table.sort(GS.NAMES, function(a, b)
  return (GS.BY_NAME[a] or 0) < (GS.BY_NAME[b] or 0)
end)

-- Armory layout rows for /cs gearsets (left / right columns, classic paperdoll).
GS.LAYOUT = {
  { "head", "hands" },
  { "neck", "waist" },
  { "shoulder", "legs" },
  { "back", "feet" },
  { "chest", "finger1" },
  { "shirt", "finger2" },
  { "tabard", "trinket1" },
  { "wrist", "trinket2" },
  { "main_hand", "off_hand" },
  { "ranged", "ammo" },
}

-- True when this item must not be written into off_hand (main-hand or two-hand).
function GS.OffhandRejects(itemId)
  itemId = tonumber(itemId)
  if not itemId then
    return false
  end
  local loc
  if type(GetItemInfoInstant) == "function" then
    local ok, _, _, _, equipLoc = pcall(GetItemInfoInstant, itemId)
    if ok and type(equipLoc) == "string" and equipLoc ~= "" then
      loc = equipLoc:upper()
    end
  end
  if not loc and type(GetItemInfo) == "function" then
    local ok, _, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, itemId)
    if ok and type(equipLoc) == "string" and equipLoc ~= "" then
      loc = equipLoc:upper()
    end
  end
  return loc == "INVTYPE_WEAPONMAINHAND" or loc == "INVTYPE_2HWEAPON"
end

function GS.IsValidName(name)
  return type(name) == "string" and GS.BY_NAME[name] ~= nil
end

function GS.InvToName(invSlot)
  return GS.BY_INV[invSlot]
end

function GS.NameToInv(name)
  return GS.BY_NAME[name]
end

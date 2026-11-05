--[[
  Read-only equipped gear scan for CSGEAR1.
  Parses item/enchant ids only from |Hitem:…|h; never trusts display names.
  Field order on Forever 1.60.1 still needs in-game confirmation; parse defensively.
]]

CrusaderStrikeEquippedGear = CrusaderStrikeEquippedGear or {}
local EG = CrusaderStrikeEquippedGear

local cache = { at = 0, map = {} }
local DEBOUNCE_SEC = 1

-- |Hitem:itemId:enchantId:…|h[Name]|h
-- Classic/Forever: [1]=item_id, [2]=enchant_id (confirm in game).
function EG.ParseItemLink(link)
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
  local itemId = tonumber(parts[1])
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) or itemId > 2147483647 then
    return nil
  end
  local out = { item_id = itemId }
  local enchant = tonumber(parts[2])
  if enchant and enchant >= 0 and enchant == math.floor(enchant) then
    out.enchant_id = enchant
  end
  return out
end

function EG.ScanNow()
  local slots = CrusaderStrikeGearSlots
  local map = {}
  if not slots then
    return map
  end
  for inv = 1, 19 do
    local name = slots.BY_INV[inv]
    if name then
      local link
      if GetInventoryItemLink then
        link = GetInventoryItemLink("player", inv)
      end
      local parsed = EG.ParseItemLink(link)
      if parsed then
        map[name] = parsed
      end
    end
  end
  cache.map = map
  cache.at = (GetServerTime and GetServerTime()) or (time and time()) or 0
  return map
end

function EG.GetCached(force)
  local now = (GetServerTime and GetServerTime()) or (time and time()) or 0
  if force or not cache.map or (now - (cache.at or 0)) >= DEBOUNCE_SEC then
    return EG.ScanNow()
  end
  return cache.map
end

function EG.OnEquipmentChanged()
  -- Debounce: mark stale; next GetCached/ScanNow refreshes. Callers that need
  -- immediate may ScanNow. We also schedule a delayed rescan when C_Timer exists.
  cache.at = 0
  if C_Timer and C_Timer.After then
    C_Timer.After(DEBOUNCE_SEC, function()
      EG.ScanNow()
    end)
  end
end

function EG.DEBOUNCE_SEC()
  return DEBOUNCE_SEC
end

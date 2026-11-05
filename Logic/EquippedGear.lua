--[[
  Read-only equipped gear scan for CSGEAR1.
  Parses item/enchant ids only from |Hitem:…|h via GearEncoder.ParseItemLink;
  never trusts display names. Field order: see GearEncoder.ITEM_LINK_FIELDS
  (Forever 1.60.1 best-effort; confirm in game — addon#26).
]]

CrusaderStrikeEquippedGear = CrusaderStrikeEquippedGear or {}
local EG = CrusaderStrikeEquippedGear

local cache = { at = 0, map = {} }
local DEBOUNCE_SEC = 1

function EG.ParseItemLink(link)
  local GE = CrusaderStrikeGearEncoder
  if GE and GE.ParseItemLink then
    return GE.ParseItemLink(link)
  end
  return nil
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

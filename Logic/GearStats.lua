-- Sum of planner gear-set stats. GetItemStats is the client source.
-- Keys are ITEM_MOD_* / RESISTANCE*_NAME constant names, or the localized
-- global string those constants hold.

CrusaderStrikeGearStats = CrusaderStrikeGearStats or {}
local S = CrusaderStrikeGearStats

local WEAPON_SLOTS = {
  main_hand = true,
  off_hand = true,
  ranged = true,
}

-- Order is the Stats panel order. Each mods entry is a constant name.
S.LINES = {
  { key = "strength", label = "Strength", mods = { "ITEM_MOD_STRENGTH_SHORT" } },
  { key = "agility", label = "Agility", mods = { "ITEM_MOD_AGILITY_SHORT" } },
  { key = "stamina", label = "Stamina", mods = { "ITEM_MOD_STAMINA_SHORT" } },
  { key = "intellect", label = "Intellect", mods = { "ITEM_MOD_INTELLECT_SHORT" } },
  { key = "spirit", label = "Spirit", mods = { "ITEM_MOD_SPIRIT_SHORT" } },
  { key = "armor", label = "Armor", mods = { "RESISTANCE0_NAME", "ITEM_MOD_ARMOR_SHORT" } },
  { key = "fire", label = "Fire Resistance", mods = { "RESISTANCE2_NAME", "ITEM_MOD_FIRE_RESISTANCE_SHORT" } },
  { key = "nature", label = "Nature Resistance", mods = { "RESISTANCE3_NAME", "ITEM_MOD_NATURE_RESISTANCE_SHORT" } },
  { key = "frost", label = "Frost Resistance", mods = { "RESISTANCE4_NAME", "ITEM_MOD_FROST_RESISTANCE_SHORT" } },
  { key = "shadow", label = "Shadow Resistance", mods = { "RESISTANCE5_NAME", "ITEM_MOD_SHADOW_RESISTANCE_SHORT" } },
  { key = "arcane", label = "Arcane Resistance", mods = { "RESISTANCE6_NAME", "ITEM_MOD_ARCANE_RESISTANCE_SHORT" } },
  { key = "attackPower", label = "Attack Power", mods = { "ITEM_MOD_ATTACK_POWER_SHORT" } },
  { key = "rangedAttackPower", label = "Ranged Attack Power", mods = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" } },
  { key = "spellPower", label = "Spell Power", mods = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" } },
  { key = "healing", label = "Healing", mods = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" } },
  {
    key = "hit",
    label = "Hit",
    mods = {
      "ITEM_MOD_HIT_RATING_SHORT",
      "ITEM_MOD_HIT_MELEE_RATING_SHORT",
      "ITEM_MOD_HIT_RANGED_RATING_SHORT",
      "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    },
  },
  {
    key = "crit",
    label = "Crit",
    mods = {
      "ITEM_MOD_CRIT_RATING_SHORT",
      "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
      "ITEM_MOD_CRIT_RANGED_RATING_SHORT",
      "ITEM_MOD_CRIT_SPELL_RATING_SHORT",
    },
  },
  { key = "mp5", label = "MP5", mods = { "ITEM_MOD_MANA_REGENERATION_SHORT" } },
  { key = "block", label = "Block", mods = { "ITEM_MOD_BLOCK_VALUE_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT" } },
  { key = "defense", label = "Defense", mods = { "ITEM_MOD_DEFENSE_SKILL_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" } },
  { key = "dps", label = "DPS", mods = { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" }, weaponsOnly = true },
}

local byConst = {}
local byLabel = {}
for _, line in ipairs(S.LINES) do
  byLabel[line.label] = line.key
  for _, const in ipairs(line.mods) do
    byConst[const] = line.key
  end
end

function S.LineFor(rawKey)
  if type(rawKey) ~= "string" or rawKey == "" then
    return nil
  end
  if byConst[rawKey] then
    return byConst[rawKey]
  end
  if byLabel[rawKey] then
    return byLabel[rawKey]
  end
  for const, lineKey in pairs(byConst) do
    if _G[const] == rawKey then
      return lineKey
    end
  end
  return nil
end

function S.ItemLink(itemId)
  itemId = tonumber(itemId)
  if not itemId then
    return nil
  end
  return "item:" .. tostring(itemId)
end

local function read_stats(itemId, getStats)
  if type(getStats) ~= "function" then
    return nil, false
  end
  local link = S.ItemLink(itemId)
  local ok, result = pcall(getStats, link)
  if not ok or result == nil then
    return nil, false
  end
  if type(result) ~= "table" then
    return nil, false
  end
  return result, true
end

function S.Add(totals, stats, slot)
  if type(stats) ~= "table" then
    return
  end
  for rawKey, value in pairs(stats) do
    local n = tonumber(value)
    local lineKey = n and S.LineFor(rawKey)
    if lineKey then
      local spec
      for _, line in ipairs(S.LINES) do
        if line.key == lineKey then
          spec = line
          break
        end
      end
      if spec and spec.weaponsOnly and not WEAPON_SLOTS[slot] then
        lineKey = nil
      end
      if lineKey then
        totals[lineKey] = (totals[lineKey] or 0) + n
      end
    end
  end
end

-- totals (every line key, missing = 0), filled count, pending item ids.
function S.Sum(slots, getStats)
  getStats = getStats or _G.GetItemStats
  local totals = {}
  for _, line in ipairs(S.LINES) do
    totals[line.key] = 0
  end
  local filled = 0
  local pending = {}
  if type(slots) ~= "table" then
    return totals, 0, pending
  end
  for slot, itemId in pairs(slots) do
    itemId = tonumber(itemId)
    if itemId and itemId > 0 then
      filled = filled + 1
      local stats, cached = read_stats(itemId, getStats)
      if not cached then
        pending[#pending + 1] = itemId
      else
        S.Add(totals, stats, slot)
      end
    end
  end
  table.sort(pending)
  return totals, filled, pending
end

function S.FormatAmount(n)
  n = tonumber(n) or 0
  if n == math.floor(n) then
    return tostring(math.floor(n))
  end
  return string.format("%.1f", n)
end

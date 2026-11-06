-- Bundled dungeon loot tables for World of Warcraft: Forever.
-- Target client: WoW Forever ONLY (gameVersion "forever"). See docs/loot-data.md
-- and docs/sources.md.
--
-- VERIFICATION STATUS (addon#2):
--  * Ragefire Chasm (389): boss rare drops with Forever item IDs from
--    questing.wiki Forever item/NPC records (checked 2026-10-01) and Classic-
--    retained IDs confirmed on Ladderly Forever beta-client loot pages.
--    Cross-checked against Wowhead Forever RFC overview loot table (names).
--  * All other Forever dungeons: TODO(unverified) — no invented item IDs.
--    Empty loot arrays; extend using the format in docs/loot-data.md.
--  * Recipe/pattern/formula trash drops are omitted from the wish-list browser
--    (boss rare gear only for v0.2.0).

CrusaderStrikeLoot = CrusaderStrikeLoot or {}

local SLOT = {
  HEAD = "Head",
  NECK = "Neck",
  SHOULDER = "Shoulder",
  BACK = "Back",
  CHEST = "Chest",
  WRIST = "Wrist",
  HANDS = "Hands",
  WAIST = "Waist",
  LEGS = "Legs",
  FEET = "Feet",
  FINGER = "Finger",
  TRINKET = "Trinket",
  WEAPON = "Weapon",
  SHIELD = "Shield",
  RANGED = "Ranged",
  HELD_IN_OFF_HAND = "Held In Off-hand",
  OTHER = "Other",
}

CrusaderStrikeLoot.SLOTS = SLOT

-- Quality: 0 poor .. 5 legendary (WoW ITEM_QUALITY colors).
local function item(id, name, slot, quality, armor)
  local row = {
    itemId = id,
    name = name,
    slot = slot,
    quality = quality or 2, -- uncommon default; rares below use 3
  }
  -- cloth / leather / mail / plate when known. Lets the browser and equip
  -- check work before the client caches GetItemInfo.
  if type(armor) == "string" and armor ~= "" then
    row.armor = armor
  end
  return row
end

-- instanceMapID -> { name, bosses = { { npcId, name, order, items = { ... } } } }
local FOREVER = {
  -- Ragefire Chasm — verified Forever item IDs (see docs/loot-data.md).
  [389] = {
    name = "Ragefire Chasm",
    verified = true,
    bosses = {
      {
        npcId = 11517,
        name = "Oggleflint",
        order = 1,
        items = {
          -- Forever-new rares (questing.wiki Forever item records)
          item(272999, "Barbaric Crossbow", SLOT.RANGED, 3),
          item(272998, "Bone Knuckles", SLOT.WEAPON, 3),
          item(272996, "Trogg Scepter", SLOT.WEAPON, 3),
        },
      },
      {
        npcId = 11520,
        name = "Taragaman the Hungerer",
        order = 2,
        items = {
          -- Classic-retained IDs; Forever beta client (Ladderly)
          item(14145, "Cursed Felblade", SLOT.WEAPON, 3),
          -- Classic mail wrists (not leather).
          item(14148, "Crystalline Cuffs", SLOT.WRIST, 3, "mail"),
          item(14149, "Subterranean Cape", SLOT.BACK, 3, "cloth"),
        },
      },
      {
        npcId = 11518,
        name = "Jergosh the Invoker",
        order = 3,
        items = {
          item(14147, "Cavedweller Bracers", SLOT.WRIST, 3, "leather"),
          item(14150, "Robe of Evocation", SLOT.CHEST, 3, "cloth"),
          item(14151, "Chanting Blade", SLOT.WEAPON, 3),
        },
      },
      {
        npcId = 11519,
        name = "Bazzalan",
        order = 4,
        items = {
          -- Forever-new rares (questing.wiki Forever item records)
          item(273003, "Searing Dagger", SLOT.WEAPON, 3),
          item(273005, "Satyrskin Cloak", SLOT.BACK, 3),
          item(273007, "Chasm Walkers", SLOT.FEET, 3),
        },
      },
    },
  },
}

CrusaderStrikeLoot.byVersion = {
  forever = FOREVER,
}

CrusaderStrikeLoot.defaultVersion = "forever"

function CrusaderStrikeLoot.GetTable(gameVersion)
  local v = gameVersion or CrusaderStrikeLoot.defaultVersion
  return CrusaderStrikeLoot.byVersion[v] or CrusaderStrikeLoot.byVersion.forever
end

function CrusaderStrikeLoot.GetDungeon(gameVersion, instanceMapId)
  local t = CrusaderStrikeLoot.GetTable(gameVersion)
  return t and t[instanceMapId] or nil
end

-- Flat list of dungeons that have at least one loot row (for the browser).
function CrusaderStrikeLoot.ListDungeons(gameVersion)
  local t = CrusaderStrikeLoot.GetTable(gameVersion)
  local out = {}
  if not t then
    return out
  end
  for mapId, dungeon in pairs(t) do
    local n = 0
    for _, boss in ipairs(dungeon.bosses or {}) do
      n = n + #(boss.items or {})
    end
    out[#out + 1] = {
      instanceMapId = mapId,
      name = dungeon.name,
      verified = dungeon.verified and true or false,
      itemCount = n,
    }
  end
  table.sort(out, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return out
end

-- Filter bosses/items by optional search substring and/or slot.
-- Returns a shallow-copied boss list with filtered items.
function CrusaderStrikeLoot.FilterDungeon(dungeon, opts)
  opts = opts or {}
  local search = opts.search and tostring(opts.search):lower() or nil
  if search == "" then
    search = nil
  end
  local slot = opts.slot
  if slot == "" or slot == "All" then
    slot = nil
  end
  local bosses = {}
  for _, boss in ipairs((dungeon and dungeon.bosses) or {}) do
    local items = {}
    for _, it in ipairs(boss.items or {}) do
      local ok = true
      if slot and it.slot ~= slot then
        ok = false
      end
      if ok and search then
        local hay = (it.name or ""):lower() .. " " .. tostring(it.itemId)
        if not hay:find(search, 1, true) then
          ok = false
        end
      end
      if ok then
        items[#items + 1] = it
      end
    end
    if #items > 0 then
      bosses[#bosses + 1] = {
        npcId = boss.npcId,
        name = boss.name,
        order = boss.order,
        items = items,
      }
    end
  end
  return bosses
end

function CrusaderStrikeLoot.LookupItem(gameVersion, itemId)
  local t = CrusaderStrikeLoot.GetTable(gameVersion)
  if not t then
    return nil
  end
  for mapId, dungeon in pairs(t) do
    for _, boss in ipairs(dungeon.bosses or {}) do
      for _, it in ipairs(boss.items or {}) do
        if it.itemId == itemId then
          return it, boss, dungeon, mapId
        end
      end
    end
  end
  return nil
end

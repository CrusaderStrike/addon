-- Gear-browser adapter for the character-pane wishlist.
--
-- Baseline is intentionally empty. AtlasLoot Classic
-- (AtlasLootClassic_DungeonsAndRaids data.lua, GPL-2.0) is a layout reference
-- only — do not paste that file here. See docs/character-gear-tab.md.
--
-- Forever overlay (Data/ForeverLootOverlay.lua) replaces a baseline dungeon
-- with the same string key and adds dungeons the baseline does not have.
-- Lookups use InstanceID (Forever instanceMapId). MapID is not a fallback key.

CrusaderStrikeGearBrowser = CrusaderStrikeGearBrowser or {}
local GB = CrusaderStrikeGearBrowser

-- gameVersion -> dungeon string key -> Atlas-shaped dungeon table.
-- Leave empty. Fill later only with hand-verified Forever rows.
GB.Baseline = {
  forever = {},
}

-- Forever dungeon Normal (docs/sources.md).
GB.FOREVER_NORMAL = 1

local function version_name(gameVersion)
  if type(gameVersion) == "string" and gameVersion ~= "" then
    return gameVersion
  end
  return "forever"
end

function GB.DefaultSources(gameVersion)
  local version = version_name(gameVersion)
  local baseline = GB.Baseline and GB.Baseline[version] or {}
  local overlayRoot = CrusaderStrikeForeverLootOverlay
  local overlay = {}
  if type(overlayRoot) == "table" and type(overlayRoot.byVersion) == "table" then
    overlay = overlayRoot.byVersion[version] or {}
  end
  return {
    baseline = baseline,
    overlay = overlay,
  }
end

local function as_sources(gameVersion, sources)
  if type(sources) == "table" and (sources.baseline or sources.overlay) then
    return {
      baseline = sources.baseline or {},
      overlay = sources.overlay or {},
    }
  end
  return GB.DefaultSources(gameVersion)
end

local function instance_id_of(dungeon)
  if type(dungeon) ~= "table" then
    return nil
  end
  local id = dungeon.InstanceID
  if type(id) ~= "number" then
    id = tonumber(id)
  end
  if type(id) ~= "number" then
    return nil
  end
  return id
end

local function map_id_of(dungeon)
  if type(dungeon) ~= "table" then
    return nil
  end
  local id = dungeon.MapID
  if type(id) ~= "number" then
    id = tonumber(id)
  end
  if type(id) ~= "number" then
    return nil
  end
  return id
end

-- Overlay wins on the same dungeon string key. MapID-only dungeons are dropped.
local function merged_dungeons(sources)
  local map = {}
  local function absorb(tbl, origin)
    if type(tbl) ~= "table" then
      return
    end
    for key, dungeon in pairs(tbl) do
      if type(key) == "string" and type(dungeon) == "table" then
        local instanceId = instance_id_of(dungeon)
        if instanceId then
          map[key] = {
            key = key,
            dungeon = dungeon,
            origin = origin,
            instanceId = instanceId,
          }
        end
      end
    end
  end
  absorb(sources.baseline, "baseline")
  absorb(sources.overlay, "overlay")
  return map
end

local function difficulty_rows(boss, difficulty)
  if type(boss) ~= "table" then
    return nil
  end
  local rows = boss[difficulty]
  if type(rows) ~= "table" and difficulty ~= nil then
    rows = boss[tostring(difficulty)]
  end
  if type(rows) ~= "table" then
    return nil
  end
  return rows
end

-- Atlas row is { slotIndex, itemID }. Non-numeric item ids (headers, icons) are skipped.
local function parse_row(row)
  if type(row) ~= "table" then
    return nil
  end
  local slotIndex = tonumber(row.slotIndex or row[1])
  local itemId = tonumber(row.itemID or row.itemId or row[2])
  if not slotIndex or not itemId then
    return nil
  end
  if slotIndex < 1 or itemId < 1 or itemId ~= math.floor(itemId) then
    return nil
  end
  local hinted = row.name
  if type(hinted) ~= "string" or hinted == "" then
    hinted = nil
  end
  if not hinted and type(row[3]) == "string" and row[3] ~= "" then
    hinted = row[3]
  end
  return slotIndex, itemId, hinted
end

function GB.ItemName(itemId, hinted, gameVersion)
  if type(hinted) == "string" and hinted ~= "" then
    return hinted
  end
  itemId = tonumber(itemId)
  if not itemId or not CrusaderStrikeLoot or not CrusaderStrikeLoot.LookupItem then
    return nil
  end
  local it = CrusaderStrikeLoot.LookupItem(version_name(gameVersion), itemId)
  if type(it) == "table" and type(it.name) == "string" and it.name ~= "" then
    return it.name
  end
  return nil
end

local function each_item(dungeon, difficulty)
  local out = {}
  local bosses = dungeon and dungeon.items
  if type(bosses) ~= "table" then
    return out
  end
  for bossIndex, boss in ipairs(bosses) do
    if type(boss) == "table" then
      local rows = difficulty_rows(boss, difficulty)
      if rows then
        for _, row in ipairs(rows) do
          local slotIndex, itemId, hinted = parse_row(row)
          if slotIndex then
            out[#out + 1] = {
              bossIndex = bossIndex,
              npcId = tonumber(boss.npcID or boss.npcId),
              bossName = type(boss.name) == "string" and boss.name or nil,
              atlasSlotIndex = slotIndex,
              itemId = itemId,
              hintedName = hinted,
            }
          end
        end
      end
    end
  end
  return out
end

local function sort_dungeons(list)
  table.sort(list, function(a, b)
    if a.name == b.name then
      return (a.instanceId or 0) < (b.instanceId or 0)
    end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

function GB.ListDungeons(gameVersion, sources)
  sources = as_sources(gameVersion, sources)
  local difficulty = GB.FOREVER_NORMAL
  local list = {}
  for _, entry in pairs(merged_dungeons(sources)) do
    local dungeon = entry.dungeon
    local items = each_item(dungeon, difficulty)
    list[#list + 1] = {
      key = entry.key,
      name = type(dungeon.name) == "string" and dungeon.name or entry.key,
      instanceId = entry.instanceId,
      mapId = map_id_of(dungeon),
      itemCount = #items,
      origin = entry.origin,
      verified = dungeon.verified == true,
    }
  end
  return sort_dungeons(list)
end

local function search_match(itemId, name, search)
  if type(search) ~= "string" then
    return true
  end
  search = (search:match("^%s*(.-)%s*$")) or ""
  if search == "" then
    return true
  end
  if search:match("^%d+$") then
    return tostring(itemId):find(search, 1, true) ~= nil
  end
  if type(name) ~= "string" or name == "" then
    return false
  end
  return name:lower():find(search:lower(), 1, true) ~= nil
end

function GB.Filter(query, gameVersion, sources)
  query = query or {}
  sources = as_sources(gameVersion, sources)
  local difficulty = tonumber(query.difficulty) or GB.FOREVER_NORMAL
  local wantInstance = tonumber(query.instanceId)
  local search = query.search
  local rows = {}
  for _, entry in pairs(merged_dungeons(sources)) do
    if not wantInstance or entry.instanceId == wantInstance then
      local dungeon = entry.dungeon
      local dungeonName = type(dungeon.name) == "string" and dungeon.name or entry.key
      for _, item in ipairs(each_item(dungeon, difficulty)) do
        local name = GB.ItemName(item.itemId, item.hintedName, gameVersion)
        if search_match(item.itemId, name, search) then
          rows[#rows + 1] = {
            dungeonKey = entry.key,
            dungeonName = dungeonName,
            instanceId = entry.instanceId,
            mapId = map_id_of(dungeon),
            npcId = item.npcId,
            bossName = item.bossName,
            bossIndex = item.bossIndex,
            difficulty = difficulty,
            atlasSlotIndex = item.atlasSlotIndex,
            itemId = item.itemId,
            name = name,
            origin = entry.origin,
          }
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.dungeonName ~= b.dungeonName then
      return tostring(a.dungeonName) < tostring(b.dungeonName)
    end
    if a.instanceId ~= b.instanceId then
      return (a.instanceId or 0) < (b.instanceId or 0)
    end
    if a.bossIndex ~= b.bossIndex then
      return (a.bossIndex or 0) < (b.bossIndex or 0)
    end
    if a.atlasSlotIndex ~= b.atlasSlotIndex then
      return (a.atlasSlotIndex or 0) < (b.atlasSlotIndex or 0)
    end
    return (a.itemId or 0) < (b.itemId or 0)
  end)
  return rows
end

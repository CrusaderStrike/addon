--[[
  Pure wish-list helpers (no WoW frame APIs).
  Per-character, per-dungeon lists live on CrusaderStrikeCharDB.wishLists:
    wishLists = {
      ["389"] = {                          -- tostring(instanceMapId)
        items = {
          { itemId = 14145, bossNpcId = 11520, obtained = false, order = 1 },
          ...
        },
      },
    }
]]

CrusaderStrikeWishList = CrusaderStrikeWishList or {}
local W = CrusaderStrikeWishList

local function key_for(instanceMapId)
  return tostring(instanceMapId)
end

local function ensure_dungeon(charDB, instanceMapId)
  if type(charDB) ~= "table" then
    return nil
  end
  charDB.wishLists = charDB.wishLists or {}
  local k = key_for(instanceMapId)
  local bucket = charDB.wishLists[k]
  if type(bucket) ~= "table" then
    bucket = { items = {} }
    charDB.wishLists[k] = bucket
  end
  if type(bucket.items) ~= "table" then
    bucket.items = {}
  end
  return bucket
end

local function find_index(items, itemId)
  for i, row in ipairs(items) do
    if row.itemId == itemId then
      return i, row
    end
  end
  return nil, nil
end

local function renumber(items)
  for i, row in ipairs(items) do
    row.order = i
  end
end

function W.GetDungeonList(charDB, instanceMapId)
  if type(charDB) ~= "table" or type(charDB.wishLists) ~= "table" then
    return {}
  end
  local bucket = charDB.wishLists[key_for(instanceMapId)]
  if not bucket or type(bucket.items) ~= "table" then
    return {}
  end
  local out = {}
  for i, row in ipairs(bucket.items) do
    out[i] = {
      itemId = row.itemId,
      bossNpcId = row.bossNpcId,
      obtained = row.obtained and true or false,
      order = row.order or i,
    }
  end
  return out
end

function W.IsWished(charDB, instanceMapId, itemId)
  if type(charDB) ~= "table" or type(charDB.wishLists) ~= "table" then
    return false
  end
  local bucket = charDB.wishLists[key_for(instanceMapId)]
  if not bucket or type(bucket.items) ~= "table" then
    return false
  end
  local _, row = find_index(bucket.items, itemId)
  return row ~= nil
end

function W.Add(charDB, instanceMapId, itemId, opts)
  opts = opts or {}
  if not instanceMapId or not itemId then
    return false, "missing_id"
  end
  itemId = tonumber(itemId)
  if not itemId then
    return false, "bad_item"
  end
  local bucket = ensure_dungeon(charDB, instanceMapId)
  if not bucket then
    return false, "no_db"
  end
  local idx, existing = find_index(bucket.items, itemId)
  if existing then
    return false, "duplicate"
  end
  local row = {
    itemId = itemId,
    bossNpcId = opts.bossNpcId and tonumber(opts.bossNpcId) or nil,
    obtained = opts.obtained and true or false,
    order = #bucket.items + 1,
  }
  bucket.items[#bucket.items + 1] = row
  return true, row
end

function W.Remove(charDB, instanceMapId, itemId)
  itemId = tonumber(itemId)
  local bucket = ensure_dungeon(charDB, instanceMapId)
  if not bucket or not itemId then
    return false, "missing"
  end
  local idx = find_index(bucket.items, itemId)
  if not idx then
    return false, "not_found"
  end
  table.remove(bucket.items, idx)
  renumber(bucket.items)
  return true
end

-- Move item to 1-based newIndex (clamped).
function W.Reorder(charDB, instanceMapId, itemId, newIndex)
  itemId = tonumber(itemId)
  newIndex = tonumber(newIndex)
  local bucket = ensure_dungeon(charDB, instanceMapId)
  if not bucket or not itemId or not newIndex then
    return false, "missing"
  end
  local idx = find_index(bucket.items, itemId)
  if not idx then
    return false, "not_found"
  end
  local n = #bucket.items
  if newIndex < 1 then
    newIndex = 1
  end
  if newIndex > n then
    newIndex = n
  end
  if newIndex == idx then
    return true, bucket.items[idx]
  end
  local row = table.remove(bucket.items, idx)
  table.insert(bucket.items, newIndex, row)
  renumber(bucket.items)
  return true, row
end

function W.MarkObtained(charDB, instanceMapId, itemId, obtained)
  itemId = tonumber(itemId)
  local bucket = ensure_dungeon(charDB, instanceMapId)
  if not bucket or not itemId then
    return false, "missing"
  end
  local _, row = find_index(bucket.items, itemId)
  if not row then
    return false, "not_found"
  end
  row.obtained = obtained and true or false
  return true, row
end

-- Mark every wish-list entry matching itemId across ALL dungeons (loot toast
-- may not know which dungeon the player is in if they hearth mid-run).
-- Prefer the in-instance mapId when provided.
function W.MarkObtainedAny(charDB, itemId, obtained, preferMapId)
  itemId = tonumber(itemId)
  if type(charDB) ~= "table" or not itemId then
    return 0
  end
  obtained = obtained and true or false
  local n = 0
  if preferMapId and W.IsWished(charDB, preferMapId, itemId) then
    local ok = W.MarkObtained(charDB, preferMapId, itemId, obtained)
    if ok then
      return 1
    end
  end
  if type(charDB.wishLists) ~= "table" then
    return 0
  end
  for mapKey, bucket in pairs(charDB.wishLists) do
    if type(bucket) == "table" and type(bucket.items) == "table" then
      local _, row = find_index(bucket.items, itemId)
      if row then
        row.obtained = obtained
        n = n + 1
      end
    end
  end
  return n
end

function W.WantedCount(charDB, instanceMapId)
  local list = W.GetDungeonList(charDB, instanceMapId)
  local wanted, obtained = 0, 0
  for _, row in ipairs(list) do
    if row.obtained then
      obtained = obtained + 1
    else
      wanted = wanted + 1
    end
  end
  return wanted, obtained, #list
end

-- itemIds currently wished-for (not yet obtained) in this dungeon.
function W.WantedItemIds(charDB, instanceMapId)
  local list = W.GetDungeonList(charDB, instanceMapId)
  local out = {}
  for _, row in ipairs(list) do
    if not row.obtained then
      out[row.itemId] = true
    end
  end
  return out
end

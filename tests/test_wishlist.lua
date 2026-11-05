describe("WishList add/remove/reorder", function()
  it("adds and rejects duplicates", function()
    local db = { wishLists = {} }
    local added, row = CrusaderStrikeWishList.Add(db, 389, 14145, { bossNpcId = 11520 })
    ok(added, "add ok")
    eq(row.itemId, 14145)
    eq(row.bossNpcId, 11520)
    eq(row.obtained, false)
    eq(row.order, 1)
    local ok2, err = CrusaderStrikeWishList.Add(db, 389, 14145, {})
    eq(ok2, false)
    eq(err, "duplicate")
    ok(CrusaderStrikeWishList.IsWished(db, 389, 14145))
    ok(not CrusaderStrikeWishList.IsWished(db, 389, 99999))
  end)

  it("removes and renumbers", function()
    local db = { wishLists = {} }
    CrusaderStrikeWishList.Add(db, 389, 14145, {})
    CrusaderStrikeWishList.Add(db, 389, 14148, {})
    CrusaderStrikeWishList.Add(db, 389, 14149, {})
    local removed = CrusaderStrikeWishList.Remove(db, 389, 14148)
    ok(removed)
    local list = CrusaderStrikeWishList.GetDungeonList(db, 389)
    eq(#list, 2)
    eq(list[1].itemId, 14145)
    eq(list[1].order, 1)
    eq(list[2].itemId, 14149)
    eq(list[2].order, 2)
  end)

  it("reorders within bounds", function()
    local db = { wishLists = {} }
    CrusaderStrikeWishList.Add(db, 36, 5187, {})
    CrusaderStrikeWishList.Add(db, 36, 872, {})
    CrusaderStrikeWishList.Add(db, 36, 1937, {})
    CrusaderStrikeWishList.Reorder(db, 36, 1937, 1)
    local list = CrusaderStrikeWishList.GetDungeonList(db, 36)
    eq(list[1].itemId, 1937)
    eq(list[2].itemId, 5187)
    eq(list[3].itemId, 872)
    eq(list[1].order, 1)
    eq(list[3].order, 3)
  end)

  it("marks obtained and counts wanted", function()
    local db = { wishLists = {} }
    CrusaderStrikeWishList.Add(db, 389, 14145, {})
    CrusaderStrikeWishList.Add(db, 389, 273003, {})
    CrusaderStrikeWishList.MarkObtained(db, 389, 14145, true)
    local wanted, obtained, total = CrusaderStrikeWishList.WantedCount(db, 389)
    eq(wanted, 1)
    eq(obtained, 1)
    eq(total, 2)
    local ids = CrusaderStrikeWishList.WantedItemIds(db, 389)
    ok(ids[273003])
    ok(not ids[14145])
  end)

  it("MarkObtainedAny prefers current map then scans", function()
    local db = { wishLists = {} }
    CrusaderStrikeWishList.Add(db, 389, 14145, {})
    CrusaderStrikeWishList.Add(db, 36, 14145, {}) -- same item id on another list
    local n = CrusaderStrikeWishList.MarkObtainedAny(db, 14145, true, 389)
    eq(n, 1)
    local list389 = CrusaderStrikeWishList.GetDungeonList(db, 389)
    local list36 = CrusaderStrikeWishList.GetDungeonList(db, 36)
    eq(list389[1].obtained, true)
    eq(list36[1].obtained, false)
    -- without prefer, marks all
    CrusaderStrikeWishList.MarkObtained(db, 389, 14145, false)
    n = CrusaderStrikeWishList.MarkObtainedAny(db, 14145, true, nil)
    eq(n, 2)
  end)

  it("isolates lists per dungeon", function()
    local db = { wishLists = {} }
    CrusaderStrikeWishList.Add(db, 389, 14145, {})
    eq(#CrusaderStrikeWishList.GetDungeonList(db, 36), 0)
    eq(#CrusaderStrikeWishList.GetDungeonList(db, 389), 1)
  end)
end)

describe("Loot data RFC sample", function()
  it("lists Ragefire Chasm with verified items", function()
    local list = CrusaderStrikeLoot.ListDungeons("forever")
    local found
    for _, d in ipairs(list) do
      if d.instanceMapId == 389 then
        found = d
      end
    end
    ok(found, "RFC present")
    ok(found.verified)
    eq(found.itemCount, 12)
  end)

  it("filters by slot and search", function()
    local dungeon = CrusaderStrikeLoot.GetDungeon("forever", 389)
    local bosses = CrusaderStrikeLoot.FilterDungeon(dungeon, { slot = "Weapon" })
    local n = 0
    for _, b in ipairs(bosses) do
      n = n + #b.items
      for _, it in ipairs(b.items) do
        eq(it.slot, "Weapon")
      end
    end
    ok(n >= 5, "several weapons")
    local byName = CrusaderStrikeLoot.FilterDungeon(dungeon, { search = "felblade" })
    eq(#byName, 1)
    eq(byName[1].items[1].itemId, 14145)
  end)

  it("looks up Forever-new Bazzalan IDs", function()
    local it, boss, dungeon, mapId = CrusaderStrikeLoot.LookupItem("forever", 273007)
    eq(mapId, 389)
    eq(boss.npcId, 11519)
    eq(it.name, "Chasm Walkers")
    eq(it.slot, "Feet")
  end)

  it("does not invent loot for unverified dungeons", function()
    local deadmines = CrusaderStrikeLoot.GetDungeon("forever", 36)
    eq(deadmines, nil)
  end)
end)

describe("loot chat parse", function()
  it("extracts item id from CHAT_MSG_LOOT link", function()
    local LB = CrusaderStrike and CrusaderStrike.LootBrowser
    ok(LB and LB._parse_loot_item_id, "LootBrowser parse helper loaded")
    local msg = "You receive loot: |cffa335ee|Hitem:14145:0:0:0:0:0:0:0:0|h[Cursed Felblade]|h|r."
    eq(LB._parse_loot_item_id(msg), 14145)
    eq(LB._parse_loot_item_id("no link here"), nil)
  end)
end)

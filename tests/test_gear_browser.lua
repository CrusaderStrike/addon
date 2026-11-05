describe("gear browser adapter", function()
  it("ships an empty Atlas-shaped baseline", function()
    local n = 0
    for _ in pairs(CrusaderStrikeGearBrowser.Baseline.forever or {}) do
      n = n + 1
    end
    eq(n, 0)
  end)

  it("searches the example overlay by verified item id and name", function()
    local rows = CrusaderStrikeGearBrowser.Filter({ search = "272999" })
    eq(#rows, 1)
    eq(rows[1].itemId, 272999)
    eq(rows[1].instanceId, 389)
    eq(rows[1].name, "Barbaric Crossbow")
    eq(rows[1].atlasSlotIndex, 1)
    eq(rows[1].npcId, 11517)
    eq(rows[1].origin, "overlay")
    rows = CrusaderStrikeGearBrowser.Filter({ search = "BARBARIC" })
    eq(#rows, 1)
    eq(rows[1].itemId, 272999)
    rows = CrusaderStrikeGearBrowser.Filter({ search = "2729" })
    eq(#rows, 3)
  end)

  it("does not treat a boss name as an item search", function()
    local rows = CrusaderStrikeGearBrowser.Filter({ search = "oggleflint" })
    eq(#rows, 0)
  end)

  it("example overlay item ids are already in Data/Loot.lua", function()
    local rows = CrusaderStrikeGearBrowser.Filter({})
    ok(#rows > 0)
    for _, row in ipairs(rows) do
      local it, _, _, mapId = CrusaderStrikeLoot.LookupItem("forever", row.itemId)
      ok(it ~= nil, "verified item " .. tostring(row.itemId))
      eq(mapId, row.instanceId)
    end
  end)

  it("prefers InstanceID and ignores MapID-only dungeons", function()
    local sources = {
      baseline = {
        MapOnly = {
          name = "Map Only",
          MapID = 389,
          items = {
            { npcID = 1, [1] = { { 1, 14145 } } },
          },
        },
      },
      overlay = {
        Deadmines = {
          name = "Deadmines",
          InstanceID = 36,
          MapID = 1,
          items = {
            { name = "Edwin VanCleef", npcID = 639, [1] = { { 1, 14145 } } },
          },
        },
      },
    }
    local list = CrusaderStrikeGearBrowser.ListDungeons("forever", sources)
    eq(#list, 1)
    eq(list[1].instanceId, 36)
    eq(list[1].mapId, 1)
    local rows = CrusaderStrikeGearBrowser.Filter({ instanceId = 1 }, "forever", sources)
    eq(#rows, 0)
    rows = CrusaderStrikeGearBrowser.Filter({ instanceId = 36, search = "14145" }, "forever", sources)
    eq(#rows, 1)
    eq(rows[1].itemId, 14145)
    eq(rows[1].atlasSlotIndex, 1)
    eq(rows[1].name, "Cursed Felblade")
  end)

  it("lets the Forever overlay replace a baseline dungeon key", function()
    local sources = {
      baseline = {
        RagefireChasm = {
          name = "Baseline",
          InstanceID = 389,
          items = {
            { npcID = 1, [1] = { { 1, 111 } } },
          },
        },
        Extra = {
          name = "Extra",
          InstanceID = 43,
          items = {
            { npcID = 2, [1] = { { 1, 14148 } } },
          },
        },
      },
      overlay = {
        RagefireChasm = {
          name = "Overlay",
          InstanceID = 389,
          items = {
            { npcID = 11517, [1] = { { 1, 272999 } } },
          },
        },
      },
    }
    local rows = CrusaderStrikeGearBrowser.Filter({ instanceId = 389 }, "forever", sources)
    eq(#rows, 1)
    eq(rows[1].itemId, 272999)
    eq(rows[1].dungeonName, "Overlay")
    eq(rows[1].origin, "overlay")
    rows = CrusaderStrikeGearBrowser.Filter({ instanceId = 43 }, "forever", sources)
    eq(#rows, 1)
    eq(rows[1].itemId, 14148)
    eq(rows[1].origin, "baseline")
  end)

  it("reads difficulty 1 by default and skips non-numeric atlas rows", function()
    local sources = {
      baseline = {},
      overlay = {
        Sample = {
          name = "Sample",
          InstanceID = 389,
          items = {
            {
              npcID = 11517,
              [1] = {
                { 1, 272999 },
                { 16, "INV_Box_01" },
              },
              [2] = {
                { 1, 14145 },
              },
            },
          },
        },
      },
    }
    local rows = CrusaderStrikeGearBrowser.Filter({}, "forever", sources)
    eq(#rows, 1)
    eq(rows[1].itemId, 272999)
    eq(rows[1].difficulty, 1)
    rows = CrusaderStrikeGearBrowser.Filter({ difficulty = 2 }, "forever", sources)
    eq(#rows, 1)
    eq(rows[1].itemId, 14145)
  end)
end)

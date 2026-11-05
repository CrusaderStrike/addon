describe("bosses Forever", function()
  it("looks up VanCleef in Deadmines", function()
    local boss, dungeon = CrusaderStrikeBosses.Lookup("forever", 36, 639)
    eq(boss.name, "Edwin VanCleef")
    eq(dungeon.name, "The Deadmines")
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 36, 639))
    ok(not CrusaderStrikeBosses.IsFinalBoss("forever", 36, 644))
  end)

  it("looks up RFC Bazzalan as final", function()
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 389, 11519))
  end)

  it("only the forever table exists", function()
    ok(CrusaderStrikeBosses.byVersion.sod == nil)
    ok(CrusaderStrikeBosses.byVersion.era == nil)
    eq(CrusaderStrikeBosses.defaultVersion, "forever")
  end)

  it("includes verified Forever new dungeon map ids", function()
    local t = CrusaderStrikeBosses.GetTable("forever")
    eq(t[3065].name, "The Hall of Thanes")
    eq(t[2999].name, "Ruins of Lordaeron")
    eq(t[2998].name, "Excavation Site: Wetlands")
    eq(t[2959].name, "City of Dalaran")
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 3065, 261319))
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 2999, 250657))
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 2998, 260326))
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 2959, 246020))
  end)

  it("looks up Magmatus and Faldrim in Hall of Thanes", function()
    local boss = CrusaderStrikeBosses.Lookup("forever", 3065, 261316)
    eq(boss.name, "Magmatus")
    local faldrim = CrusaderStrikeBosses.Lookup("forever", 3065, 261306)
    eq(faldrim.name, "Faldrim Anvilmar")
    ok(not CrusaderStrikeBosses.IsFinalBoss("forever", 3065, 261306))
  end)

  it("lists pending Forever dungeons without invented map ids", function()
    local pending = CrusaderStrikeBosses.pendingForeverDungeons
    ok(type(pending) == "table")
    eq(#pending, 5)
    eq(pending[1].name, "The Drowned City")
    eq(CrusaderStrikeBosses.normalDifficultyId, 1)
  end)

  it("keeps unverified Dalaran encounters out of the boss table", function()
    local pe = CrusaderStrikeBosses.pendingForeverEncounters
    eq(#pe, 2)
    eq(pe[1].encounterId, 3301)
    eq(pe[2].encounterId, 3312)
    ok(pe[1].npcId == nil and pe[2].npcId == nil)
    -- Shade of the Archmage (DungeonEncounter OrderIndex 9000) stays the final trigger.
    ok(CrusaderStrikeBosses.IsFinalBoss("forever", 2959, 246020))
    ok(not CrusaderStrikeBosses.IsFinalBoss("forever", 2959, 247126))
  end)

  it("creature guid parse helper", function()
    -- Inline the same pattern DungeonLog uses (avoid loading CreateFrame-heavy files).
    local function creature_id_from_guid(guid)
      local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
      return id and tonumber(id) or nil
    end
    eq(creature_id_from_guid("Creature-0-1234-36-12-639-00001"), 639)
    eq(creature_id_from_guid("Creature-0-1234-3065-12-261319-00001"), 261319)
    eq(creature_id_from_guid("Player-1-ABCDEF"), nil)
  end)
end)

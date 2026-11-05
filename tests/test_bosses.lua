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

  it("creature guid parse helper", function()
    -- Inline the same pattern DungeonLog uses (avoid loading CreateFrame-heavy files).
    local function creature_id_from_guid(guid)
      local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
      return id and tonumber(id) or nil
    end
    eq(creature_id_from_guid("Creature-0-1234-36-12-639-00001"), 639)
    eq(creature_id_from_guid("Player-1-ABCDEF"), nil)
  end)
end)

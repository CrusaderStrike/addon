describe("gear slots", function()
  it("has 19 platform names including shirt and tabard", function()
    local GS = CrusaderStrikeGearSlots
    eq(#GS.NAMES, 19)
    ok(GS.IsValidName("shirt"))
    ok(GS.IsValidName("tabard"))
    ok(GS.IsValidName("main_hand"))
    ok(not GS.IsValidName("mainHand"))
    eq(GS.InvToName(16), "main_hand")
    eq(GS.NameToInv("ranged"), 18)
  end)
end)

describe("equipped gear parse", function()
  it("parses item and enchant from Hitem link", function()
    local p = CrusaderStrikeEquippedGear.ParseItemLink("|cffffffff|Hitem:14145:2564:0:0:0:0:0:0:0|h[Blade]|h|r")
    eq(p.item_id, 14145)
    eq(p.enchant_id, 2564)
  end)

  it("rejects display names and bad ids", function()
    eq(CrusaderStrikeEquippedGear.ParseItemLink("Blade of Eternal Darkness"), nil)
    eq(CrusaderStrikeEquippedGear.ParseItemLink("|Hitem:0:0|h[x]|h"), nil)
    eq(CrusaderStrikeEquippedGear.ParseItemLink(nil), nil)
  end)

  it("scans GetInventoryItemLink for slots 1-19", function()
    _G._CS_TestEquipped = {
      [16] = "|Hitem:19019:0:0:0:0:0:0:0:0|h[Thunderfury]|h",
      [9] = "|Hitem:14148:0|h[Wrist]|h",
    }
    local map = CrusaderStrikeEquippedGear.ScanNow()
    eq(map.main_hand.item_id, 19019)
    eq(map.wrist.item_id, 14148)
    eq(map.head, nil)
    _G._CS_TestEquipped = nil
  end)
end)

describe("CSGEAR1 encode/decode", function()
  local function sample_payload()
    return {
      schema_version = 1,
      game_version = "forever",
      region = "us",
      realm = "CrusaderStrike",
      character = "Snipy",
      character_id = nil,
      exported_at = "2026-11-05T06:30:00Z",
      equipped = {
        main_hand = { item_id = 14145, enchant_id = 0 },
        wrist = { item_id = 14148 },
      },
      lists = {
        {
          id = nil,
          local_id = "a3f09c12",
          name = "Pre-BiS 50",
          type = "leveling",
          until_level = 50,
          role_spec = "fury",
          edited_at = "2026-11-05T06:29:10Z",
          edited_in = "game",
          slots = { head = 12345, main_hand = 19019, off_hand = nil },
          removes = {},
        },
        {
          id = "7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21",
          local_id = "5e7d1b90",
          name = "Tank BiS",
          type = "max_level",
          until_level = nil,
          role_spec = nil,
          edited_at = "2026-11-05T05:58:00Z",
          edited_in = "web",
          slots = { chest = 16966 },
          removes = {
            { op = "clear_slot", slot = "off_hand" },
            { op = "remove_item", slot = "wrist", item_id = 14149 },
          },
        },
      },
      deleted_lists = {},
    }
  end

  it("FNV-1a matches schema worked example JSON bytes", function()
    -- Exact compact sorted-key JSON from gear-list-schema.md (includes explicit nulls).
    local json = [[{"character":"Snipy","character_id":null,"deleted_lists":[],"equipped":{"main_hand":{"enchant_id":0,"item_id":14145},"wrist":{"item_id":14148}},"exported_at":"2026-11-05T06:30:00Z","game_version":"forever","lists":[{"edited_at":"2026-11-05T06:29:10Z","edited_in":"game","id":null,"local_id":"a3f09c12","name":"Pre-BiS 50","removes":[],"role_spec":"fury","slots":{"head":12345,"main_hand":19019,"off_hand":null},"type":"leveling","until_level":50},{"edited_at":"2026-11-05T05:58:00Z","edited_in":"web","id":"7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21","local_id":"5e7d1b90","name":"Tank BiS","removes":[{"op":"clear_slot","slot":"off_hand"},{"item_id":14149,"op":"remove_item","slot":"wrist"}],"role_spec":null,"slots":{"chest":16966},"type":"max_level","until_level":null}],"realm":"CrusaderStrike","region":"us","schema_version":1}]]
    eq(#json, 826)
    eq(CrusaderStrikeGearEncoder.ChecksumHex(json), "c896e890")
  end)

  it("round-trips encode/decode", function()
    local encoded, err = CrusaderStrikeGearEncoder.Encode(sample_payload())
    ok(encoded ~= nil, err)
    ok(encoded:sub(1, 8) == "CSGEAR1:")
    ok(encoded:find("|c=", 1, true) ~= nil)
    local payload, derr = CrusaderStrikeGearEncoder.Decode(encoded)
    ok(payload ~= nil, derr)
    eq(payload.character, "Snipy")
    eq(#payload.lists, 2)
    eq(payload.lists[1].local_id, "a3f09c12")
    eq(payload.lists[2].slots.chest, 16966)
  end)

  it("decodes the schema worked example envelope", function()
    local env = "CSGEAR1:eyJjaGFyYWN0ZXIiOiJTbmlweSIsImNoYXJhY3Rlcl9pZCI6bnVsbCwiZGVsZXRlZF9saXN0cyI6W10sImVxdWlwcGVkIjp7Im1haW5faGFuZCI6eyJlbmNoYW50X2lkIjowLCJpdGVtX2lkIjoxNDE0NX0sIndyaXN0Ijp7Iml0ZW1faWQiOjE0MTQ4fX0sImV4cG9ydGVkX2F0IjoiMjAyNi0xMS0wNVQwNjozMDowMFoiLCJnYW1lX3ZlcnNpb24iOiJmb3JldmVyIiwibGlzdHMiOlt7ImVkaXRlZF9hdCI6IjIwMjYtMTEtMDVUMDY6Mjk6MTBaIiwiZWRpdGVkX2luIjoiZ2FtZSIsImlkIjpudWxsLCJsb2NhbF9pZCI6ImEzZjA5YzEyIiwibmFtZSI6IlByZS1CaVMgNTAiLCJyZW1vdmVzIjpbXSwicm9sZV9zcGVjIjoiZnVyeSIsInNsb3RzIjp7ImhlYWQiOjEyMzQ1LCJtYWluX2hhbmQiOjE5MDE5LCJvZmZfaGFuZCI6bnVsbH0sInR5cGUiOiJsZXZlbGluZyIsInVudGlsX2xldmVsIjo1MH0seyJlZGl0ZWRfYXQiOiIyMDI2LTExLTA1VDA1OjU4OjAwWiIsImVkaXRlZF9pbiI6IndlYiIsImlkIjoiN2IxZTJjNGEtMGQxZi00ZThhLTljM2ItMmE2ZjVlNGQzYzIxIiwibG9jYWxfaWQiOiI1ZTdkMWI5MCIsIm5hbWUiOiJUYW5rIEJpUyIsInJlbW92ZXMiOlt7Im9wIjoiY2xlYXJfc2xvdCIsInNsb3QiOiJvZmZfaGFuZCJ9LHsiaXRlbV9pZCI6MTQxNDksIm9wIjoicmVtb3ZlX2l0ZW0iLCJzbG90Ijoid3Jpc3QifV0sInJvbGVfc3BlYyI6bnVsbCwic2xvdHMiOnsiY2hlc3QiOjE2OTY2fSwidHlwZSI6Im1heF9sZXZlbCIsInVudGlsX2xldmVsIjpudWxsfV0sInJlYWxtIjoiQ3J1c2FkZXJTdHJpa2UiLCJyZWdpb24iOiJ1cyIsInNjaGVtYV92ZXJzaW9uIjoxfQ==|c=c896e890"
    local payload, err = CrusaderStrikeGearEncoder.Decode(env)
    ok(payload ~= nil, err)
    eq(payload.lists[1].name, "Pre-BiS 50")
    eq(payload.equipped.main_hand.item_id, 14145)
  end)

  it("rejects bad prefix checksum and character mismatch", function()
    local _, e1 = CrusaderStrikeGearEncoder.Decode("CSRUN1:abc")
    eq(e1, "bad_prefix")
    local good = CrusaderStrikeGearEncoder.Encode(sample_payload())
    local tampered = good:gsub("|c=[0-9a-f]+", "|c=deadbeef")
    local _, e2 = CrusaderStrikeGearEncoder.Decode(tampered)
    eq(e2, "bad_checksum")
    local _, e3 = CrusaderStrikeGearEncoder.Decode(good, {
      expect_realm = "CrusaderStrike",
      expect_character = "SomeoneElse",
    })
    eq(e3, "character_mismatch")
  end)

  it("rejects invalid set type and unknown slots", function()
    local p = sample_payload()
    p.lists[1].type = "bis"
    local enc = CrusaderStrikeGearEncoder.Encode(p)
    -- Encode does not validate; Decode does
    local _, err = CrusaderStrikeGearEncoder.Decode(enc)
    eq(err, "validation")
    p = sample_payload()
    p.lists[1].slots.fake_slot = 1
    enc = CrusaderStrikeGearEncoder.Encode(p)
    _, err = CrusaderStrikeGearEncoder.Decode(enc)
    eq(err, "validation")
  end)

  it("enforces paste size cap", function()
    local huge = "CSGEAR1:" .. string.rep("A", 25 * 1024) .. "|c=00000000"
    local _, err = CrusaderStrikeGearEncoder.Decode(huge)
    eq(err, "too_large")
  end)
end)

describe("gear sets storage", function()
  local function fresh_db()
    return {
      schemaVersion = 4,
      gameVersion = "forever",
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
  end

  it("creates leveling set below 60 and coerces to max_level at 60", function()
    local db = fresh_db()
    local list, err = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS",
      type = "leveling",
      until_level = 40,
    }, 25)
    ok(list ~= nil, err)
    eq(list.type, "leveling")
    eq(list.until_level, 40)
    eq(#list.local_id, 8)

    -- At 60 CreateSet forces max_level (UI has no leveling option).
    local coerced, err60 = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Late",
      type = "leveling",
      until_level = 60,
    }, 60)
    ok(coerced ~= nil, err60)
    eq(coerced.type, "max_level")
    eq(coerced.until_level, nil)

    local okv, code = CrusaderStrikeGearSets.ValidateUntilLevel("leveling", 60, 60)
    eq(okv, false)
    eq(code, "leveling_set_at_max_level")

    local maxset, merr = CrusaderStrikeGearSets.CreateSet(db, {
      name = "BiS",
      type = "max_level",
    }, 60)
    ok(maxset ~= nil, merr)
    eq(maxset.type, "max_level")
    eq(maxset.until_level, nil)
  end)

  it("rejects until_level not above current level", function()
    local db = fresh_db()
    local _, err = CrusaderStrikeGearSets.CreateSet(db, {
      name = "TooLow",
      type = "leveling",
      until_level = 25,
    }, 25)
    eq(err, "until_level_not_above_current_level")
  end)

  it("returns list_limit_reached at 20 sets", function()
    local db = fresh_db()
    for i = 1, 20 do
      local list, err = CrusaderStrikeGearSets.CreateSet(db, {
        name = "Set " .. i,
        type = "max_level",
      }, 60)
      ok(list ~= nil, err)
    end
    local _, err = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Overflow",
      type = "max_level",
    }, 60)
    eq(err, "list_limit_reached")
  end)

  it("set/clear slot records clear_slot and pending set_slot/clear_slot ops", function()
    local db = fresh_db()
    CrusaderStrikeGearOps.SetMode("set_slot")
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "A", type = "max_level" }, 60)
    local _, ops_set = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    eq(list.slots.head, 12345)
    ok(ops_set ~= nil)
    eq(#ops_set, 1)
    eq(ops_set[1].type, "set_slot")
    eq(ops_set[1].item_id, 12345)
    eq(ops_set[1].slot, "head")
    ok(CrusaderStrikeGearOps.IsOpId(ops_set[1].op_id))
    eq(ops_set[1].base_version, 0)

    local _, ops_clear = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", nil)
    eq(list.slots.head, nil)
    eq(#ops_clear, 1)
    eq(ops_clear[1].type, "clear_slot")
    eq(ops_clear[1].item_id, nil)
    local saw_clear, saw_remove = false, false
    for _, op in ipairs(list.removes) do
      if op.op == "clear_slot" and op.slot == "head" then
        saw_clear = true
      end
      if op.op == "remove_item" and op.item_id == 12345 then
        saw_remove = true
      end
    end
    ok(saw_clear)
    eq(saw_remove, false) -- Option B: no remove_item companion
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#pending, 1)
    eq(pending[1].type, "clear_slot") -- set replaced by later clear for same slot
  end)

  it("legacy mode still records remove_item on clear (fixture fallback)", function()
    local db = fresh_db()
    CrusaderStrikeGearOps.SetMode("legacy")
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "B", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local _, ops = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", nil)
    local saw_clear, saw_remove = false, false
    for _, op in ipairs(list.removes) do
      if op.op == "clear_slot" then saw_clear = true end
      if op.op == "remove_item" and op.item_id == 12345 then saw_remove = true end
    end
    ok(saw_clear)
    ok(saw_remove)
    -- legacy clear of one prior item → one remove_item (no add)
    eq(#ops, 1)
    eq(ops[1].type, "remove_item")
    CrusaderStrikeGearOps.SetMode("set_slot")
  end)
end)

describe("gear import merge", function()
  local function fresh_db()
    return {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
  end

  it("links local_id to server id and last-edited-wins", function()
    local db = fresh_db()
    local local_list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS 50",
      type = "leveling",
      until_level = 50,
    }, 25)
    local_list.edited_at = "2026-11-05T06:00:00Z"
    local_list.slots.head = 1

    local payload = {
      schema_version = 1,
      game_version = "forever",
      region = "us",
      realm = "CrusaderStrike",
      character = "Tester",
      character_id = "char-1",
      lists = {
        {
          id = "7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21",
          local_id = local_list.local_id,
          name = "Pre-BiS 50",
          type = "leveling",
          until_level = 50,
          role_spec = "fury",
          edited_at = "2026-11-05T07:00:00Z",
          edited_in = "web",
          slots = { head = 999 },
          removes = {},
        },
      },
      deleted_lists = {},
      equipped = { head = { item_id = 42 } }, -- must be ignored by ApplyImport caller
    }
    local applied, err = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied, err)
    eq(db.gearSets.character_id, "char-1")
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, local_list.local_id)
    eq(merged.id, "7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21")
    eq(merged.slots.head, 999)
    eq(merged.role_spec, "fury")
  end)

  it("keeps newer local edits and still links id", function()
    local db = fresh_db()
    local local_list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Mine",
      type = "max_level",
    }, 60)
    local_list.edited_at = "2026-11-05T08:00:00Z"
    local_list.slots.chest = 111
    local payload = {
      lists = {
        {
          id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          local_id = local_list.local_id,
          name = "Mine",
          type = "max_level",
          until_level = nil,
          edited_at = "2026-11-05T07:00:00Z",
          edited_in = "web",
          slots = { chest = 222 },
          removes = {},
        },
      },
      deleted_lists = {},
    }
    local applied = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied)
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, local_list.local_id)
    eq(merged.id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    eq(merged.slots.chest, 111)
  end)

  it("applies explicit removes and deleted_lists", function()
    local db = fresh_db()
    local a = CrusaderStrikeGearSets.CreateSet(db, { name = "Keep", type = "max_level" }, 60)
    local b = CrusaderStrikeGearSets.CreateSet(db, { name = "Drop", type = "max_level" }, 60)
    a.slots.off_hand = 55
    a.slots.wrist = 14149
    local payload = {
      lists = {
        {
          id = nil,
          local_id = a.local_id,
          name = "Keep",
          type = "max_level",
          until_level = nil,
          edited_at = "2026-11-05T09:00:00Z",
          edited_in = "web",
          slots = {},
          removes = {
            { op = "clear_slot", slot = "off_hand" },
            { op = "remove_item", slot = "wrist", item_id = 14149 },
          },
        },
      },
      deleted_lists = { { local_id = b.local_id } },
    }
    local applied = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied)
    eq(#db.gearSets.lists, 1)
    eq(db.gearSets.lists[1].name, "Keep")
    eq(db.gearSets.lists[1].slots.off_hand, nil)
    eq(db.gearSets.lists[1].slots.wrist, nil)
  end)
end)

describe("export build", function()
  it("BuildExportPayload includes equipped and lists", function()
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    CrusaderStrikeGearSets.CreateSet(db, { name = "A", type = "max_level" }, 60)
    _G._CS_TestEquipped = {
      [1] = "|Hitem:12345:0|h[Helm]|h",
    }
    local payload = CrusaderStrikeGearSets.BuildExportPayload(db, {
      realm = "CrusaderStrike",
      character = "Tester",
    })
    eq(payload.schema_version, 1)
    eq(payload.game_version, "forever")
    eq(#payload.lists, 1)
    eq(payload.equipped.head.item_id, 12345)
    _G._CS_TestEquipped = nil
  end)
end)

describe("gear sets validate-before-mutate (#27)", function()
  local function fresh_db()
    return {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
  end

  it("ApplyImport leaves character_id and region untouched on list_limit_reached", function()
    local db = fresh_db()
    for i = 1, 20 do
      local list, err = CrusaderStrikeGearSets.CreateSet(db, {
        name = "Set " .. i,
        type = "max_level",
      }, 60)
      ok(list ~= nil, err)
    end
    local before_lists = #db.gearSets.lists
    local payload = {
      character_id = "should-not-stick",
      region = "eu",
      lists = {
        {
          id = nil,
          local_id = "overflow1",
          name = "Overflow",
          type = "max_level",
          until_level = nil,
          role_spec = "fury",
          edited_at = "2026-11-05T10:00:00Z",
          edited_in = "web",
          slots = {},
          removes = {},
        },
      },
      deleted_lists = {},
    }
    local applied, err = CrusaderStrikeGearSets.ApplyImport(db, payload)
    eq(applied, false)
    eq(err, "list_limit_reached")
    eq(db.gearSets.character_id, nil)
    eq(db.gearSets.region, "us")
    eq(#db.gearSets.lists, before_lists)
  end)

  it("UpdateSet does not partially mutate when until_level validation fails", function()
    local db = fresh_db()
    local list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Original",
      type = "leveling",
      until_level = 40,
      role_spec = "fury",
    }, 25)
    ok(list ~= nil)
    local updated, err = CrusaderStrikeGearSets.UpdateSet(db, list.local_id, {
      name = "Renamed",
      type = "leveling",
      until_level = 25, -- not above current level 25
      role_spec = "arms",
    }, 25)
    eq(updated, nil)
    eq(err, "until_level_not_above_current_level")
    eq(list.name, "Original")
    eq(list.type, "leveling")
    eq(list.until_level, 40)
    eq(list.role_spec, "fury")
  end)

  it("empty or whitespace role_spec is stored as null on create, update, and decode", function()
    local db = fresh_db()
    local created = CrusaderStrikeGearSets.CreateSet(db, {
      name = "EmptyRole",
      type = "max_level",
      role_spec = "   ",
    }, 60)
    ok(created ~= nil)
    eq(created.role_spec, nil)

    local with_role = CrusaderStrikeGearSets.CreateSet(db, {
      name = "HasRole",
      type = "max_level",
      role_spec = "fury",
    }, 60)
    ok(with_role ~= nil)
    eq(with_role.role_spec, "fury")
    local cleared = CrusaderStrikeGearSets.UpdateSet(db, with_role.local_id, {
      role_spec = "",
    }, 60)
    ok(cleared ~= nil)
    eq(cleared.role_spec, nil)

    local payload = {
      schema_version = 1,
      game_version = "forever",
      region = "us",
      realm = "CrusaderStrike",
      character = "Tester",
      character_id = nil,
      exported_at = "2026-11-05T06:30:00Z",
      equipped = {},
      lists = {
        {
          id = nil,
          local_id = "abcd1234",
          name = "WhitespaceRole",
          type = "max_level",
          until_level = nil,
          role_spec = "  ",
          edited_at = "2026-11-05T06:29:10Z",
          edited_in = "game",
          slots = {},
          removes = {},
        },
      },
      deleted_lists = {},
    }
    local encoded, enc_err = CrusaderStrikeGearEncoder.Encode(payload)
    ok(encoded ~= nil, enc_err)
    local decoded, dec_err = CrusaderStrikeGearEncoder.Decode(encoded)
    ok(decoded ~= nil, dec_err)
    eq(decoded.lists[1].role_spec, nil)

    local import_db = fresh_db()
    payload.role_spec = nil -- top-level N/A
    payload.lists[1].role_spec = ""
    payload.character_id = "char-null-role"
    local applied, aerr = CrusaderStrikeGearSets.ApplyImport(import_db, payload)
    ok(applied, aerr)
    eq(import_db.gearSets.lists[1].role_spec, nil)
    eq(import_db.gearSets.character_id, "char-null-role")
  end)
end)

describe("Forever item link field order (#29)", function()
  it("documents ITEM_LINK_FIELDS and ParseItemLink via GearEncoder", function()
    local F = CrusaderStrikeGearEncoder.ITEM_LINK_FIELDS
    eq(F.item_id, 1)
    eq(F.enchant_id, 2)
    eq(F.suffix_id, 7)
    local p = CrusaderStrikeGearEncoder.ParseItemLink(
      "|cffffffff|Hitem:14145:2564:0:0:0:0:123:0:0|h[Blade]|h|r"
    )
    eq(p.item_id, 14145)
    eq(p.enchant_id, 2564)
    -- EquippedGear delegates to GearEncoder
    local p2 = CrusaderStrikeEquippedGear.ParseItemLink(
      "|Hitem:19019:0:0:0:0:0:0:0:0|h[Thunderfury]|h"
    )
    eq(p2.item_id, 19019)
    eq(p2.enchant_id, 0)
  end)

  it("RejectMessage covers character_mismatch list_limit_reached item_not_forever", function()
    local GE = CrusaderStrikeGearEncoder
    local m1 = GE.RejectMessage("character_mismatch")
    ok(m1:find("different character", 1, true) ~= nil, m1)
    local m2 = GE.RejectMessage("list_limit_reached")
    ok(m2:find("20", 1, true) ~= nil, m2)
    local m3 = GE.RejectMessage("item_not_forever")
    ok(m3:find("Forever", 1, true) ~= nil, m3)
    ok(GE.RejectMessage("bad_checksum"):find("checksum", 1, true) ~= nil)
  end)
end)

describe("web-import CSGEAR1 fixture (#29)", function()
  local function read_fixture()
    local path = "tests/fixtures/web_import_csgear1.txt"
    -- resolve relative to addon root (runner cwd) or beside this file
    local f = io.open(path, "r")
    if not f then
      local src = debug.getinfo(1, "S").source
      local dir = src:match("^@(.*/)") or ""
      f = io.open(dir .. "../fixtures/web_import_csgear1.txt", "r")
    end
    assert(f, "missing tests/fixtures/web_import_csgear1.txt")
    local s = f:read("*a")
    f:close()
    return (s:gsub("%s+$", ""))
  end

  it("decodes web re-import string with local_id→id and no equipped", function()
    local env = read_fixture()
    ok(env:sub(1, 8) == "CSGEAR1:", env:sub(1, 20))
    local payload, err = CrusaderStrikeGearEncoder.Decode(env, {
      expect_realm = "CrusaderStrike",
      expect_character = "Snipy",
    })
    ok(payload ~= nil, err)
    eq(payload.character_id, "char_01JACKET9FOREVERSYNC0001")
    -- Import strings omit equipped (or empty)
    ok(payload.equipped == nil or next(payload.equipped) == nil
      or (type(payload.equipped) == "table"), "equipped present or omitted")
    -- Prefer: fixture encodes without equipped key; FromJson may omit it
    eq(payload.equipped, nil)
    eq(#payload.lists, 2)
    eq(payload.lists[1].local_id, "a3f09c12")
    eq(payload.lists[1].id, "9c2e4f6a-1b3d-4e5f-8a7b-6c5d4e3f2a10")
    eq(payload.lists[1].edited_in, "web")
    eq(payload.lists[2].id, "7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21")
    eq(payload.rejects[1].code, "item_not_forever")
    eq(payload.rejects[1].item_id, 19019)
  end)

  it("ApplyImport links local_id to server id from web fixture", function()
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    -- Local set created in game with same local_id, no server id yet
    local local_list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS 50",
      type = "leveling",
      until_level = 50,
    }, 25)
    -- Force the fixture local_id
    local_list.local_id = "a3f09c12"
    local_list.edited_at = "2026-11-05T07:00:00Z"
    local_list.slots.head = 1

    local env = read_fixture()
    local payload = CrusaderStrikeGearEncoder.Decode(env)
    ok(payload ~= nil)
    payload.equipped = nil
    local applied, aerr = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied, aerr)
    eq(db.gearSets.character_id, "char_01JACKET9FOREVERSYNC0001")
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, "a3f09c12")
    ok(merged ~= nil)
    eq(merged.id, "9c2e4f6a-1b3d-4e5f-8a7b-6c5d4e3f2a10")
    eq(merged.slots.head, 14145)
    -- Second list added from web
    local tank = CrusaderStrikeGearSets.FindById(db, "7b1e2c4a-0d1f-4e8a-9c3b-2a6f5e4d3c21")
    ok(tank ~= nil)
    eq(tank.local_id, "5e7d1b90")
  end)

  it("links id even when local edited_at is newer", function()
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    local local_list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS 50",
      type = "leveling",
      until_level = 50,
    }, 25)
    local_list.local_id = "a3f09c12"
    local_list.edited_at = "2026-11-05T09:00:00Z" -- newer than web fixture
    local_list.slots.head = 777
    local env = read_fixture()
    local payload = CrusaderStrikeGearEncoder.Decode(env)
    payload.equipped = nil
    -- Only first list for this case
    payload.lists = { payload.lists[1] }
    payload.rejects = nil
    local applied, aerr = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied, aerr)
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, "a3f09c12")
    eq(merged.id, "9c2e4f6a-1b3d-4e5f-8a7b-6c5d4e3f2a10")
    eq(merged.slots.head, 777) -- local wins content
  end)

  it("does not wipe existing server id when web sends id null", function()
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    local local_list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "KeepId",
      type = "max_level",
    }, 60)
    local_list.id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    local_list.edited_at = "2026-11-05T06:00:00Z"
    local payload = {
      lists = {
        {
          id = nil,
          local_id = local_list.local_id,
          name = "KeepId",
          type = "max_level",
          until_level = nil,
          edited_at = "2026-11-05T07:00:00Z",
          edited_in = "web",
          slots = { chest = 1 },
          removes = {},
        },
      },
      deleted_lists = {},
    }
    local applied = CrusaderStrikeGearSets.ApplyImport(db, payload)
    ok(applied)
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, local_list.local_id)
    eq(merged.id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    eq(merged.slots.chest, 1)
  end)
end)


describe("gear ops Option B (platform#46)", function()
  it("BuildSlotOps set_slot / clear_slot shapes match OpenAPI", function()
    CrusaderStrikeGearOps.SetMode("set_slot")
    local set_ops, err = CrusaderStrikeGearOps.BuildSlotOps({
      slot = "main_hand",
      item_id = 19019,
      base_version = 3,
      prior_item_ids = { 111 },
      op_id = "019a0000-0000-7000-8000-000000000101",
    })
    eq(err, nil)
    eq(#set_ops, 1)
    eq(set_ops[1].type, "set_slot")
    eq(set_ops[1].item_id, 19019)
    eq(set_ops[1].slot, "main_hand")
    eq(set_ops[1].base_version, 3)
    eq(set_ops[1].op_id, "019a0000-0000-7000-8000-000000000101")
    eq(set_ops[1].priority, nil)
    eq(set_ops[1].source, "addon")

    local clear_ops = CrusaderStrikeGearOps.BuildSlotOps({
      slot = "main_hand",
      item_id = nil,
      base_version = 4,
      prior_item_ids = { 19019 },
    })
    eq(#clear_ops, 1)
    eq(clear_ops[1].type, "clear_slot")
    eq(clear_ops[1].item_id, nil)
    ok(CrusaderStrikeGearOps.IsOpId(clear_ops[1].op_id))
  end)

  it("BuildSlotOps legacy fallback emits remove_item+add_item", function()
    local ops = CrusaderStrikeGearOps.BuildSlotOps({
      mode = "legacy",
      slot = "head",
      item_id = 16846,
      base_version = 1,
      prior_item_ids = { 123, 456 },
    })
    eq(#ops, 3)
    eq(ops[1].type, "remove_item")
    eq(ops[1].item_id, 123)
    eq(ops[2].type, "remove_item")
    eq(ops[2].item_id, 456)
    eq(ops[3].type, "add_item")
    eq(ops[3].item_id, 16846)
    eq(ops[3].priority, 1)
  end)

  it("DrainPendingOps clears queue and keeps op_id for dedupe", function()
    CrusaderStrikeGearOps.SetMode("set_slot")
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Drain", type = "max_level" }, 60)
    list.version = 7
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "wrist", 14148)
    local drained = CrusaderStrikeGearSets.DrainPendingOps(db, list.local_id)
    eq(#drained, 1)
    eq(drained[1].type, "set_slot")
    eq(drained[1].base_version, 7)
    ok(CrusaderStrikeGearOps.IsOpId(drained[1].op_id))
    local again = CrusaderStrikeGearSets.DrainPendingOps(db, list.local_id)
    eq(#again, 0)
  end)

  it("empty clear emits no op", function()
    local ops = CrusaderStrikeGearOps.BuildSlotOps({
      slot = "head",
      item_id = nil,
      base_version = 0,
      prior_item_ids = {},
    })
    eq(#ops, 0)
  end)
end)

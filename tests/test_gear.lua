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
    eq(saw_remove, false) -- primary path: clear_slot only, no remove_item companion
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#pending, 1)
    eq(pending[1].type, "clear_slot") -- set replaced by later clear for same slot
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


describe("gear ops set_slot/clear_slot (platform#46)", function()
  it("BuildSlotOps set_slot / clear_slot shapes match OpenAPI", function()
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
    eq(set_ops[1].source, nil) -- not on the wire (server ignored[])

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


  it("DrainPendingOps peeks without clearing so retries reuse op_id", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Drain", type = "max_level" }, 60)
    list.version = 7
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "wrist", 14148)
    local drained = CrusaderStrikeGearSets.DrainPendingOps(db, list.local_id)
    eq(#drained, 1)
    eq(drained[1].type, "set_slot")
    eq(drained[1].base_version, 7)
    ok(CrusaderStrikeGearOps.IsOpId(drained[1].op_id))
    eq(drained[1].source, nil)
    eq(drained[1].prior_item_id, nil) -- stripped on send
    local again = CrusaderStrikeGearSets.DrainPendingOps(db, list.local_id)
    eq(#again, 1)
    eq(again[1].op_id, drained[1].op_id) -- same op_id for dedupe
    CrusaderStrikeGearSets.AckPendingOps(db, list.local_id, { drained[1].op_id })
    local after = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#after, 0)
  end)

  it("tracks list.version so next op carries refreshed base_version", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Ver", type = "max_level" }, 60)
    eq(list.version, 0)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 111)
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(pending[1].base_version, 0)
    local op_id = pending[1].op_id
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 5,
      applied = { op_id },
      duplicates = {},
      conflicts = {},
      ignored = {},
      list = { id = "list-uuid-1", version = 5 },
    })
    eq(summary.version, 5)
    eq(list.version, 5)
    eq(list.id, "list-uuid-1")
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), 0)
    local _, ops = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "chest", 222)
    eq(ops[1].base_version, 5)
  end)

  it("applied no-op acks without requiring a version bump", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Noop", type = "max_level" }, 60)
    list.version = 3
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    local op_id = pending[1].op_id
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 3, -- no bump (no-op on server)
      applied = { op_id },
      duplicates = {},
      conflicts = {},
    })
    eq(summary.version, 3)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), 0)
    eq(list.slots.head, 12345)
  end)

  it("stale_base_version refreshes version and rebuilds with a new op_id", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Stale", type = "max_level" }, 60)
    list.version = 2
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "main_hand", 19019)
    local old_id = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)[1].op_id
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 9,
      applied = {},
      duplicates = {},
      conflicts = {
        { op_id = old_id, reason = "stale_base_version", winning_version = 9 },
      },
      ignored = {},
    })
    eq(list.version, 9)
    eq(#summary.rebuilt, 1)
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#pending, 1)
    eq(pending[1].type, "set_slot")
    eq(pending[1].item_id, 19019)
    eq(pending[1].base_version, 9)
    ok(pending[1].op_id ~= old_id)
    ok(CrusaderStrikeGearOps.IsOpId(pending[1].op_id))
    eq(list.slots.main_hand, 19019) -- local intent kept
  end)

  it("item_not_in_slot / list_items_limit revert slot and surface errors", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Hard", type = "max_level" }, 60)
    list.version = 4
    list.slots.head = 100
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 99999)
    eq(list.slots.head, 99999)
    local bad_id = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)[1].op_id

    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "chest", 16846)
    local lim_id = nil
    for _, op in ipairs(CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)) do
      if op.slot == "chest" then lim_id = op.op_id end
    end
    ok(lim_id ~= nil)

    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 4,
      applied = {},
      duplicates = {},
      rejected = { -- alias of conflicts
        { op_id = bad_id, reason = "item_not_in_slot", slot = "head", item_id = 99999 },
        { op_id = lim_id, reason = "list_items_limit", slot = "chest", item_id = 16846 },
      },
    })
    eq(#summary.errors, 2)
    eq(summary.errors[1].reason, "item_not_in_slot")
    ok(summary.errors[1].message ~= nil and #summary.errors[1].message > 0)
    eq(summary.errors[2].reason, "list_items_limit")
    eq(list.slots.head, 100) -- reverted to prior
    eq(list.slots.chest, nil) -- reverted (was empty)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), 0)
  end)

  it("ignored[] is returned for logging and source is not sent", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Ign", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "wrist", 14148)
    local op_id = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)[1].op_id
    local wire = CrusaderStrikeGearSets.DrainPendingOps(db, list.local_id)[1]
    eq(wire.source, nil)
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 1,
      applied = { op_id },
      duplicates = {},
      conflicts = {},
      ignored = { { op_id = op_id, keys = { "source" } } },
    })
    eq(#summary.ignored, 1)
    eq(summary.ignored[1].keys[1], "source")
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

describe("CSGEAR1 end-to-end round-trip (#41)", function()
  -- True path: CreateSet → BuildExportPayload → Encode → (web assigns id) →
  -- Encode → Decode → ApplyImport; local_id→id preserved.
  it("export → web id assign → re-import links local_id to server id", function()
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    local leveling = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS 40",
      type = "leveling",
      until_level = 40,
      role_spec = "fury",
    }, 25)
    ok(leveling ~= nil)
    local local_id = leveling.local_id
    CrusaderStrikeGearSets.SetSlot(db, local_id, "head", 14145)
    CrusaderStrikeGearSets.SetSlot(db, local_id, "main_hand", 19019)

    -- Under-60 creating a max_level set is allowed (Forever BiS while leveling).
    local bis = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Tank BiS",
      type = "max_level",
    }, 25)
    ok(bis ~= nil, "under-60 may create max_level")
    eq(bis.type, "max_level")
    eq(bis.until_level, nil)
    CrusaderStrikeGearSets.SetSlot(db, bis.local_id, "chest", 16966)

    local payload = CrusaderStrikeGearSets.BuildExportPayload(db, {
      realm = "CrusaderStrike",
      character = "Snipy",
      region = "us",
      equipped = { main_hand = { item_id = 14145, enchant_id = 0 } },
    })
    eq(payload.schema_version, 1)
    eq(payload.game_version, "forever")
    eq(#payload.lists, 2)
    eq(payload.lists[1].local_id, local_id)
    eq(payload.lists[1].id, nil)
    -- pending_ops / version must not ride the CSGEAR1 wire
    eq(payload.lists[1].pending_ops, nil)
    eq(payload.lists[1].version, nil)

    local exported, enc_err = CrusaderStrikeGearEncoder.Encode(payload)
    ok(exported ~= nil, enc_err)
    ok(exported:sub(1, 8) == "CSGEAR1:")

    -- Simulate website: decode, assign server ids + character_id, strip equipped, re-encode.
    local web_payload, derr = CrusaderStrikeGearEncoder.Decode(exported)
    ok(web_payload ~= nil, derr)
    web_payload.character_id = "char_01E2EROUNDTRIPTEST00000001"
    web_payload.equipped = nil
    web_payload.lists[1].id = "11111111-2222-4333-8444-555555555501"
    web_payload.lists[1].edited_in = "web"
    web_payload.lists[1].edited_at = "2026-11-05T12:00:00Z"
    web_payload.lists[1].version = 3
    web_payload.lists[2].id = "11111111-2222-4333-8444-555555555502"
    web_payload.lists[2].edited_in = "web"
    web_payload.lists[2].edited_at = "2026-11-05T12:00:00Z"
    -- Prefer web slot write for list 1 head (last-edited-wins)
    web_payload.lists[1].slots.head = 14148

    local reimported, rerr = CrusaderStrikeGearEncoder.Encode(web_payload)
    ok(reimported ~= nil, rerr)

    local round, r2 = CrusaderStrikeGearEncoder.Decode(reimported, {
      expect_realm = "CrusaderStrike",
      expect_character = "Snipy",
    })
    ok(round ~= nil, r2)
    eq(round.equipped, nil)
    round.equipped = nil
    local applied, aerr = CrusaderStrikeGearSets.ApplyImport(db, round)
    ok(applied, aerr)

    eq(db.gearSets.character_id, "char_01E2EROUNDTRIPTEST00000001")
    local merged = CrusaderStrikeGearSets.FindByLocalId(db, local_id)
    ok(merged ~= nil)
    eq(merged.id, "11111111-2222-4333-8444-555555555501")
    eq(merged.slots.head, 14148)
    eq(merged.version, 3)
    local merged_bis = CrusaderStrikeGearSets.FindByLocalId(db, bis.local_id)
    ok(merged_bis ~= nil)
    eq(merged_bis.id, "11111111-2222-4333-8444-555555555502")
    eq(merged_bis.type, "max_level")
  end)

  it("fixture path still round-trips decode → ApplyImport → re-export local_id", function()
    local path = "tests/fixtures/web_import_csgear1.txt"
    local f = io.open(path, "r")
    assert(f, "missing fixture")
    local env = (f:read("*a") or ""):gsub("%s+$", "")
    f:close()
    local payload = CrusaderStrikeGearEncoder.Decode(env)
    ok(payload ~= nil)
    local db = {
      gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} },
    }
    -- Seed local set matching fixture local_id so merge links id
    local seed = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Pre-BiS 50",
      type = "leveling",
      until_level = 50,
    }, 25)
    seed.local_id = "a3f09c12"
    seed.edited_at = "2026-11-05T06:00:00Z"
    payload.equipped = nil
    ok(CrusaderStrikeGearSets.ApplyImport(db, payload))
    local out = CrusaderStrikeGearSets.BuildExportPayload(db, {
      realm = "CrusaderStrike",
      character = "Snipy",
      equipped = {},
    })
    local enc = CrusaderStrikeGearEncoder.Encode(out)
    ok(enc ~= nil)
    local again = CrusaderStrikeGearEncoder.Decode(enc)
    ok(again ~= nil)
    local found = false
    for _, list in ipairs(again.lists) do
      if list.local_id == "a3f09c12" then
        found = true
        eq(list.id, "9c2e4f6a-1b3d-4e5f-8a7b-6c5d4e3f2a10")
      end
    end
    ok(found, "re-export must keep linked local_id→id")
  end)
end)

describe("until_level under-60 + Forever create defaults (#41)", function()
  it("CreateDefaults / AllowedSetTypes match Forever rules", function()
    local d25 = CrusaderStrikeGearSets.CreateDefaults(25)
    eq(d25.type, "leveling")
    eq(d25.until_level, 26)
    eq(d25.allow_leveling, true)
    local a25 = CrusaderStrikeGearSets.AllowedSetTypes(25)
    eq(#a25, 2)
    eq(a25[1], "leveling")
    eq(a25[2], "max_level")

    local d59 = CrusaderStrikeGearSets.CreateDefaults(59)
    eq(d59.until_level, 60)
    eq(d59.allow_leveling, true)

    local d60 = CrusaderStrikeGearSets.CreateDefaults(60)
    eq(d60.type, "max_level")
    eq(d60.until_level, nil)
    eq(d60.allow_leveling, false)
    local a60 = CrusaderStrikeGearSets.AllowedSetTypes(60)
    eq(#a60, 1)
    eq(a60[1], "max_level")
  end)

  it("under-60 may create max_level; leveling edges enforced", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local maxset, merr = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Early BiS",
      type = "max_level",
      until_level = 99, -- coerced away
    }, 30)
    ok(maxset ~= nil, merr)
    eq(maxset.type, "max_level")
    eq(maxset.until_level, nil)

    local ok_edge, list = true, CrusaderStrikeGearSets.CreateSet(db, {
      name = "UpTo60",
      type = "leveling",
      until_level = 60,
    }, 30)
    ok(list ~= nil)
    eq(list.until_level, 60)

    local _, err_eq = CrusaderStrikeGearSets.CreateSet(db, {
      name = "EqLevel",
      type = "leveling",
      until_level = 30,
    }, 30)
    eq(err_eq, "until_level_not_above_current_level")

    local _, err_hi = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Over60",
      type = "leveling",
      until_level = 61,
    }, 30)
    eq(err_hi, "until_level_out_of_range")

    local _, err_nil = CrusaderStrikeGearSets.CreateSet(db, {
      name = "NoUntil",
      type = "leveling",
    }, 30)
    eq(err_nil, "until_level_required")

    -- ValidateUntilLevel alone rejects max_level + until_level
    local okv, code = CrusaderStrikeGearSets.ValidateUntilLevel("max_level", 40, 30)
    eq(okv, false)
    eq(code, "until_level_must_be_null")
  end)

  it("RejectMessage covers until_level codes for UI", function()
    local GE = CrusaderStrikeGearEncoder
    ok(GE.RejectMessage("until_level_required"):find("Up to level", 1, true) ~= nil)
    ok(GE.RejectMessage("leveling_set_at_max_level"):find("60", 1, true) ~= nil)
    ok(GE.RejectMessage("until_level_must_be_null"):find("Max%-level", 1, true) ~= nil
      or GE.RejectMessage("until_level_must_be_null"):find("max%-level", 1, true) ~= nil
      or GE.RejectMessage("until_level_must_be_null"):find("Max-level", 1, true) ~= nil)
  end)
end)

describe("sync API/session error handling (#41)", function()
  it("FailSync keeps pending_ops and clears syncing with player message", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "SyncMe", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local before = #CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    ok(before >= 1)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    eq(list.syncing, true)

    local summary = CrusaderStrikeGearSets.FailSync(db, list.local_id, "session_expired")
    eq(summary.syncing, false)
    eq(list.syncing, false)
    eq(summary.pending_kept, before)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), before) -- not drained
    ok(summary.message:find("session", 1, true) ~= nil)
    eq(list.last_sync_error.code, "session_expired")
    eq(db.gearSets.last_sync_error.code, "session_expired")
  end)

  it("api_unavailable / token_expired / unauthorized have clear messages", function()
    local GE = CrusaderStrikeGearEncoder
    for _, code in ipairs({ "api_unavailable", "api_down", "network_error", "token_expired", "unauthorized", "unauthenticated" }) do
      local msg = GE.SyncErrorMessage(code)
      ok(type(msg) == "string" and #msg > 20, code)
      ok(not msg:find("Import rejected", 1, true), code .. " should not look like import")
    end
  end)

  it("ApplyOpsResult({error=...}) routes through FailSync without clearing pending", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Down", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "wrist", 14148)
    local n = #CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "api_unavailable" },
    })
    ok(summary ~= nil)
    eq(summary.code, "api_unavailable")
    eq(summary.pending_kept, n)
    eq(list.syncing, false)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)
    ok(summary.message:find("unreachable", 1, true) ~= nil
      or summary.message:find("API", 1, true) ~= nil)
  end)

  it("CompleteSync clears syncing and last error", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Done", type = "max_level" }, 60)
    CrusaderStrikeGearSets.FailSync(db, list.local_id, "network_error")
    ok(list.last_sync_error ~= nil)
    CrusaderStrikeGearSets.CompleteSync(db, list.local_id)
    eq(list.syncing, false)
    eq(list.last_sync_error, nil)
  end)
end)

describe("platform#51/#52 error envelopes (#45)", function()
  local GE = CrusaderStrikeGearEncoder

  it("ParseErrorEnvelope maps unauthenticated / session_expired / upstream_unavailable", function()
    local a = GE.ParseErrorEnvelope({ error = { code = "unauthenticated", message = "no session", retryable = false } })
    eq(a.code, "unauthenticated")
    eq(a.retryable, false)
    ok(a.message:find("Not signed in", 1, true) ~= nil)
    ok(not a.message:find("Import rejected", 1, true))

    local s = GE.ParseErrorEnvelope({
      error = { code = "session_expired", message = "expired", retryable = false },
    })
    eq(s.code, "session_expired")
    eq(s.retryable, false)
    ok(s.message:find("session", 1, true) ~= nil)

    local u = GE.ParseErrorEnvelope({
      error = { code = "upstream_unavailable", message = "blizzard down", retryable = true },
    }, { http_status = 503, headers = { ["Retry-After"] = "30" } })
    eq(u.code, "upstream_unavailable")
    eq(u.retryable, true)
    eq(u.retry_after, 30)
    ok(u.message:find("unavailable", 1, true) ~= nil)
    ok(u.message:find("30", 1, true) ~= nil)
  end)

  it("honors retryable=false on upstream_unavailable and Retry-After from meta", function()
    local u = GE.ParseErrorEnvelope({
      error = { code = "upstream_unavailable", retryable = false },
    }, { http_status = 502 })
    eq(u.retryable, false)
    ok(u.message:find("try again later", 1, true) ~= nil)

    local r = GE.ParseErrorEnvelope({ code = "upstream_unavailable", retryable = true }, { retry_after = 15 })
    eq(r.retry_after, 15)
    ok(r.message:find("15", 1, true) ~= nil)
  end)

  it("infers codes from HTTP status when envelope code missing", function()
    local a = GE.ParseErrorEnvelope({ error = { message = "missing cookie" } }, { http_status = 401 })
    eq(a.code, "unauthenticated")

    local s = GE.ParseErrorEnvelope({ error = { message = "token expired" } }, { http_status = 401 })
    eq(s.code, "session_expired")

    local u = GE.ParseErrorEnvelope({}, { http_status = 503, headers = { ["Retry-After"] = "5" } })
    eq(u.code, "upstream_unavailable")
    eq(u.retry_after, 5)
  end)

  it("backward-compat: string error, reason field, legacy aliases", function()
    local a = GE.ParseErrorEnvelope("api_unavailable")
    eq(a.code, "api_unavailable")
    ok(a.message:find("unreachable", 1, true) ~= nil)

    local b = GE.ParseErrorEnvelope({ reason = "network_error" })
    eq(b.code, "network_error")

    local c = GE.ParseErrorEnvelope({ code = "unauthorized" })
    eq(c.code, "unauthenticated")

    local d = GE.ParseErrorEnvelope({ code = "token_expired" })
    eq(d.code, "session_expired")

    -- Unknown sync code uses sync-specific fallback (not Import rejected)
    local e = GE.SyncErrorMessage("totally_unknown_xyz")
    ok(e:find("sync failed", 1, true) ~= nil)
    ok(not e:find("Import rejected", 1, true))
  end)

  it("ApplyOpsResult routes platform#51 envelope through FailSync (pending kept)", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Env", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local before_ops = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    local n = #before_ops
    local before_ids = {}
    for i, op in ipairs(before_ops) do before_ids[i] = op.op_id end
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)

    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "unauthenticated", message = "no session", retryable = false },
      http_status = 401,
    })
    eq(summary.code, "unauthenticated")
    eq(summary.retryable, false)
    eq(summary.pending_kept, n)
    eq(list.syncing, false)
    local after = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#after, n)
    for i, op in ipairs(after) do eq(op.op_id, before_ids[i]) end
    ok(summary.message:find("Not signed in", 1, true) ~= nil)
    eq(list.last_sync_error.retryable, false)

    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s2 = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "session_expired", retryable = false },
      status = 401,
    })
    eq(s2.code, "session_expired")
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)

    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s3 = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "upstream_unavailable", retryable = true },
      http_status = 503,
      headers = { ["Retry-After"] = "45" },
    })
    eq(s3.code, "upstream_unavailable")
    eq(s3.retryable, true)
    eq(s3.retry_after, 45)
    eq(list.last_sync_error.retry_after, 45)
    ok(s3.message:find("45", 1, true) ~= nil)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)
  end)

  it("ParseErrorEnvelope maps rate_limited / version_mismatch / internal_error + request_id", function()
    local rl = GE.ParseErrorEnvelope({
      error = {
        code = "rate_limited",
        message = "slow down",
        retryable = true,
        request_id = "req_rate_1",
      },
    }, { http_status = 429, headers = { ["Retry-After"] = "12" } })
    eq(rl.code, "rate_limited")
    eq(rl.retryable, true)
    eq(rl.retry_after, 12)
    eq(rl.request_id, "req_rate_1")
    ok(rl.message:find("rate limit", 1, true) ~= nil)
    ok(rl.message:find("12", 1, true) ~= nil)

    local vm = GE.ParseErrorEnvelope({
      error = {
        code = "version_mismatch",
        message = "stale",
        retryable = true,
        request_id = "req_ver_2",
      },
    }, { http_status = 409 })
    eq(vm.code, "version_mismatch")
    eq(vm.retryable, true)
    eq(vm.request_id, "req_ver_2")
    ok(vm.message:find("changed on the website", 1, true) ~= nil)

    local ie = GE.ParseErrorEnvelope({
      error = {
        code = "internal_error",
        message = "boom",
        retryable = true,
        request_id = "req_int_3",
      },
    }, { http_status = 500, retry_after = 8 })
    eq(ie.code, "internal_error")
    eq(ie.retryable, true)
    eq(ie.retry_after, 8)
    eq(ie.request_id, "req_int_3")
    ok(ie.message:find("unexpected error", 1, true) ~= nil)
    ok(ie.message:find("8", 1, true) ~= nil)

    -- request_id from meta when envelope omits it
    local m = GE.ParseErrorEnvelope(
      { error = { code = "unauthenticated", retryable = false } },
      { request_id = "req_meta_only" }
    )
    eq(m.request_id, "req_meta_only")
  end)

  it("infers rate_limited / internal_error from HTTP status", function()
    local rl = GE.ParseErrorEnvelope({}, { http_status = 429, headers = { ["Retry-After"] = "3" } })
    eq(rl.code, "rate_limited")
    eq(rl.retryable, true)
    eq(rl.retry_after, 3)

    local ie = GE.ParseErrorEnvelope({ error = { message = "oops" } }, { http_status = 500 })
    eq(ie.code, "internal_error")
    eq(ie.retryable, true)

    local vm = GE.ParseErrorEnvelope(
      { error = { message = "version conflict" } },
      { http_status = 409 }
    )
    eq(vm.code, "version_mismatch")
  end)

  it("ApplyOpsResult routes rate_limited / version_mismatch / internal_error (pending kept)", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Env52", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local n = #CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)

    local s1 = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = {
        code = "rate_limited",
        message = "slow",
        retryable = true,
        request_id = "req_apply_rl",
      },
      http_status = 429,
      headers = { ["Retry-After"] = "20" },
    })
    eq(s1.code, "rate_limited")
    eq(s1.retryable, true)
    eq(s1.retry_after, 20)
    eq(s1.request_id, "req_apply_rl")
    eq(list.last_sync_error.request_id, "req_apply_rl")
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)
    ok(s1.message:find("20", 1, true) ~= nil)

    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s2 = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "version_mismatch", retryable = true, request_id = "req_apply_vm" },
      status = 409,
    })
    eq(s2.code, "version_mismatch")
    eq(s2.request_id, "req_apply_vm")
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)

    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s3 = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      error = { code = "internal_error", retryable = true, request_id = "req_apply_ie" },
      http_status = 500,
    })
    eq(s3.code, "internal_error")
    eq(s3.retryable, true)
    eq(s3.request_id, "req_apply_ie")
    eq(list.last_sync_error.code, "internal_error")
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), n)
  end)

  it("FailSync string code still works (backward compat)", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Compat", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "wrist", 14148)
    local n = #CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    local summary = CrusaderStrikeGearSets.FailSync(db, list.local_id, "api_unavailable")
    eq(summary.code, "api_unavailable")
    eq(summary.pending_kept, n)
    eq(summary.retryable, true)
  end)

  it("ParseErrorEnvelope maps platform#54 field-map invalid_json (non-retryable)", function()
    local a = GE.ParseErrorEnvelope({ errors = { body = "invalid_json" } }, { http_status = 400 })
    eq(a.code, "invalid_json")
    eq(a.retryable, false)
    eq(a.request_id, nil)
    ok(a.message:find("invalid JSON", 1, true) ~= nil)
    ok(not a.message:find("will retry", 1, true))

    -- Bare field-map without meta status still maps
    local b = GE.ParseErrorEnvelope({ errors = { body = "invalid_json" } })
    eq(b.code, "invalid_json")
    eq(b.retryable, false)

    -- Other field reasons → validation_error (non-retryable)
    local c = GE.ParseErrorEnvelope({ errors = { name = "required" } }, { http_status = 400 })
    eq(c.code, "validation_error")
    eq(c.retryable, false)
    ok(c.message:find("validation", 1, true) ~= nil)

    -- Must not infer internal_error for 400 field-map
    local d = GE.ParseErrorEnvelope({ errors = { body = "invalid_json" } }, { http_status = 400 })
    ok(d.code ~= "internal_error")
    eq(d.retryable, false)

    -- Bare HTTP 400 (no body) → validation_error, not internal_error / api_unavailable
    local e = GE.ParseErrorEnvelope({}, { http_status = 400 })
    eq(e.code, "validation_error")
    eq(e.retryable, false)
  end)

  it("ApplyOpsResult / FailSync route 400 field-map through FailSync (pending kept, non-retryable)", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "InvJson", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 12345)
    local before_ops = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    local n = #before_ops
    local before_ids = {}
    for i, op in ipairs(before_ops) do before_ids[i] = op.op_id end
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)

    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      errors = { body = "invalid_json" },
      http_status = 400,
    })
    eq(summary.code, "invalid_json")
    eq(summary.retryable, false)
    eq(summary.pending_kept, n)
    eq(list.syncing, false)
    eq(list.last_sync_error.code, "invalid_json")
    eq(list.last_sync_error.retryable, false)
    local after = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    eq(#after, n)
    for i, op in ipairs(after) do eq(op.op_id, before_ids[i]) end
    ok(summary.message:find("invalid JSON", 1, true) ~= nil)

    -- FailSync with full body + meta (companion NotifySyncFailure path)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s2 = CrusaderStrikeGearSets.FailSync(db, list.local_id, {
      errors = { body = "invalid_json" },
    }, { http_status = 400 })
    eq(s2.code, "invalid_json")
    eq(s2.retryable, false)
    eq(s2.pending_kept, n)
    eq(list.syncing, false)
  end)

  it("keeps validation / conflict handling unchanged alongside envelopes", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Valid", type = "max_level" }, 60)
    list.id = "srv-1"
    list.version = 1
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 111)
    local pending = CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    ok(#pending >= 1)
    local op_id = pending[1].op_id
    local summary = CrusaderStrikeGearSets.ApplyOpsResult(db, list.local_id, {
      version = 2,
      applied = { op_id },
      conflicts = {},
      duplicates = {},
    })
    eq(summary.version, 2)
    eq(#summary.errors, 0)
    eq(#CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id), 0)
  end)
  -- #51: deferred envelope nits from #46
  it("ParseHttpDate handles IMF-fixdate, RFC 850 and asctime (UTC)", function()
    eq(GE.ParseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT"), 784111777)
    eq(GE.ParseHttpDate("Sunday, 06-Nov-94 08:49:37 GMT"), 784111777)
    eq(GE.ParseHttpDate("Sun Nov  6 08:49:37 1994"), 784111777)
    eq(GE.ParseHttpDate("Thu, 01 Jan 1970 00:00:00 GMT"), 0)
    eq(GE.ParseHttpDate("Thu, 29 Feb 2024 12:00:00 GMT"), 1709208000)
    eq(GE.ParseHttpDate("not a date"), nil)
    eq(GE.ParseHttpDate("Sun, 06 Foo 1994 08:49:37 GMT"), nil)
    eq(GE.ParseHttpDate(nil), nil)
  end)

  it("Retry-After HTTP-date becomes seconds from now (clamped at 0)", function()
    local now = 784111777
    eq(GE.ParseRetryAfter("Sun, 06 Nov 1994 08:50:07 GMT", now), 30)
    eq(GE.ParseRetryAfter("Sun, 06 Nov 1994 08:49:00 GMT", now), 0)
    eq(GE.ParseRetryAfter(" 12 ", now), 12)
    eq(GE.ParseRetryAfter("-5", now), nil)
    eq(GE.ParseRetryAfter("1.5", now), nil)
    eq(GE.ParseRetryAfter("garbage", now), nil)
    local rl = GE.ParseErrorEnvelope({}, {
      http_status = 429, now = now,
      headers = { ["Retry-After"] = "Sun, 06 Nov 1994 08:50:17 GMT" },
    })
    eq(rl.code, "rate_limited")
    eq(rl.retry_after, 40)
    ok(rl.message:find("40 seconds", 1, true))
    -- Real clock round-trip (os.date UTC → HTTP-date → delta).
    local t0 = os.time()
    local future = GE.ParseRetryAfter(os.date("!%a, %d %b %Y %H:%M:%S GMT", t0 + 120), t0)
    eq(future, 120)
  end)

  it("Retry-After header lookup is case-insensitive for any casing", function()
    for _, k in ipairs({ "Retry-After", "retry-after", "RETRY-AFTER", "Retry-after", "rEtRy-AfTeR", " retry-after " }) do
      local p = GE.ParseErrorEnvelope({}, { http_status = 503, headers = { [k] = "7" } })
      eq(p.retry_after, 7)
    end
    local m = GE.ParseErrorEnvelope({}, { http_status = 503, headers = { ["retry-AFTER"] = { "9" } } })
    eq(m.retry_after, 9)
    local b = GE.ParseErrorEnvelope({ headers = { ["Retry-after"] = "4" } }, { http_status = 429 })
    eq(b.retry_after, 4)
    local none = GE.ParseErrorEnvelope({}, { http_status = 503, headers = { ["X-Retry-After"] = "9" } })
    eq(none.retry_after, nil)
  end)

  it("ParseErrorEnvelope validation_error envelope is non-retryable", function()
    local v = GE.ParseErrorEnvelope({ error = { code = "validation_error", message = "bad slot" } }, { http_status = 400 })
    eq(v.code, "validation_error")
    eq(v.retryable, false)
    eq(v.message, GE.SyncErrorMessage("validation_error"))
    eq(v.limit, nil)
    local f = GE.ParseErrorEnvelope({ errors = { name = "too_long" } }, { http_status = 422 })
    eq(f.code, "validation_error")
    eq(f.retryable, false)
  end)

  it("ParseErrorEnvelope list_limit_reached with and without details.limit", function()
    local a = GE.ParseErrorEnvelope({ error = { code = "list_limit_reached", details = { limit = 25 } } }, { http_status = 409 })
    eq(a.code, "list_limit_reached")
    eq(a.retryable, false)
    eq(a.limit, 25)
    ok(a.message:find("25 gear sets", 1, true))
    local b = GE.ParseErrorEnvelope({ error = { code = "list_limit_reached" } }, { http_status = 409 })
    eq(b.limit, nil)
    eq(b.message, GE.SyncErrorMessage("list_limit_reached"))
    local c = GE.ParseErrorEnvelope({ error = { code = "list_limit_reached", details = { limit = "x" } } })
    eq(c.limit, nil)
  end)

  it("FailSync surfaces validation_error / list_limit_reached (pending kept)", function()
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local list = CrusaderStrikeGearSets.CreateSet(db, { name = "Lim", type = "max_level" }, 60)
    CrusaderStrikeGearSets.SetSlot(db, list.local_id, "head", 111)
    local n = #CrusaderStrikeGearSets.PeekPendingOps(db, list.local_id)
    ok(n >= 1)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s1 = CrusaderStrikeGearSets.FailSync(db, list.local_id,
      { error = { code = "list_limit_reached", details = { limit = 20 } } }, { http_status = 409 })
    eq(s1.code, "list_limit_reached")
    eq(s1.limit, 20)
    eq(s1.retryable, false)
    eq(s1.pending_kept, n)
    eq(list.syncing, false)
    eq(list.last_sync_error.limit, 20)
    CrusaderStrikeGearSets.BeginSync(db, list.local_id)
    local s2 = CrusaderStrikeGearSets.FailSync(db, list.local_id,
      { error = { code = "validation_error" } }, { http_status = 400 })
    eq(s2.code, "validation_error")
    eq(s2.retryable, false)
    eq(s2.pending_kept, n)
    eq(list.syncing, false)
  end)
end)

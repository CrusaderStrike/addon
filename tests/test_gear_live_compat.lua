-- addon#57: CSGEAR1 compatibility with the live /api/v1/gear-lists format + clear import errors.
local GE = CrusaderStrikeGearEncoder
local GS = CrusaderStrikeGearSets
local CS = CrusaderStrike

local function read_fixture(name)
  local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
  local f = io.open(dir .. "fixtures/" .. name, "r") or io.open("tests/fixtures/" .. name, "r")
  assert(f, "missing tests/fixtures/" .. name)
  local s = f:read("*a")
  f:close()
  return (s:gsub("%s+$", ""))
end

-- Run fn as Snipy-nightslayer with a fresh char DB, capturing chat lines.
local function as_snipy(fn)
  local saved = {
    realm = GetNormalizedRealmName, rn = GetRealmName, unit = UnitName,
    add = DEFAULT_CHAT_FRAME.AddMessage, db = CrusaderStrikeCharDB, gii = GetItemInfoInstant,
  }
  local lines = {}
  _G.GetNormalizedRealmName = function() return "nightslayer" end
  _G.GetRealmName = function() return "nightslayer" end
  _G.UnitName = function(u) if u == "player" then return "Snipy" end end
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) lines[#lines + 1] = m end
  _G.CrusaderStrikeCharDB = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
  local okc, err = pcall(fn, lines)
  _G.GetNormalizedRealmName, _G.GetRealmName, _G.UnitName = saved.realm, saved.rn, saved.unit
  DEFAULT_CHAT_FRAME.AddMessage = saved.add
  _G.CrusaderStrikeCharDB = saved.db
  _G.GetItemInfoInstant = saved.gii
  ok(okc, "no Lua error: " .. tostring(err))
end

local function snapshot(db)
  return GE.Encode(GS.BuildExportPayload(db, {
    realm = "nightslayer", character = "Snipy", exported_at = "2026-11-05T09:30:00Z", omit_equipped = true,
  }))
end

describe("CSGEAR1 live gear-lists compatibility (addon#57)", function()
  it("live /api/v1/gear-lists fixture imports and re-exports byte for byte", function()
    local fixture = read_fixture("csgear1_live_gear_lists.txt")
    local payload, err = GE.Decode(fixture, { expect_realm = "nightslayer", expect_character = "Snipy" })
    ok(payload ~= nil, "decode: " .. tostring(err))
    eq(#payload.lists, 2)
    eq(payload.lists[1].id, "3f2a9c4e-1b7d-4e2f-9a6c-5d8e7f0a1b21")
    eq(payload.lists[2].until_level, nil)
    local db = { gearSets = { character_id = nil, region = "us", lists = {}, deleted = {} } }
    local okapply, aerr = GS.ApplyImport(db, payload)
    ok(okapply, tostring(aerr))
    eq(db.gearSets.character_id, "char_01JLIVEGEARLISTS0000000001")
    local out = GE.Encode(GS.BuildExportPayload(db, {
      realm = payload.realm, character = payload.character,
      exported_at = payload.exported_at, omit_equipped = true,
    }))
    eq(out, fixture, "re-export must match fixture byte for byte")
  end)

  it("/cs import of the live fixture via slash command saves both sets", function()
    as_snipy(function(lines)
      SlashCmdList["CRUSADERSTRIKE"]("import " .. read_fixture("csgear1_live_gear_lists.txt"))
      eq(#CrusaderStrikeCharDB.gearSets.lists, 2)
      ok(lines[#lines]:find("Imported gear sets (2 lists)", 1, true) ~= nil, lines[#lines])
      eq(snapshot(CrusaderStrikeCharDB), read_fixture("csgear1_live_gear_lists.txt"))
    end)
  end)
end)

describe("/cs import clear one-line errors, nothing saved (addon#57)", function()
  local fixture = read_fixture("csgear1_live_gear_lists.txt")
  local b64, hex = fixture:match("^CSGEAR1:(.-)|c=(%x+)$")

  local function rebuild(mutate)
    local json = CrusaderStrikeEncoder.Base64Decode(b64)
    json = mutate(json)
    return "CSGEAR1:" .. CrusaderStrikeEncoder.Base64Encode(json) .. "|c=" .. GE.ChecksumHex(json)
  end

  local cases = {
    { "truncated (cut mid-string)", fixture:sub(1, 120), "truncated", "incomplete or truncated" },
    { "truncated (checksum cut)", fixture:sub(1, #fixture - 3), "truncated", "incomplete or truncated" },
    { "bad string", "CSGEAR1:@@@not-base64@@@|c=deadbeef", "truncated", "Import failed" },
    { "checksum mismatch", "CSGEAR1:" .. b64 .. "|c=00000000", "bad_checksum", "checksum failed" },
    { "wrong version prefix", "CSGEAR2:" .. b64 .. "|c=" .. hex, "wrong_version", "CSGEAR2" },
    { "not CSGEAR at all", "CSRUN1:abc|c=12345678", "bad_prefix", "wrong prefix" },
    { "garbage", "hello world", "bad_prefix", "wrong prefix" },
    { "item id not an integer", rebuild(function(j) return (j:gsub('"head":10328', '"head":10328.5')) end), "unknown_item", "head=10328.5" },
    { "item id zero", rebuild(function(j) return (j:gsub('"wrist":14148', '"wrist":0')) end), "unknown_item", "Leveling 50: wrist=0" },
  }

  for _, c in ipairs(cases) do
    it(c[1] .. " → " .. c[3], function()
      as_snipy(function(lines)
        local okimp, code = CS.ImportGearString(c[2])
        eq(okimp, false)
        eq(code, c[3])
        eq(#lines, 1, "exactly one chat line")
        local line = lines[1] or ""
        ok(line:find("Import failed: ", 1, true) ~= nil, line)
        ok(line:find(c[4], 1, true) ~= nil, "mentions " .. c[4] .. ": " .. line)
        ok(not line:find("\n", 1, true), "single line")
        eq(#CrusaderStrikeCharDB.gearSets.lists, 0, "no partial sets saved")
      end)
    end)
  end

  it("unknown item ID per client item DB rejects whole import", function()
    as_snipy(function(lines)
      _G.GetItemInfoInstant = function(id) if id == 16966 then return nil end return id end
      local okimp, code = CS.ImportGearString(fixture)
      eq(okimp, false)
      eq(code, "unknown_item")
      eq(#lines, 1)
      ok((lines[1] or ""):find("Tank BiS: chest=16966", 1, true) ~= nil, lines[1])
      eq(#CrusaderStrikeCharDB.gearSets.lists, 0, "first (valid) set not saved either")
    end)
  end)

  it("failed import leaves existing sets untouched", function()
    as_snipy(function(lines)
      ok(CS.ImportGearString(fixture))
      local before = snapshot(CrusaderStrikeCharDB)
      _G.GetItemInfoInstant = function() return nil end
      eq(CS.ImportGearString(fixture), false)
      eq(snapshot(CrusaderStrikeCharDB), before)
    end)
  end)

  it("character mismatch is one line and saves nothing", function()
    local saved = UnitName
    as_snipy(function(lines)
      _G.UnitName = function() return "Other" end
      local okimp, code = CS.ImportGearString(fixture)
      eq(okimp, false)
      eq(code, "character_mismatch")
      eq(#lines, 1)
      eq(#CrusaderStrikeCharDB.gearSets.lists, 0)
    end)
    _G.UnitName = saved
  end)

  it("ImportErrorLine collapses newlines", function()
    eq(GE.ImportErrorLine("truncated", "a\nb"):find("\n"), nil)
    eq(GE.ImportErrorLine(nil), "Import failed: Import rejected.")
  end)
end)

describe("/cs gearsets check (addon#57)", function()
  it("prints addon version, CSGEAR version, saved set count", function()
    as_snipy(function(lines)
      SlashCmdList["CRUSADERSTRIKE"]("gearsets check")
      eq(lines[1], "|cffd4a017CrusaderStrike|r: addon v" .. CS.VERSION .. " | CSGEAR1 | saved gear sets: 0")
      CS.ImportGearString(read_fixture("csgear1_live_gear_lists.txt"))
      eq(CS.GearSetsCheckLine(), "addon v" .. CS.VERSION .. " | CSGEAR1 | saved gear sets: 2")
    end)
  end)
end)

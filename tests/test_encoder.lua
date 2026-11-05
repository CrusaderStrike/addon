describe("encoder", function()
  it("base64 round-trips", function()
    local s = '{"a":1,"b":"x"}'
    local enc = CrusaderStrikeEncoder.Base64Encode(s)
    local dec = CrusaderStrikeEncoder.Base64Decode(enc)
    eq(dec, s)
  end)

  it("json round-trips nested run-like table", function()
    local t = {
      schemaVersion = 1,
      gameVersion = "forever",
      completed = true,
      bosses = { { npcId = 639, name = "Edwin VanCleef", killedAt = 9 } },
      party = { { name = "A", realm = "R", class = "WARRIOR", level = 20, isPlayer = true } },
    }
    local json = CrusaderStrikeEncoder.ToJson(t)
    local back = CrusaderStrikeEncoder.FromJson(json)
    eq(back.schemaVersion, 1)
    eq(back.gameVersion, "forever")
    eq(back.completed, true)
    eq(back.bosses[1].npcId, 639)
    eq(back.party[1].name, "A")
  end)

  it("export string uses CSRUN1 prefix", function()
    local run = {
      schemaVersion = 1,
      gameVersion = "forever",
      idempotencyKey = "R|C|1|36",
      addonRunId = "R|C|1|36",
      completed = false,
      party = {},
      bosses = {},
      deaths = {},
    }
    local s = CrusaderStrikeEncoder.EncodeRun(run)
    ok(s:sub(1, 7) == "CSRUN1:", "prefix")
    local back = CrusaderStrikeEncoder.DecodeExport(s)
    eq(back.idempotencyKey, "R|C|1|36")
    eq(back.gameVersion, "forever")
  end)
end)

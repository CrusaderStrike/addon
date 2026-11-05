local P = CrusaderStrikePvp
local ID = { realm = "Ironhollow", character = "Aldric" }

local function ctx(t, extra)
  local c = { now = t or 1730000000, inInstance = false, pvpZoneType = "contested",
    zone = "Hillsbrad Foothills", subzone = "Southshore" }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

local function kill(extra)
  local ev = { result = "kill", honorable = true, opponentName = "Grukk", opponentClass = "WARRIOR",
    opponentLevel = 58, opponentFaction = "Horde", opponentIsPlayer = true }
  for k, v in pairs(extra or {}) do ev[k] = v end
  return ev
end

describe("pvp world capture", function()
  it("records an honorable kill with all fields", function()
    local pvp = P.Ensure({})
    local r = P.RecordWorld(pvp, ID, kill(), ctx())
    ok(r ~= nil, "recorded")
    eq(#pvp.world, 1)
    eq(r.result, "kill")
    eq(r.honorable, true)
    eq(r.opponent.name, "Grukk")
    eq(r.opponent.class, "WARRIOR")
    eq(r.opponent.level, 58)
    eq(r.opponent.faction, "Horde")
    eq(r.zone, "Hillsbrad Foothills")
    eq(r.subzone, "Southshore")
    eq(r.time, 1730000000)
    eq(r.synced, false)
    eq(r.addon_pvp_id, "Ironhollow|Aldric|W|1730000000|kill|Grukk|1")
  end)

  it("records a death", function()
    local pvp = P.Ensure({})
    local r = P.RecordWorld(pvp, ID, kill({ result = "death", honorable = false }), ctx())
    eq(r.result, "death")
    eq(r.honorable, false)
  end)

  it("ids are unique for same-second events", function()
    local pvp = P.Ensure({})
    local a = P.RecordWorld(pvp, ID, kill(), ctx())
    local b = P.RecordWorld(pvp, ID, kill(), ctx())
    ok(a.addon_pvp_id ~= b.addon_pvp_id, "distinct ids")
  end)

  it("ignores duels (active and just finished)", function()
    local pvp = P.Ensure({})
    local r1, why1 = P.RecordWorld(pvp, ID, kill({ result = "death" }), ctx(100, { inDuel = true }))
    local r2, why2 = P.RecordWorld(pvp, ID, kill(), ctx(102, { duelEndedAt = 100 }))
    eq(r1, nil); eq(why1, "duel")
    eq(r2, nil); eq(why2, "duel")
    eq(#pvp.world, 0)
  end)

  it("ignores sanctuary, instances and pets", function()
    local pvp = P.Ensure({})
    local _, a = P.RecordWorld(pvp, ID, kill(), ctx(1, { pvpZoneType = "sanctuary" }))
    local _, b = P.RecordWorld(pvp, ID, kill(), ctx(1, { inInstance = true }))
    local _, c = P.RecordWorld(pvp, ID, kill({ opponentIsPet = true }), ctx())
    local _, d = P.RecordWorld(pvp, ID, kill({ killerIsPet = true }), ctx())
    local _, e = P.RecordWorld(pvp, ID, kill({ opponentIsPlayer = false }), ctx())
    eq(a, "sanctuary"); eq(b, "instance"); eq(c, "pet"); eq(d, "pet"); eq(e, "not_player")
    eq(#pvp.world, 0)
  end)

  it("caps world events, dropping oldest first", function()
    local pvp = P.Ensure({})
    for i = 1, P.WORLD_CAP + 5 do
      P.RecordWorld(pvp, ID, kill(), ctx(1000 + i))
    end
    eq(#pvp.world, P.WORLD_CAP)
    eq(pvp.world[1].time, 1006)
  end)

  it("marks records synced", function()
    local pvp = P.Ensure({})
    local r = P.RecordWorld(pvp, ID, kill(), ctx())
    eq(P.MarkSynced(pvp, { r.addon_pvp_id }), 1)
    eq(pvp.world[1].synced, true)
    eq(P.MarkSynced(pvp, { r.addon_pvp_id }), 0)
  end)
end)

describe("pvp battlegrounds", function()
  local function start(pvp, t)
    return P.StartBattleground(pvp, ID, { mapId = 489, mapName = "Warsong Gulch", faction = "Alliance", now = t or 5000 })
  end

  it("records a BG win with scoreboard row", function()
    local pvp = P.Ensure({})
    local bg = start(pvp)
    eq(bg.addon_pvp_id, "Ironhollow|Aldric|BG|5000|489")
    P.UpdateScore(pvp, { killingBlows = 4, honorableKills = 12, deaths = 2, honorGained = 310 })
    local r = P.FinishBattleground(pvp, 1, 6200)
    eq(r.result, "win")
    eq(r.durationSec, 1200)
    eq(r.startedAt, 5000); eq(r.endedAt, 6200)
    eq(r.faction, "Alliance"); eq(r.mapName, "Warsong Gulch")
    eq(r.stats.killingBlows, 4); eq(r.stats.honorableKills, 12)
    eq(r.stats.deaths, 2); eq(r.stats.honor, 310)
    eq(#pvp.battlegrounds, 1)
    eq(pvp.activeBattleground, nil)
  end)

  it("records a loss and a draw", function()
    local pvp = P.Ensure({})
    start(pvp); eq(P.FinishBattleground(pvp, 0, 6000).result, "loss")
    start(pvp, 7000); eq(P.FinishBattleground(pvp, 255, 8000).result, "draw")
  end)

  it("records leaving early as left with partial stats", function()
    local pvp = P.Ensure({})
    start(pvp)
    P.UpdateScore(pvp, { killingBlows = 1, honorableKills = 3, deaths = 1, honorGained = 40 })
    local r = P.LeaveBattleground(pvp, 5300)
    eq(r.result, "left")
    eq(r.stats.honorableKills, 3)
    eq(r.durationSec, 300)
  end)

  it("leave with no active match or no score is safe", function()
    local pvp = P.Ensure({})
    eq(P.LeaveBattleground(pvp, 1), nil)
    eq(P.UpdateScore(pvp, nil), false)
    start(pvp)
    eq(P.UpdateScore(pvp, nil), false)
    eq(P.LeaveBattleground(pvp, nil).result, "left")
  end)

  it("resumes the same match after /reload", function()
    local pvp = P.Ensure({})
    local a = start(pvp, 5000)
    local b = start(pvp, 5100)
    eq(a.addon_pvp_id, b.addon_pvp_id)
    eq(#pvp.battlegrounds, 0)
  end)

  it("caps battlegrounds", function()
    local pvp = P.Ensure({})
    for i = 1, P.BG_CAP + 2 do
      start(pvp, i * 10); P.FinishBattleground(pvp, 1, i * 10 + 5)
    end
    eq(#pvp.battlegrounds, P.BG_CAP)
    eq(pvp.battlegrounds[1].startedAt, 30)
  end)

  it("summary counts", function()
    local pvp = P.Ensure({})
    P.RecordWorld(pvp, ID, kill(), ctx())
    P.RecordWorld(pvp, ID, kill({ result = "death" }), ctx())
    start(pvp); P.FinishBattleground(pvp, 1, 6000)
    start(pvp, 7000); P.LeaveBattleground(pvp, 7100)
    local s = P.Summary(pvp)
    eq(s.kills, 1); eq(s.deaths, 1); eq(s.wins, 1); eq(s.losses, 0); eq(s.left, 1)
    local lines = P.FormatSummary(pvp)
    ok(lines[1]:find("1 kills", 1, true) ~= nil, "summary line")
    ok(lines[2]:find("1 W / 0 L", 1, true) ~= nil, "bg line")
  end)
end)

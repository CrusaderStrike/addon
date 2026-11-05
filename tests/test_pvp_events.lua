-- Event-level tests: PvpLog.lua driven by mocked WoW events (Forever API surface).
local root = package.path:match("([^;]*)/Logic/%?.lua") or "."
-- CombatLogGetCurrentEventInfo stays as the erroring mock from mock_wow.lua
dofile(root .. "/Core.lua")
dofile(root .. "/PvpLog.lua")
local CS = CrusaderStrike
local PL = CS.PvpLog

local T = 1730000000
local units, inst, zoneType, winner, scoreRow
local function reset()
  CrusaderStrikeDB = { settings = {} }
  CrusaderStrikeCharDB = { runs = {} }
  PL._state.inDuel, PL._state.duelEndedAt = false, nil
  units = { player = { name = "Aldric", class = "PALADIN", level = 60, faction = "Alliance", player = true, guid = "Player-1-0001" } }
  inst = { false, nil }
  zoneType, winner, scoreRow = "contested", nil, nil
end

_G.GetServerTime = function() return T end
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitName = function(u) return units[u] and units[u].name, units[u] and units[u].realm end
_G.UnitClass = function(u) return "x", units[u] and units[u].class end
_G.UnitLevel = function(u) return units[u] and units[u].level end
_G.UnitFactionGroup = function(u) return units[u] and units[u].faction end
_G.UnitIsPlayer = function(u) return units[u] ~= nil and units[u].player == true end
_G.UnitIsEnemy = function(a, b) return units[b] and units[b].faction ~= "Alliance" end
_G.UnitGUID = function(u) return units[u] and units[u].guid end
_G.IsInInstance = function() return inst[1], inst[2] end
_G.GetInstanceInfo = function() return "Warsong Gulch", "pvp", 0, "", 20, 0, false, 489 end
_G.GetRealZoneText = function() return "Hillsbrad Foothills" end
_G.GetSubZoneText = function() return "Tarren Mill" end
_G.C_PvP = {
  GetZonePVPInfo = function() return zoneType end,
  GetScoreInfoByPlayerGuid = function() return scoreRow end,
}
_G.GetBattlefieldWinner = function() return winner end
_G.GetBattlefieldInstanceRunTime = function() return 0 end
_G.IsActiveBattlefieldArena = function() return false end

local function db() return CrusaderStrikeCharDB.pvp end

describe("pvp events (mocked Forever client)", function()
  it("honorable kill from PLAYER_PVP_KILLS_CHANGED", function()
    reset()
    units.target = { name = "Grukk", class = "WARRIOR", level = 59, faction = "Horde", player = true, guid = "Player-2-0002" }
    PL.HandleEvent("PLAYER_PVP_KILLS_CHANGED", "target")
    eq(#db().world, 1)
    local r = db().world[1]
    eq(r.result, "kill"); eq(r.honorable, true); eq(r.opponent.name, "Grukk")
    eq(r.opponent.faction, "horde"); eq(r.subzone, "Tarren Mill")
  end)

  it("death to an enemy player", function()
    reset()
    units.target = { name = "Grukk", class = "WARRIOR", level = 60, faction = "Horde", player = true }
    PL.HandleEvent("PLAYER_DEAD")
    eq(db().world[1].result, "death")
    eq(db().world[1].opponent.name, "Grukk")
    eq(db().world[1].killer_source, "target")
  end)

  it("PvE death is not recorded", function()
    reset()
    PL.HandleEvent("PLAYER_DEAD")
    eq(#(CrusaderStrikeCharDB.pvp and db().world or {}), 0)
  end)

  it("duel is ignored", function()
    reset()
    units.target = { name = "Bob", class = "MAGE", level = 60, faction = "Horde", player = true }
    PL.HandleEvent("DUEL_REQUESTED", "Bob")
    PL.HandleEvent("PLAYER_PVP_KILLS_CHANGED", "target")
    PL.HandleEvent("DUEL_FINISHED")
    PL.HandleEvent("PLAYER_DEAD")
    eq(#db().world, 0)
  end)

  it("sanctuary is ignored", function()
    reset(); zoneType = "sanctuary"
    units.target = { name = "Grukk", class = "WARRIOR", level = 60, faction = "Horde", player = true }
    PL.HandleEvent("PLAYER_PVP_KILLS_CHANGED", "target")
    eq(#db().world, 0)
  end)

  it("BG win via scoreboard", function()
    reset()
    inst = { true, "pvp" }
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    ok(db().activeBattleground ~= nil, "bg started")
    scoreRow = { killingBlows = 3, honorableKills = 9, deaths = 1, honorGained = 200 }
    PL.HandleEvent("UPDATE_BATTLEFIELD_SCORE")
    eq(#db().battlegrounds, 0)
    winner = 1
    T = T + 900
    PL.HandleEvent("PVP_MATCH_COMPLETE", 1, 900)
    local r = db().battlegrounds[1]
    eq(r.result, "win"); eq(r.mapId, 489); eq(r.faction, "alliance")
    eq(r.durationSec, 900); eq(r.stats.honor, 200)
  end)

  it("one match produces exactly one record (post-end refresh, /reload, exit)", function()
    reset()
    inst = { true, "pvp" }
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    scoreRow = { killingBlows = 2, honorableKills = 5, deaths = 1, honorGained = 120 }
    winner = 0
    PL.HandleEvent("PVP_MATCH_COMPLETE", 0, 600)
    eq(#db().battlegrounds, 1)
    local id = db().battlegrounds[1].addon_pvp_id
    -- scoreboard stays up: more score/status/zone events while still inside
    PL.HandleEvent("UPDATE_BATTLEFIELD_SCORE")
    PL.HandleEvent("UPDATE_BATTLEFIELD_STATUS", 1)
    PL.HandleEvent("ZONE_CHANGED_NEW_AREA")
    PL.HandleEvent("UPDATE_BATTLEFIELD_SCORE")
    -- /reload after the end: SavedVariables keep the finished marker
    local saved = CrusaderStrikeCharDB
    CrusaderStrikeCharDB = saved
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    PL.HandleEvent("UPDATE_BATTLEFIELD_SCORE")
    eq(db().activeBattleground, nil)
    -- leave the instance
    inst = { false, nil }
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    eq(#db().battlegrounds, 1)
    eq(db().battlegrounds[1].addon_pvp_id, id)
    eq(db().battlegrounds[1].result, "loss")
    eq(db().finishedBattleground, nil)
  end)

  it("never registers CLEU and never calls CombatLogGetCurrentEventInfo", function()
    eq(PL._frame._events.COMBAT_LOG_EVENT_UNFILTERED, nil)
    ok(PL._frame._events.PLAYER_PVP_KILLS_CHANGED, "HK event registered")
    ok(PL._frame._events.PLAYER_DEAD, "PLAYER_DEAD registered")
    eq(_G._CS_CombatLogCallCount or 0, 0)
    eq(_G._CS_CleuRegisterAttempts or 0, 0)
  end)

  it("death killer_source is target never combat_log", function()
    reset()
    units.target = { name = "Grukk", class = "WARRIOR", level = 59, faction = "Horde", player = true, guid = "Player-2-0002" }
    PL.HandleEvent("PLAYER_DEAD")
    eq(#db().world, 1)
    eq(db().world[1].result, "death")
    eq(db().world[1].killer_source, "target")
  end)

  it("BG left early (or disconnect then relog outside) is left with partial stats", function()
    reset()
    inst = { true, "pvp" }
    PL.HandleEvent("UPDATE_BATTLEFIELD_STATUS", 1)
    scoreRow = { killingBlows = 1, honorableKills = 2, deaths = 0, honorGained = 15 }
    PL.HandleEvent("UPDATE_BATTLEFIELD_SCORE")
    inst = { false, nil }
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    local r = db().battlegrounds[1]
    eq(r.result, "left"); eq(r.stats.honorableKills, 2)
    eq(db().activeBattleground, nil)
  end)

  it("handler errors never escape", function()
    reset()
    local saved = _G.IsInInstance
    _G.IsInInstance = function() error("boom") end
    PL.HandleEvent("PLAYER_ENTERING_WORLD")
    _G.IsInInstance = saved
    ok(true, "no crash")
  end)

  it("/cs pvp prints a summary", function()
    reset()
    local out = {}
    local saved = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(_, m) out[#out + 1] = m end
    SlashCmdList["CRUSADERSTRIKE"]("pvp")
    DEFAULT_CHAT_FRAME.AddMessage = saved
    ok(#out >= 2, "summary lines")
    ok(out[1]:find("World PvP", 1, true) ~= nil, "world line")
  end)
end)

describe("detection helpers", function()
  it("treats success=1 as kill and success=0 as wipe", function()
    ok(CrusaderStrikeDetection.EncounterSucceeded(1))
    ok(CrusaderStrikeDetection.EncounterSucceeded(true))
    ok(not CrusaderStrikeDetection.EncounterSucceeded(0))
    ok(not CrusaderStrikeDetection.EncounterSucceeded(nil))
    ok(not CrusaderStrikeDetection.EncounterSucceeded(false))
  end)

  it("pcall-guards CombatLogGetCurrentEventInfo when it errors", function()
    local old = _G.CombatLogGetCurrentEventInfo
    _G.CombatLogGetCurrentEventInfo = function()
      error("protected", 0)
    end
    local okRead, info, detail = CrusaderStrikeDetection.TryReadCombatLog()
    eq(okRead, false)
    eq(info, nil)
    ok(type(detail) == "string" and detail:match("^error:"))
    _G.CombatLogGetCurrentEventInfo = old
  end)

  it("reports missing CombatLogGetCurrentEventInfo", function()
    local old = _G.CombatLogGetCurrentEventInfo
    _G.CombatLogGetCurrentEventInfo = nil
    local okRead, info, detail = CrusaderStrikeDetection.TryReadCombatLog()
    eq(okRead, false)
    eq(info, nil)
    eq(detail, "missing")
    _G.CombatLogGetCurrentEventInfo = old
  end)

  it("reads callable combat log via pcall", function()
    local old = _G.CombatLogGetCurrentEventInfo
    _G.CombatLogGetCurrentEventInfo = function()
      return 100, "UNIT_DIED", false, nil, nil, nil, nil, "Creature-0-0-0-0-639-0", "Edwin VanCleef", 0
    end
    local okRead, info, detail = CrusaderStrikeDetection.TryReadCombatLog()
    eq(okRead, true)
    eq(detail, "callable")
    eq(info.subevent, "UNIT_DIED")
    eq(info.destName, "Edwin VanCleef")
    _G.CombatLogGetCurrentEventInfo = old
  end)
end)

describe("party death tracker", function()
  it("counts a death once and ignores release while still dead", function()
    local t = CrusaderStrikeDetection.NewDeathTracker(5)
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1000), "death")
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1001), nil) -- still dead
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1002), nil) -- release echo
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", false, 1100), "rez")
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1200), "death") -- new life cycle
  end)

  it("debounces PLAYER_DEAD double-fire within window", function()
    local t = CrusaderStrikeDetection.NewDeathTracker(5)
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1000), "death")
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1002), nil) -- still dead / double-fire
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", false, 1003), "rez")
    -- Premature death edge within debounce after rez (Forever echo)
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1004), nil)
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", false, 1005), "rez")
    eq(CrusaderStrikeDetection.DeathTransition(t, "player", true, 1010), "death")
  end)
end)

describe("encounter lookup", function()
  it("maps verified Deadmines VanCleef encounter", function()
    local row = CrusaderStrikeBosses.LookupByEncounter("forever", 2747)
    eq(row.npcId, 639)
    eq(row.instanceMapId, 36)
    ok(CrusaderStrikeBosses.IsFinalBossByEncounter("forever", 2747))
  end)

  it("maps Sneed encounter to NPC 643 not shredder", function()
    local row = CrusaderStrikeBosses.LookupByEncounter("forever", 2742)
    eq(row.npcId, 643)
  end)

  it("leaves pending Mana Elemental without npc mapping", function()
    eq(CrusaderStrikeBosses.LookupByEncounter("forever", 3301), nil)
  end)
end)

describe("dungeon log encounter handlers", function()
  local function boot_run()
    CrusaderStrikeDB = { schemaVersion = 2, settings = { debug = false, resumeWindowSec = 10800 }, companion = {} }
    CrusaderStrikeCharDB = {
      schemaVersion = 2,
      gameVersion = "forever",
      activeRunKey = nil,
      runs = {},
      pvp = { world = {}, battlegrounds = {}, seq = 0 },
    }
    CrusaderStrike.DungeonLog._resetDeathTracker()
    local run = CrusaderStrikeRunLifecycle.Start({
      realm = "CrusaderStrike",
      character = "Tester",
      gameVersion = "forever",
      instanceId = 36,
      instanceName = "The Deadmines",
      difficulty = 1,
      difficultyName = "Normal",
      startTimeUnix = 1000,
      party = { { name = "Tester", realm = "CrusaderStrike", class = "PALADIN", level = 20, isPlayer = true } },
    })
    CrusaderStrike.StoreRun(run)
    return run
  end

  it("records ENCOUNTER_END success as a boss kill and completes on final", function()
    local run = boot_run()
    ok(CrusaderStrike.DungeonLog.HandleEncounterEnd(2741, "Rhahk'Zor", 1, 5, 1))
    eq(#run.bosses, 1)
    eq(run.bosses[1].npcId, 644)
    ok(not CrusaderStrike.DungeonLog.HandleEncounterEnd(2741, "Rhahk'Zor", 1, 5, 1)) -- dedupe
    ok(CrusaderStrike.DungeonLog.HandleEncounterEnd(2747, "Edwin VanCleef", 1, 5, 1))
    eq(run.completed, true)
    eq(run.status, "completed")
  end)

  it("does not count ENCOUNTER_END wipe as a kill", function()
    local run = boot_run()
    ok(not CrusaderStrike.DungeonLog.HandleEncounterEnd(2747, "Edwin VanCleef", 1, 5, 0))
    eq(#run.bosses, 0)
    eq(run.completed, false)
  end)

  it("records BOSS_KILL via encounter map", function()
    local run = boot_run()
    ok(CrusaderStrike.DungeonLog.HandleBossKill(2745, "Mr. Smite"))
    eq(run.bosses[1].npcId, 646)
  end)

  it("counts player death once across release/rez", function()
    local run = boot_run()
    -- Simulate PLAYER_DEAD
    _G.UnitName = function(unit)
      if unit == "player" then return "Tester", "CrusaderStrike" end
      return nil
    end
    ok(CrusaderStrike.DungeonLog.HandlePlayerDeadEvent())
    eq(#run.deaths, 1)
    ok(not CrusaderStrike.DungeonLog.HandlePlayerDeadEvent()) -- double-fire / still dead
    eq(#run.deaths, 1)
    -- rez then die again after debounce
    CrusaderStrikeDetection.DeathTransition(CrusaderStrike.DungeonLog._deathTracker(), CrusaderStrike.DungeonLog.DeathKey("player"), false, 2000)
    -- advance time past debounce by poking tracker lastDeathAt
    local tr = CrusaderStrike.DungeonLog._deathTracker()
    tr.lastDeathAt[CrusaderStrike.DungeonLog.DeathKey("player")] = 0
    ok(CrusaderStrike.DungeonLog.HandlePlayerDeadEvent())
    eq(#run.deaths, 2)
  end)
end)

describe("debug events buffer", function()
  it("caps and summarizes", function()
    CrusaderStrikeDB = { settings = {}, debugEvents = { enabled = false, entries = {} } }
    CrusaderStrikeDebugEvents.SetEnabled(true)
    for i = 1, 505 do
      CrusaderStrikeDebugEvents.Note("ENCOUNTER_END", i, { encounterID = i, success = 1 })
    end
    eq(CrusaderStrikeDebugEvents.Count(), 500)
    local s = CrusaderStrikeDebugEvents.Summarize(5)
    ok(s:find("debugEvents n=500"))
    ok(s:find("ENCOUNTER_END"))
    CrusaderStrikeDebugEvents.SetEnabled(false)
  end)
end)

describe("party death keying and seeding", function()
  local DL = CrusaderStrike.DungeonLog
  local saved = {}
  local roster, dead

  local function install()
    for _, k in ipairs({ "UnitName", "UnitExists", "UnitGUID", "UnitIsDeadOrGhost" }) do
      saved[k] = _G[k]
    end
    _G.UnitExists = function(u) return roster[u] ~= nil end
    _G.UnitName = function(u)
      local c = roster[u]
      if c then return c.name, c.realm end
      return nil
    end
    _G.UnitGUID = function(u)
      local c = roster[u]
      return c and c.guid or nil
    end
    _G.UnitIsDeadOrGhost = function(u)
      local c = roster[u]
      return c and dead[c.guid] or false
    end
  end
  local function restore()
    for k, v in pairs(saved) do _G[k] = v end
  end
  local function boot()
    CrusaderStrikeDB = { schemaVersion = 2, settings = { debug = false, resumeWindowSec = 10800 }, companion = {} }
    CrusaderStrikeCharDB = { schemaVersion = 2, gameVersion = "forever", runs = {},
      pvp = { world = {}, battlegrounds = {}, seq = 0 } }
    DL._resetDeathTracker()
    local run = CrusaderStrikeRunLifecycle.Start({
      realm = "CrusaderStrike", character = "Tester", gameVersion = "forever",
      instanceId = 36, instanceName = "The Deadmines", difficulty = 1, difficultyName = "Normal",
      startTimeUnix = 1000, party = {},
    })
    CrusaderStrike.StoreRun(run)
    return run
  end
  local A = { name = "Alice", realm = "CrusaderStrike", guid = "Player-1-0000000A" }
  local B = { name = "Bob", realm = "CrusaderStrike", guid = "Player-1-0000000B" }
  local P = { name = "Tester", realm = "CrusaderStrike", guid = "Player-1-00000001" }

  it("does not count an already-dead member after /reload (seeded)", function()
    install()
    roster = { player = P, party1 = A, party2 = B }
    dead = { [B.guid] = true }
    local run = boot() -- tracker reset == /reload
    DL.SeedDeathState()
    ok(not DL.HandlePartyDeath("party2"))
    ok(not DL.HandlePartyDeath("party2")) -- ghost UNIT_HEALTH ticks
    eq(#run.deaths, 0)
    -- rez then die again later: counted once
    dead[B.guid] = nil
    ok(not DL.HandlePartyDeath("party2"))
    DL._deathTracker().lastDeathAt["guid:" .. B.guid] = 0
    dead[B.guid] = true
    ok(DL.HandlePartyDeath("party2"))
    eq(#run.deaths, 1)
    restore()
  end)

  it("does not recount a dead member who shifts slots after someone leaves", function()
    install()
    roster = { player = P, party1 = A, party2 = B }
    dead = {}
    local run = boot()
    DL.SeedDeathState()
    dead[B.guid] = true
    ok(DL.HandlePartyDeath("party2"))
    eq(#run.deaths, 1)
    -- Alice leaves; Bob (still dead) shifts party2 -> party1
    roster = { player = P, party1 = B }
    DL.SeedDeathState() -- GROUP_ROSTER_UPDATE
    ok(not DL.HandlePartyDeath("party1"))
    ok(not DL.HandlePartyDeath("party2"))
    eq(#run.deaths, 1)
    restore()
  end)

  it("ignores UNIT_* events for unwatched units and keys by GUID", function()
    ok(DL.WATCHED_UNITS["party4"] and DL.WATCHED_UNITS["boss5"] and DL.WATCHED_UNITS["player"])
    ok(not DL.WATCHED_UNITS["target"])
    ok(not DL.WATCHED_UNITS["nameplate1"])
    ok(not DL.WATCHED_UNITS["raid1"])
    install()
    roster = { party1 = A }
    eq(DL.DeathKey("party1"), "guid:" .. A.guid)
    roster = { party1 = { name = "NoGuid", realm = "X" } }
    eq(DL.DeathKey("party1"), "name:NoGuid-X")
    restore()
  end)
end)

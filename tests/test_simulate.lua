-- addon#22: /cs debug simulate kill|death
local CS = CrusaderStrike
local RL = CrusaderStrikeRunLifecycle

local function reset()
  CrusaderStrikeDB = { settings = { debug = false, resumeWindowSec = 10800 } }
  CrusaderStrikeCharDB = { gameVersion = "forever", runs = {}, activeRunKey = nil, pvp = { world = {}, battlegrounds = {}, seq = 0 } }
  CS.DungeonLog._resetDeathTracker()
end

local function count_runs()
  local n = 0
  for _ in pairs(CrusaderStrikeCharDB.runs) do n = n + 1 end
  return n
end

describe("debug simulate gating", function()
  it("refuses kill and death while debug mode is off", function()
    reset()
    local okk = CS.DebugSimulate.Kill()
    local okd = CS.DebugSimulate.Death()
    ok(not okk, "kill refused")
    ok(not okd, "death refused")
    eq(count_runs(), 0, "no runs written")
  end)

  it("/cs debug on|off sets debug explicitly (no toggle)", function()
    reset()
    SlashCmdList["CRUSADERSTRIKE"]("debug on")
    eq(CrusaderStrikeDB.settings.debug, true)
    SlashCmdList["CRUSADERSTRIKE"]("debug on")
    eq(CrusaderStrikeDB.settings.debug, true, "on twice stays on")
    SlashCmdList["CRUSADERSTRIKE"]("debug simulate kill")
    eq(count_runs(), 1, "slash simulate ran")
    SlashCmdList["CRUSADERSTRIKE"]("debug off")
    eq(CrusaderStrikeDB.settings.debug, false)
    SlashCmdList["CRUSADERSTRIKE"]("debug simulate kill")
    eq(count_runs(), 1, "gated once off")
  end)
end)

describe("debug simulate kill", function()
  it("goes through ENCOUNTER_END/BOSS_KILL handlers into a simulated sandbox run", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    CS.DebugEvents.SetEnabled(true)
    CS.DebugEvents.Clear()
    local okk, msg, run = CS.DebugSimulate.Kill("oggle")
    ok(okk, tostring(msg))
    eq(run.simulated, true, "run simulated")
    eq(#run.bosses, 1, "one kill (BOSS_KILL deduped)")
    eq(run.bosses[1].npcId, 11517)
    eq(run.bosses[1].simulated, true, "boss row simulated")
    eq(run.instance.id, 389)
    ok(run.status ~= "in_progress", "sandbox closed")
    eq(CrusaderStrikeCharDB.activeRunKey, nil, "active key restored")
    local seen = {}
    for _, e in ipairs(CS.DebugEvents and CrusaderStrikeDebugEvents.Entries() or {}) do seen[e.event] = true end
    ok(seen.ENCOUNTER_END, "ENCOUNTER_END handler ran")
    ok(seen.BOSS_KILL, "BOSS_KILL handler ran")
    CS.DebugEvents.SetEnabled(false)
    local okf, _, runf = CS.DebugSimulate.Kill("Bazzalan")
    ok(okf, "final boss kill")
    eq(runf.completed, true, "final boss completes only the sandbox run")
    eq(_G._CS_CombatLogCallCount or 0, 0, "no CLEU")
    eq(_G._CS_CleuRegisterAttempts or 0, 0, "no CLEU register")
  end)

  it("defaults to a Ragefire Chasm encounter and rejects unknown bosses", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local okk, _, run = CS.DebugSimulate.Kill()
    ok(okk)
    eq(run.instance.id, 389)
    local bad = CS.DebugSimulate.Kill("Not A Real Boss")
    ok(not bad, "unknown boss refused")
  end)

  it("never writes into the real active run", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local real = RL.Start({ realm = "CrusaderStrike", character = "Tester", gameVersion = "forever",
      instanceId = 389, instanceName = "Ragefire Chasm", difficulty = 1, startTimeUnix = os.time(), party = {} })
    CS.StoreRun(real)
    CS.DebugSimulate.Kill("Bazzalan")
    CS.DebugSimulate.Death("player")
    eq(CrusaderStrikeCharDB.activeRunKey, real.idempotencyKey, "real run still active")
    eq(#real.bosses, 0, "real run has no simulated kill")
    eq(#real.deaths, 0, "real run has no simulated death")
    eq(real.status, "in_progress")


  end)
end)

describe("debug simulate death", function()
  it("player death goes through PLAYER_DEAD and leaves the real tracker alone", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local okd, msg, run = CS.DebugSimulate.Death()
    ok(okd, tostring(msg))
    eq(#run.deaths, 1)
    eq(run.deaths[1].name, "Tester")
    eq(run.deaths[1].simulated, true)
    eq(CS.DungeonLog._deathTracker().dead[CS.DungeonLog.DeathKey("player")], nil, "real tracker untouched")
    local ok2, _, run2 = CS.DebugSimulate.Death("player")
    ok(ok2, "repeatable (fresh tracker each time)")
    eq(#run2.deaths, 1)
  end)

  it("party unit / name death records a simulated row", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local okd, _, run = CS.DebugSimulate.Death("party2")
    ok(okd)
    eq(run.deaths[1].name, "Simparty2")
    eq(run.deaths[1].simulated, true)
    local okn, _, runn = CS.DebugSimulate.Death("Healbot")
    ok(okn)
    eq(runn.deaths[1].name, "Healbot")
  end)
end)

describe("simulated records excluded from export/upload", function()
  it("ToExportTable drops simulated rows by default, keeps them on request", function()
    local run = RL.Start({ realm = "R", character = "C", gameVersion = "forever", instanceId = 389,
      instanceName = "Ragefire Chasm", difficulty = 1, startTimeUnix = 1000, party = {} })
    RL.RecordBossKill(run, 11517, "Oggleflint", 1010)
    RL.RecordBossKill(run, 11519, "Bazzalan", 1020)
    run.bosses[2].simulated = true
    RL.RecordDeath(run, "C", "R", 1015, nil)
    run.deaths[1].simulated = true
    local t = RL.ToExportTable(run)
    eq(#t.bosses, 1)
    eq(t.bosses[1].npcId, 11517)
    eq(#t.deaths, 0)
    local all = RL.ToExportTable(run, { includeSimulated = true })
    eq(#all.bosses, 2)
    eq(#all.deaths, 1)
    eq(#run.bosses, 2, "stored run not mutated")
  end)

  it("simulated runs are not uploadable or picked by /cs export", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local _, _, run = CS.DebugSimulate.Kill()
    ok(not RL.IsUploadable(run), "not uploadable")
    ok(RL.IsUploadable(run, { includeSimulated = true }), "opt-in")
    ok(RL.IsUploadable({ status = "closed" }), "real runs uploadable")

    local printed = {}
    local orig = CS.Print
    CS.Print = function(m) printed[#printed + 1] = m end
    CS.Export.Show(nil)
    local firstCount = #printed
    CS.Export.Show(run.idempotencyKey)
    CS.Print = orig
    eq(printed[1], "No runs to export yet (gear line still available).")
    local refused = false
    for i = firstCount + 1, #printed do
      if printed[i]:find("simulated", 1, true) then refused = true end
    end
    ok(refused, "explicit key refused")
  end)
end)

describe("simulated sandbox runs are never resumed (review 5780402317)", function()
  local function enter_rfc()
    local origII, origGI = IsInInstance, GetInstanceInfo
    _G.IsInInstance = function() return true, "party" end
    _G.GetInstanceInfo = function() return "Ragefire Chasm", "party", 1, "Normal", 5, 0, false, 389 end
    local okc, err = pcall(CS.DungeonLog.TryStartOrResume)
    _G.IsInInstance, _G.GetInstanceInfo = origII, origGI
    ok(okc, tostring(err))
  end

  it("ShouldResume refuses a simulated run even if closed and inside the window", function()
    local run = RL.Start({ realm = "R", character = "C", gameVersion = "forever", instanceId = 389,
      instanceName = "Ragefire Chasm", difficulty = 1, startTimeUnix = os.time(), party = {} })
    RL.Close(run, os.time())
    eq(run.status, "closed")
    ok(RL.ShouldResume(run, 389, os.time(), 10800), "real closed run resumable")
    run.simulated = true
    ok(not RL.ShouldResume(run, 389, os.time(), 10800), "simulated run not resumable")
  end)

  for _, kind in ipairs({ "kill", "death" }) do
    it("entering RFC after simulate " .. kind .. " starts a fresh real run", function()
      reset()
      CrusaderStrikeDB.settings.debug = true
      local okk, msg, sim
      if kind == "kill" then okk, msg, sim = CS.DebugSimulate.Kill("oggle")
      else okk, msg, sim = CS.DebugSimulate.Death() end
      ok(okk, tostring(msg))
      eq(sim.status, "abandoned", "sandbox abandoned on exit")
      ok(not RL.ShouldResume(sim, 389, os.time(), 10800), "sandbox not resume-eligible")
      enter_rfc()
      local key = CrusaderStrikeCharDB.activeRunKey
      ok(key and key ~= sim.idempotencyKey, "did not resume sandbox")
      local live = CrusaderStrikeCharDB.runs[key]
      ok(live and not live.simulated, "live run is real")
      eq(live.status, "in_progress")
      ok(RL.IsUploadable(live), "live run uploadable")
      eq(sim.status, "abandoned", "sandbox untouched")
      ok(not key:find("^sim%-"), "no sim- key")
    end)
  end

  it("real RFC entry does not resume a CLOSED simulated run inside the window", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local okk, msg, sim = CS.DebugSimulate.Kill("oggle")
    ok(okk, tostring(msg))
    sim.status = "closed"
    sim.endTimeUnix = os.time()
    CrusaderStrikeCharDB.activeRunKey = nil
    ok(not RL.ShouldResume(sim, 389, os.time(), 10800), "closed sim not resume-eligible")
    enter_rfc()
    local key = CrusaderStrikeCharDB.activeRunKey
    ok(key and key ~= sim.idempotencyKey, "did not resume closed sandbox")
    local live = CrusaderStrikeCharDB.runs[key]
    ok(live and not live.simulated, "live run is real")
    eq(live.status, "in_progress")
    eq(sim.status, "closed", "closed sandbox untouched")
  end)

  it("ToExportTable refuses a simulated run unless includeSimulated", function()
    local run = { simulated = true, status = "abandoned", instance = { id = 389 }, bosses = {}, deaths = {} }
    eq(RL.ToExportTable(run), nil)
    ok(RL.ToExportTable(run, { includeSimulated = true }), "opt-in envelope")
  end)

  it("prunes sandbox runs beyond the cap", function()
    reset()
    CrusaderStrikeDB.settings.debug = true
    local cap = CS.DebugSimulate.MAX_SANDBOX_RUNS
    for i = 1, cap + 3 do
      CrusaderStrikeCharDB.runs["sim-old" .. i] = { simulated = true, startedAt = i, status = "abandoned", instance = { id = 389 } }
    end
    CrusaderStrikeCharDB.runs["real"] = { status = "closed", startedAt = 1, instance = { id = 389 } }
    CS.DebugSimulate.Kill()
    local sims = 0
    for _, r in pairs(CrusaderStrikeCharDB.runs) do if r.simulated then sims = sims + 1 end end
    eq(sims, cap, "capped")
    ok(CrusaderStrikeCharDB.runs["real"], "real run kept")
  end)
end)

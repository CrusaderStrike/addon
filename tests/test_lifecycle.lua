describe("run lifecycle", function()
  local function start(opts)
    opts = opts or {}
    return CrusaderStrikeRunLifecycle.Start({
      realm = opts.realm or "CrusaderStrike",
      character = opts.character or "Tester",
      gameVersion = "forever",
      instanceId = opts.instanceId or 36,
      instanceName = opts.instanceName or "The Deadmines",
      difficulty = 1,
      difficultyName = "Normal",
      startTimeUnix = opts.startTimeUnix or 1000,
      party = { { name = "Tester", realm = "CrusaderStrike", class = "PALADIN", level = 20, isPlayer = true } },
    })
  end

  it("starts with idempotency key", function()
    local run = start()
    eq(run.idempotencyKey, "CrusaderStrike|Tester|1000|36")
    eq(run.status, "in_progress")
    eq(run.completed, false)
    eq(run.schemaVersion, 1)
    eq(run.lastSeenAt, 1000)
  end)

  it("records unique boss kills and completion", function()
    local run = start()
    ok(CrusaderStrikeRunLifecycle.RecordBossKill(run, 644, "Rhahk'Zor", 1100))
    ok(not CrusaderStrikeRunLifecycle.RecordBossKill(run, 644, "Rhahk'Zor", 1101))
    eq(#run.bosses, 1)
    eq(run.lastSeenAt, 1100)
    CrusaderStrikeRunLifecycle.MarkCompleted(run, 2000)
    eq(run.completed, true)
    eq(run.status, "completed")
    eq(run.durationSec, 1000)
  end)

  it("records deaths", function()
    local run = start()
    CrusaderStrikeRunLifecycle.RecordDeath(run, "Tester", "CrusaderStrike", 1500, "Goblin")
    eq(#run.deaths, 1)
    eq(run.deaths[1].source, "Goblin")
    eq(run.lastSeenAt, 1500)
  end)

  it("closes and resumes within window", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Close(run, 1300)
    eq(run.status, "closed")
    eq(run.durationSec, 300)
    ok(CrusaderStrikeRunLifecycle.ShouldResume(run, 36, 2000, 3600))
    ok(not CrusaderStrikeRunLifecycle.ShouldResume(run, 36, 100000, 3600))
    ok(not CrusaderStrikeRunLifecycle.ShouldResume(run, 389, 2000, 3600))
    CrusaderStrikeRunLifecycle.Resume(run)
    eq(run.status, "in_progress")
    eq(run.endedAt, nil)
  end)

  it("does not resume completed runs", function()
    local run = start()
    CrusaderStrikeRunLifecycle.MarkCompleted(run, 1800)
    CrusaderStrikeRunLifecycle.Close(run, 1800)
    ok(not CrusaderStrikeRunLifecycle.ShouldResume(run, 36, 1900, 3600))
  end)

  it("export table includes required fields", function()
    local run = start()
    local t = CrusaderStrikeRunLifecycle.ToExportTable(run)
    eq(t.schemaVersion, 1)
    eq(t.gameVersion, "forever")
    eq(t.instance.id, 36)
    ok(t.party[1].isPlayer)
  end)

  it("abandons with lastSeenAt endedAt and completed=false (hearth-out)", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Touch(run, 1200)
    CrusaderStrikeRunLifecycle.RecordBossKill(run, 644, "Rhahk'Zor", 1250)
    -- Player hearths out much later; abandon uses lastSeen, not the late login clock.
    CrusaderStrikeRunLifecycle.Abandon(run, run.lastSeenAt)
    eq(run.status, "abandoned")
    eq(run.completed, false)
    eq(run.endedAt, 1250)
    eq(run.durationSec, 250)
    ok(not CrusaderStrikeRunLifecycle.ShouldResume(run, 36, 1300, 3600))
    local export = CrusaderStrikeRunLifecycle.ToExportTable(run)
    eq(export.status, "closed")
    eq(export.completed, false)
    eq(export.endedAt, 1250)
    eq(export.lastSeenAt, nil)
    eq(run.status, "abandoned") -- local status untouched by export
  end)

  it("abandoned run exports as closed with completed=false (never 'abandoned')", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Touch(run, 1300)
    CrusaderStrikeRunLifecycle.Abandon(run, run.lastSeenAt)
    local export = CrusaderStrikeRunLifecycle.ToExportTable(run)
    eq(export.status, "closed")
    eq(export.completed, false)
    ok(export.status ~= "abandoned")
    eq(run.status, "abandoned")
  end)

  it("completed run export is unchanged", function()
    local run = start()
    CrusaderStrikeRunLifecycle.MarkCompleted(run, 2000)
    local export = CrusaderStrikeRunLifecycle.ToExportTable(run)
    eq(export.status, "completed")
    eq(export.completed, true)
    eq(export.endedAt, 2000)
    eq(export.durationSec, 1000)
  end)

  it("closed and in_progress runs export their status unchanged", function()
    local run = start()
    eq(CrusaderStrikeRunLifecycle.ToExportTable(run).status, "in_progress")
    CrusaderStrikeRunLifecycle.Close(run, 1500)
    local export = CrusaderStrikeRunLifecycle.ToExportTable(run)
    eq(export.status, "closed")
    eq(export.completed, false)
  end)

  it("reload in the same instance resumes instead of abandoning", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Touch(run, 1500)
    local runs = { [run.idempotencyKey] = run }
    local result = CrusaderStrikeRunLifecycle.ReconcileStale(runs, {
      currentInstanceId = 36,
      nowUnix = 1600,
      resumeWindowSec = 3600,
    })
    eq(#result.abandoned, 0)
    eq(result.kept, run)
    eq(run.status, "in_progress")
    ok(CrusaderStrikeRunLifecycle.ShouldResume(run, 36, 1600, 3600))
  end)

  it("crash/relog later outside the instance abandons using lastSeen", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Touch(run, 1400)
    local runs = { [run.idempotencyKey] = run }
    -- Hours later, player logs in outside any dungeon.
    local result = CrusaderStrikeRunLifecycle.ReconcileStale(runs, {
      currentInstanceId = nil,
      nowUnix = 1400 + 7200,
      resumeWindowSec = 3600,
    })
    eq(#result.abandoned, 1)
    eq(result.kept, nil)
    eq(run.status, "abandoned")
    eq(run.endedAt, 1400)
    eq(run.durationSec, 400)
    eq(run.completed, false)
  end)

  it("entering a different dungeon abandons the previous in_progress run", function()
    local deadmines = start({ instanceId = 36, startTimeUnix = 1000 })
    CrusaderStrikeRunLifecycle.Touch(deadmines, 1100)
    local runs = { [deadmines.idempotencyKey] = deadmines }
    local result = CrusaderStrikeRunLifecycle.ReconcileStale(runs, {
      currentInstanceId = 389, -- Ragefire Chasm
      nowUnix = 2000,
      resumeWindowSec = 10800,
    })
    eq(#result.abandoned, 1)
    eq(deadmines.status, "abandoned")
    eq(deadmines.endedAt, 1100)
    eq(result.kept, nil)
  end)

  it("reconcile abandons multiple stale in_progress runs", function()
    local a = start({ instanceId = 36, startTimeUnix = 1000, character = "A" })
    local b = start({ instanceId = 389, startTimeUnix = 2000, character = "B" })
    CrusaderStrikeRunLifecycle.Touch(a, 1050)
    CrusaderStrikeRunLifecycle.Touch(b, 2100)
    local runs = {
      [a.idempotencyKey] = a,
      [b.idempotencyKey] = b,
    }
    local result = CrusaderStrikeRunLifecycle.ReconcileStale(runs, {
      currentInstanceId = nil,
      nowUnix = 5000,
      resumeWindowSec = 10800,
    })
    eq(#result.abandoned, 2)
    eq(a.status, "abandoned")
    eq(b.status, "abandoned")
    eq(a.endedAt, 1050)
    eq(b.endedAt, 2100)
  end)

  it("same-instance past resume window is abandoned (not resumed)", function()
    local run = start()
    CrusaderStrikeRunLifecycle.Touch(run, 1000)
    local runs = { [run.idempotencyKey] = run }
    local result = CrusaderStrikeRunLifecycle.ReconcileStale(runs, {
      currentInstanceId = 36,
      nowUnix = 1000 + 10801,
      resumeWindowSec = 10800,
    })
    eq(#result.abandoned, 1)
    eq(run.status, "abandoned")
    eq(result.kept, nil)
  end)
end)

describe("party-death name compare", function()
  local L = CrusaderStrikeRunLifecycle
  it("matches exact and Name-Realm", function()
    eq(L.NameMatches("Aldric", "Aldric"), true)
    eq(L.NameMatches("Aldric-Ironhollow", "Aldric"), true)
    eq(L.NameMatches("Aldricson", "Aldric"), false)
    eq(L.NameMatches("Bob", "Aldric"), false)
  end)
  it("does not treat names as patterns", function()
    eq(L.NameMatches("Xy-Realm", "X."), false)
    eq(L.NameMatches("X.-Realm", "X."), true)
    eq(L.NameMatches("Ab", "A%"), false)
    eq(L.NameMatches("Aldric", nil), false)
    eq(L.NameMatches(nil, "Aldric"), false)
  end)
  it("splits on the first hyphen", function()
    local n, r = L.SplitNameRealm("Aldric-Ironhollow")
    eq(n, "Aldric"); eq(r, "Ironhollow")
    n, r = L.SplitNameRealm("Aldric")
    eq(n, "Aldric"); eq(r, nil)
  end)
end)

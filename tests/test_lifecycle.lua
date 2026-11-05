describe("run lifecycle", function()
  local function start()
    return CrusaderStrikeRunLifecycle.Start({
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
  end

  it("starts with idempotency key", function()
    local run = start()
    eq(run.idempotencyKey, "CrusaderStrike|Tester|1000|36")
    eq(run.status, "in_progress")
    eq(run.completed, false)
    eq(run.schemaVersion, 1)
  end)

  it("records unique boss kills and completion", function()
    local run = start()
    ok(CrusaderStrikeRunLifecycle.RecordBossKill(run, 644, "Rhahk'Zor", 1100))
    ok(not CrusaderStrikeRunLifecycle.RecordBossKill(run, 644, "Rhahk'Zor", 1101))
    eq(#run.bosses, 1)
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
end)

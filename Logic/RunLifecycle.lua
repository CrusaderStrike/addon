-- Pure run state machine: start, boss kill, death, close, resume.
-- WoW-facing code supplies clocks and snapshots; this module mutates run tables only.

CrusaderStrikeRunLifecycle = CrusaderStrikeRunLifecycle or {}

local Idem = CrusaderStrikeIdempotency

local SCHEMA_VERSION = 1

function CrusaderStrikeRunLifecycle.SchemaVersion()
  return SCHEMA_VERSION
end

-- Build a new in-progress run.
-- opts: realm, character, gameVersion, instanceId, instanceName, difficulty, difficultyName, startTimeUnix, party
function CrusaderStrikeRunLifecycle.Start(opts)
  local startTime = opts.startTimeUnix
  local key = Idem.MakeKey(opts.realm, opts.character, startTime, opts.instanceId)
  return {
    schemaVersion = SCHEMA_VERSION,
    gameVersion = opts.gameVersion or "forever",
    idempotencyKey = key,
    addonRunId = Idem.ToAddonRunId(key),
    realm = opts.realm,
    character = opts.character,
    instance = {
      id = opts.instanceId,
      name = opts.instanceName or "",
      difficulty = opts.difficulty,
      difficultyName = opts.difficultyName,
    },
    startedAt = startTime,
    endedAt = nil,
    durationSec = nil,
    completed = false,
    status = "in_progress", -- in_progress | closed | completed
    party = opts.party or {},
    bosses = {},
    deaths = {},
  }
end

function CrusaderStrikeRunLifecycle.RecordBossKill(run, npcId, bossName, killedAt)
  if not run or run.status == "closed" then
    return false
  end
  for _, b in ipairs(run.bosses) do
    if b.npcId == npcId then
      return false -- already recorded
    end
  end
  run.bosses[#run.bosses + 1] = {
    npcId = npcId,
    name = bossName or ("npc:" .. tostring(npcId)),
    killedAt = killedAt,
  }
  return true
end

function CrusaderStrikeRunLifecycle.RecordDeath(run, playerName, playerRealm, diedAt, sourceName)
  if not run or run.status == "closed" then
    return false
  end
  run.deaths[#run.deaths + 1] = {
    name = playerName,
    realm = playerRealm,
    time = diedAt,
    source = sourceName,
  }
  return true
end

function CrusaderStrikeRunLifecycle.MarkCompleted(run, endedAt)
  if not run then
    return
  end
  run.completed = true
  run.status = "completed"
  run.endedAt = endedAt or run.endedAt
  if run.startedAt and run.endedAt then
    run.durationSec = math.max(0, run.endedAt - run.startedAt)
  end
end

-- Close when leaving the instance. completed stays true if final boss was killed.
function CrusaderStrikeRunLifecycle.Close(run, endedAt)
  if not run or run.status == "closed" then
    return run
  end
  run.endedAt = endedAt
  if run.startedAt and endedAt then
    run.durationSec = math.max(0, endedAt - run.startedAt)
  end
  if run.completed then
    run.status = "completed"
  else
    run.status = "closed"
  end
  return run
end

-- Resume if we re-enter the same instance map while a matching open-ish run exists.
-- Matching: same instanceId, same realm/character, not older than resumeWindowSec,
-- and status was closed (left mid-run) or still in_progress (reload).
function CrusaderStrikeRunLifecycle.ShouldResume(activeOrLast, instanceId, nowUnix, resumeWindowSec)
  if not activeOrLast then
    return false
  end
  if activeOrLast.instance.id ~= instanceId then
    return false
  end
  if activeOrLast.status == "completed" then
    return false
  end
  local anchor = activeOrLast.endedAt or activeOrLast.startedAt or 0
  local window = resumeWindowSec or (3 * 60 * 60) -- 3 hours default
  if nowUnix - anchor > window then
    return false
  end
  return true
end

function CrusaderStrikeRunLifecycle.Resume(run)
  if not run then
    return nil
  end
  run.status = "in_progress"
  run.endedAt = nil
  run.durationSec = nil
  return run
end

-- Convert a stored run into the public export / platform payload shape.
function CrusaderStrikeRunLifecycle.ToExportTable(run)
  return {
    schemaVersion = run.schemaVersion or SCHEMA_VERSION,
    gameVersion = run.gameVersion,
    idempotencyKey = run.idempotencyKey,
    addonRunId = run.addonRunId or run.idempotencyKey,
    realm = run.realm,
    character = run.character,
    instance = {
      id = run.instance.id,
      name = run.instance.name,
      difficulty = run.instance.difficulty,
      difficultyName = run.instance.difficultyName,
    },
    startedAt = run.startedAt,
    endedAt = run.endedAt,
    durationSec = run.durationSec,
    completed = run.completed and true or false,
    status = run.status,
    party = run.party or {},
    bosses = run.bosses or {},
    deaths = run.deaths or {},
  }
end

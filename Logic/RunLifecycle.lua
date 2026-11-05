-- Pure run state machine: start, boss kill, death, close, abandon, resume.
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
    lastSeenAt = startTime, -- updated while the run is active; used when abandoning after crash/hearth
    completed = false,
    status = "in_progress", -- in_progress | closed | abandoned | completed
    party = opts.party or {},
    bosses = {},
    deaths = {},
  }
end

-- Bump lastSeenAt during an active run (login pulse, combat events, zone checks).
function CrusaderStrikeRunLifecycle.Touch(run, seenAt)
  if not run or run.status ~= "in_progress" then
    return false
  end
  if not seenAt then
    return false
  end
  if not run.lastSeenAt or seenAt >= run.lastSeenAt then
    run.lastSeenAt = seenAt
  end
  return true
end

function CrusaderStrikeRunLifecycle.RecordBossKill(run, npcId, bossName, killedAt)
  if not run or run.status == "closed" or run.status == "abandoned" then
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
  CrusaderStrikeRunLifecycle.Touch(run, killedAt)
  return true
end

function CrusaderStrikeRunLifecycle.RecordDeath(run, playerName, playerRealm, diedAt, sourceName)
  if not run or run.status == "closed" or run.status == "abandoned" then
    return false
  end
  run.deaths[#run.deaths + 1] = {
    name = playerName,
    realm = playerRealm,
    time = diedAt,
    source = sourceName,
  }
  CrusaderStrikeRunLifecycle.Touch(run, diedAt)
  return true
end

function CrusaderStrikeRunLifecycle.MarkCompleted(run, endedAt)
  if not run then
    return
  end
  run.completed = true
  run.status = "completed"
  run.endedAt = endedAt or run.endedAt
  if endedAt then
    CrusaderStrikeRunLifecycle.Touch(run, endedAt)
  end
  if run.startedAt and run.endedAt then
    run.durationSec = math.max(0, run.endedAt - run.startedAt)
  end
end

local function finish_duration(run, endedAt)
  run.endedAt = endedAt
  if run.startedAt and endedAt then
    run.durationSec = math.max(0, endedAt - run.startedAt)
  end
end

-- Close when leaving the instance intentionally (zone change out). completed stays true if final boss was killed.
function CrusaderStrikeRunLifecycle.Close(run, endedAt)
  if not run or run.status == "closed" or run.status == "abandoned" then
    return run
  end
  finish_duration(run, endedAt)
  if run.completed then
    run.status = "completed"
  else
    run.status = "closed"
  end
  return run
end

-- Abandon a stale or interrupted in_progress run (hearth/crash leftover, or leave without completion).
-- endedAt should be lastSeenAt so a later login does not invent a long fake duration.
function CrusaderStrikeRunLifecycle.Abandon(run, endedAt)
  if not run then
    return run
  end
  if run.status == "closed" or run.status == "abandoned" or run.status == "completed" then
    return run
  end
  local stamp = endedAt or run.lastSeenAt or run.startedAt
  run.completed = false
  run.status = "abandoned"
  finish_duration(run, stamp)
  return run
end

-- Anchor used for resume-window checks: prefer last activity, then endedAt, then start.
function CrusaderStrikeRunLifecycle.ResumeAnchor(run)
  if not run then
    return 0
  end
  return run.lastSeenAt or run.endedAt or run.startedAt or 0
end

-- Resume if we re-enter the same instance map while a matching open-ish run exists.
-- Matching: same instanceId, same realm/character, not older than resumeWindowSec,
-- and status was closed (left mid-run) or still in_progress (reload). Abandoned runs do not resume.
function CrusaderStrikeRunLifecycle.ShouldResume(activeOrLast, instanceId, nowUnix, resumeWindowSec)
  if not activeOrLast then
    return false
  end
  -- Simulated (/cs debug simulate) sandbox runs are never resumable: real
  -- logging attached to a sim- run would be refused by IsUploadable forever.
  if activeOrLast.simulated then
    return false
  end
  if activeOrLast.instance.id ~= instanceId then
    return false
  end
  if activeOrLast.status == "completed" or activeOrLast.status == "abandoned" then
    return false
  end
  local anchor = CrusaderStrikeRunLifecycle.ResumeAnchor(activeOrLast)
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

-- Close every in_progress run that is not the current instance (or none if outside a dungeon).
-- Same-instance in_progress within the resume window is kept (reload / reconnect).
-- Returns { abandoned = {runs...}, kept = run|nil }.
function CrusaderStrikeRunLifecycle.ReconcileStale(runs, opts)
  opts = opts or {}
  local currentInstanceId = opts.currentInstanceId -- nil when outside a party dungeon
  local nowUnix = opts.nowUnix or 0
  local window = opts.resumeWindowSec or (3 * 60 * 60)
  local abandoned = {}
  local kept = nil

  if type(runs) ~= "table" then
    return { abandoned = abandoned, kept = kept }
  end

  for _, run in pairs(runs) do
    if run and run.status == "in_progress" then
      local sameInstance = currentInstanceId ~= nil and run.instance and run.instance.id == currentInstanceId
      if sameInstance and CrusaderStrikeRunLifecycle.ShouldResume(run, currentInstanceId, nowUnix, window) then
        kept = run
      else
        -- Outside the instance, different dungeon, or past the resume window.
        CrusaderStrikeRunLifecycle.Abandon(run, run.lastSeenAt or run.startedAt)
        abandoned[#abandoned + 1] = run
      end
    end
  end

  return { abandoned = abandoned, kept = kept }
end

-- Map local (SavedVariables) status to the platform API enum
-- (platform#18: in_progress | closed | completed). "abandoned" is local-only
-- and is exported as "closed" with completed=false.
function CrusaderStrikeRunLifecycle.ExportStatus(run)
  if run.status == "abandoned" then
    return "closed"
  end
  return run.status
end

-- Convert a stored run into the public export / platform payload shape.
-- addon#22: /cs debug simulate records carry simulated=true. Exports and
-- uploads drop them unless opts.includeSimulated is set.
local function without_simulated(list, include)
  local out = {}
  for _, e in ipairs(list or {}) do
    if include or not e.simulated then
      out[#out + 1] = e
    end
  end
  return out
end

function CrusaderStrikeRunLifecycle.IsSimulated(run)
  return run ~= nil and run.simulated == true
end

-- Companion/uploader gate: simulated sandbox runs never upload by default.
function CrusaderStrikeRunLifecycle.IsUploadable(run, opts)
  if not run then
    return false
  end
  if run.simulated and not (opts and opts.includeSimulated) then
    return false
  end
  return true
end

function CrusaderStrikeRunLifecycle.ToExportTable(run, opts)
  local includeSim = opts and opts.includeSimulated or false
  -- Defense in depth: never build an envelope for a simulated run unless asked.
  if run.simulated and not includeSim then
    return nil
  end
  local abandoned = run.status == "abandoned"
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
    completed = (not abandoned) and (run.completed and true or false) or false,
    status = CrusaderStrikeRunLifecycle.ExportStatus(run),
    party = run.party or {},
    bosses = without_simulated(run.bosses, includeSim),
    deaths = without_simulated(run.deaths, includeSim),
  }
end

-- Plain (non-pattern) name compare for party-death matching.
-- Matches "Name" or "Name-Realm" against a unit name without treating
-- either string as a Lua pattern (names may contain magic chars).
function CrusaderStrikeRunLifecycle.NameMatches(destName, unitName)
  if type(destName) ~= "string" or type(unitName) ~= "string" or unitName == "" then
    return false
  end
  if destName == unitName then
    return true
  end
  local prefix = unitName .. "-"
  return destName:sub(1, #prefix) == prefix
end

-- Split "Name-Realm" on the first hyphen with a plain find.
function CrusaderStrikeRunLifecycle.SplitNameRealm(fullName)
  if type(fullName) ~= "string" then
    return fullName, nil
  end
  local i = fullName:find("-", 1, true)
  if not i or i == 1 or i == #fullName then
    return fullName, nil
  end
  return fullName:sub(1, i - 1), fullName:sub(i + 1)
end

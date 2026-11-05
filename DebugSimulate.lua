--[[
  /cs debug simulate kill [bossName] | death [unit]   (addon#22, WoW Forever only)

  Lets kill/death logging be exercised without a dungeon-level character.
  Synthetic events go through the SAME DungeonLog handlers as live play:
    kill  -> ENCOUNTER_END (success=1) then BOSS_KILL via the DungeonLog OnEvent
    death -> PLAYER_DEAD handler for "player"; record_party_death (the path
             UNIT_HEALTH/UNIT_FLAGS use after an alive->dead edge) for party1-4
             or a bare name.

  Safety:
  * Requires debug mode (/cs debug on).
  * Writes only into a throwaway sandbox run marked simulated=true; every
    boss/death row written is also simulated=true. The real active run, its
    boss dedupe and the real death tracker are never touched.
  * Simulated runs/rows are excluded from /cs export and uploads by default
    (CrusaderStrikeRunLifecycle.IsUploadable / ToExportTable).
  * No COMBAT_LOG_EVENT_UNFILTERED, no CombatLogGetCurrentEventInfo and no
    protected calls: only plain Lua tables and addon functions.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.DebugSimulate = CS.DebugSimulate or {}
local Sim = CS.DebugSimulate

local DEFAULT_INSTANCE = 389 -- Ragefire Chasm
local MAX_SANDBOX_RUNS = 5 -- keep only the newest simulated runs for inspection
Sim.MAX_SANDBOX_RUNS = MAX_SANDBOX_RUNS

local function now()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

function Sim.IsAllowed()
  local db = CS.GetAccountDB and CS.GetAccountDB()
  return db and db.settings and db.settings.debug == true or false
end

-- Pick a verified encounter by (case-insensitive substring) boss name, or the
-- lowest encounter ID in Ragefire Chasm when no name is given.
function Sim.FindEncounter(bossName)
  local byEnc = CrusaderStrikeBosses.byEncounterId or {}
  local ids = {}
  for id, row in pairs(byEnc) do
    if row.npcId then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  local needle = bossName and bossName ~= "" and bossName:lower() or nil
  local fallback
  for _, id in ipairs(ids) do
    local row = byEnc[id]
    if needle then
      local n = (row.name or ""):lower()
      if n == needle then
        return id, row
      end
      if not fallback and n:find(needle, 1, true) then
        fallback = id
      end
    elseif row.instanceMapId == DEFAULT_INSTANCE then
      return id, row
    end
  end
  if fallback then
    return fallback, byEnc[fallback]
  end
  if not needle and ids[1] then
    return ids[1], byEnc[ids[1]]
  end
  return nil
end

-- Delete all but the newest MAX_SANDBOX_RUNS simulated runs.
function Sim.PruneSandboxRuns(charDB)
  local sims = {}
  for key, run in pairs(charDB.runs or {}) do
    if run.simulated then
      sims[#sims + 1] = { key = key, t = run.startedAt or 0 }
    end
  end
  table.sort(sims, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.key > b.key
  end)
  for i = MAX_SANDBOX_RUNS + 1, #sims do
    if charDB.activeRunKey ~= sims[i].key then
      charDB.runs[sims[i].key] = nil
    end
  end
end

-- Run fn inside a sandbox run (simulated=true) made active for the duration;
-- afterwards abandon it, prune old sandboxes and restore the previous activeRunKey.
local function with_sandbox(instanceId, instanceName, fn)
  local charDB = CS.GetCharDB()
  local prevKey = charDB.activeRunKey
  local t = now()
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
  local run = CrusaderStrikeRunLifecycle.Start({
    realm = realm,
    character = UnitName("player"),
    gameVersion = CS.GetGameVersion(),
    instanceId = instanceId,
    instanceName = instanceName,
    difficulty = 1,
    difficultyName = "Normal",
    startTimeUnix = t,
    party = CS.DungeonLog.SnapshotParty(),
  })
  run.simulated = true
  -- Keep sandbox keys distinct from any real run started in the same second.
  run.idempotencyKey = "sim-" .. tostring(run.idempotencyKey)
  run.addonRunId = run.idempotencyKey
  charDB.runs[run.idempotencyKey] = run
  charDB.activeRunKey = run.idempotencyKey

  local DL = CS.DungeonLog
  DL._simulating = true
  local ok, res = pcall(fn, run)
  DL._simulating = false

  if run.status == "in_progress" then
    CrusaderStrikeRunLifecycle.Close(run, now())
  end
  -- Sandbox runs end abandoned so they can never be resumed by real play
  -- (ShouldResume also skips run.simulated), and old ones are pruned.
  run.status = "abandoned"
  charDB.runs[run.idempotencyKey] = run
  charDB.activeRunKey = prevKey
  Sim.PruneSandboxRuns(charDB)
  if not ok then
    error(res, 0)
  end
  return res, run
end

function Sim.Kill(bossName)
  if not Sim.IsAllowed() then
    return false, "debug mode is off: /cs debug on first"
  end
  local encounterID, row = Sim.FindEncounter(bossName)
  if not encounterID then
    return false, "no verified encounter matches '" .. tostring(bossName) .. "'"
  end
  local tbl = CrusaderStrikeBosses.GetTable("forever") or {}
  local instName = tbl[row.instanceMapId] and tbl[row.instanceMapId].name or nil
  local recorded, run = with_sandbox(row.instanceMapId, instName, function()
    local onEvent = CS.DungeonLog._onEvent
    onEvent(nil, "ENCOUNTER_END", encounterID, row.name, 1, 5, 1)
    onEvent(nil, "BOSS_KILL", encounterID, row.name)
    return #CS.GetCharDB().runs[CS.GetCharDB().activeRunKey].bosses
  end)
  if recorded == 0 then
    return false, "handlers did not record a kill", run
  end
  return true, string.format("simulated kill: %s (encounter %d) in sandbox run %s",
    tostring(row.name), encounterID, run.idempotencyKey), run
end

function Sim.Death(unit)
  if not Sim.IsAllowed() then
    return false, "debug mode is off: /cs debug on first"
  end
  unit = (unit and unit ~= "") and unit or "player"
  local DL = CS.DungeonLog
  local recorded, run = with_sandbox(DEFAULT_INSTANCE, "Ragefire Chasm", function()
    if unit:lower() == "player" then
      local fresh = CrusaderStrikeDetection.NewDeathTracker(5)
      local real = DL._swapDeathTracker(fresh)
      local okc, r = pcall(DL._onEvent, nil, "PLAYER_DEAD")
      DL._swapDeathTracker(real)
      if not okc then
        error(r, 0)
      end
    elseif unit:match("^party[1-4]$") and UnitExists and UnitExists(unit) then
      DL._recordPartyDeath(unit)
    else
      -- Bare name (or absent party slot): record a death for that name.
      local name = unit:match("^party[1-4]$") and ("Sim" .. unit) or unit
      local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
      DL._recordPartyDeath(unit, name, realm)
    end
    return #CS.GetCharDB().runs[CS.GetCharDB().activeRunKey].deaths
  end)
  if recorded == 0 then
    return false, "handlers did not record a death", run
  end
  local d = run.deaths[#run.deaths]
  return true, string.format("simulated death: %s in sandbox run %s", tostring(d.name), run.idempotencyKey), run
end

function Sim.Command(rest)
  local what, arg = (rest or ""):match("^(%S+)%s*(.-)%s*$")
  what = what and what:lower() or nil
  local ok, msg
  if what == "kill" then
    ok, msg = Sim.Kill(arg)
  elseif what == "death" then
    ok, msg = Sim.Death(arg)
  else
    CS.Print("usage: /cs debug simulate kill [bossName] | death [unit]  (needs /cs debug on)")
    return false
  end
  CS.Print((ok and "" or "simulate failed: ") .. tostring(msg))
  return ok
end

return Sim

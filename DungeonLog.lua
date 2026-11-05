--[[
  Instance detection, party snapshot, boss/death tracking for WoW Forever.

  Forever 1.60.1 runs on the 12.x UI stack: CombatLogGetCurrentEventInfo is not
  callable by addons (missing from Ketho forever GlobalAPI; protected on 12.x).
  Boss kills use ENCOUNTER_END (success=1) / BOSS_KILL with verified DungeonEncounter
  IDs, plus a boss-unit UnitIsDead fallback. Party deaths use PLAYER_DEAD and
  UNIT_HEALTH/UNIT_FLAGS on player/party1-4. CLEU is registered only via pcall and
  never drives production detection (debug probe only).
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.DungeonLog = CS.DungeonLog or {}
local DL = CS.DungeonLog

local deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
local engagedBosses = {} -- [unitToken] = { npcId=..., name=..., guid=... }
local cleuRegistered = false

local function now()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

local function creature_id_from_guid(guid)
  if not guid or type(guid) ~= "string" then
    return nil
  end
  local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if id then
    return tonumber(id)
  end
  id = guid:match("Creature%-.-%-(%d+)%-%x+$")
  return id and tonumber(id) or nil
end

local function unit_name_realm(unit)
  local name, realm = UnitName(unit)
  if not name then
    return nil, nil
  end
  if not realm or realm == "" then
    realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
  end
  return name, realm
end

local function snapshot_party()
  local party = {}
  local function add(unit)
    if not UnitExists(unit) then
      return
    end
    local name, realm = unit_name_realm(unit)
    if not name then
      return
    end
    local className, classFile = UnitClass(unit)
    local level = UnitLevel(unit)
    party[#party + 1] = {
      name = name,
      realm = realm,
      class = classFile or className,
      level = level,
      isPlayer = UnitIsUnit(unit, "player") or false,
    }
  end
  add("player")
  for i = 1, 4 do
    add("party" .. i)
  end
  return party
end

local function in_party_dungeon()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then
    return false
  end
  return instanceType == "party"
end

local function read_instance()
  local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceMapID = GetInstanceInfo()
  return {
    name = name,
    instanceType = instanceType,
    difficulty = difficultyID,
    difficultyName = difficultyName,
    maxPlayers = maxPlayers,
    id = instanceMapID,
  }
end

local function resume_window()
  local accountDB = CS.GetAccountDB()
  return (accountDB and accountDB.settings and accountDB.settings.resumeWindowSec) or (3 * 60 * 60)
end

local function safe_register(frame, event)
  local ok, err = pcall(function()
    frame:RegisterEvent(event)
  end)
  if not ok then
    CS.Debug("RegisterEvent failed: " .. tostring(event) .. " :: " .. tostring(err))
  end
  return ok
end

function DL.ReconcileStale(currentInstanceId)
  local charDB = CS.GetCharDB()
  if not charDB or type(charDB.runs) ~= "table" then
    return
  end
  local result = CrusaderStrikeRunLifecycle.ReconcileStale(charDB.runs, {
    currentInstanceId = currentInstanceId,
    nowUnix = now(),
    resumeWindowSec = resume_window(),
  })
  for _, run in ipairs(result.abandoned) do
    CS.StoreRun(run)
    CS.Debug("Abandoned stale run: " .. tostring(run.idempotencyKey))
  end
  if #result.abandoned > 0 then
    local active = CS.GetActiveRun()
    if not active or active.status ~= "in_progress" then
      CS.ClearActiveRunKey()
    end
  end
  if result.kept then
    CrusaderStrikeRunLifecycle.Touch(result.kept, now())
    CS.StoreRun(result.kept)
  end
  return result
end

function DL.TryStartOrResume()
  if not in_party_dungeon() then
    return
  end
  local inst = read_instance()
  if not inst.id then
    return
  end

  DL.ReconcileStale(inst.id)

  local charDB = CS.GetCharDB()
  local window = resume_window()
  local existing = CS.GetActiveRun()

  if CrusaderStrikeRunLifecycle.ShouldResume(existing, inst.id, now(), window) then
    CrusaderStrikeRunLifecycle.Resume(existing)
    CrusaderStrikeRunLifecycle.Touch(existing, now())
    CS.StoreRun(existing)
    CS.Debug("Resumed run " .. existing.idempotencyKey)
    return
  end

  if not existing or existing.status ~= "in_progress" then
    local best
    for _, run in pairs(charDB.runs or {}) do
      if CrusaderStrikeRunLifecycle.ShouldResume(run, inst.id, now(), window) then
        if not best or (run.startedAt or 0) > (best.startedAt or 0) then
          best = run
        end
      end
    end
    if best then
      CrusaderStrikeRunLifecycle.Resume(best)
      CrusaderStrikeRunLifecycle.Touch(best, now())
      CS.StoreRun(best)
      CS.Debug("Resumed stored run " .. best.idempotencyKey)
      return
    end
  elseif existing and existing.status == "in_progress" and existing.instance.id == inst.id then
    CrusaderStrikeRunLifecycle.Touch(existing, now())
    CS.StoreRun(existing)
    return
  end

  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
  local character = UnitName("player")
  local run = CrusaderStrikeRunLifecycle.Start({
    realm = realm,
    character = character,
    gameVersion = CS.GetGameVersion(),
    instanceId = inst.id,
    instanceName = inst.name,
    difficulty = inst.difficulty,
    difficultyName = inst.difficultyName,
    startTimeUnix = now(),
    party = snapshot_party(),
  })
  CS.StoreRun(run)
  CS.Print(string.format("Logging run: %s", inst.name or tostring(inst.id)))
end

function DL.CloseActive(reason)
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return
  end
  CrusaderStrikeRunLifecycle.Close(run, now())
  CS.StoreRun(run)
  CS.ClearActiveRunKey()
  CS.Debug("Closed run (" .. tostring(reason) .. "): " .. run.idempotencyKey)
end

local function apply_boss_kill(run, npcId, bossName, killedAt)
  if not run or not npcId then
    return false
  end
  if CrusaderStrikeRunLifecycle.RecordBossKill(run, npcId, bossName, killedAt) then
    CS.Debug("Boss kill: " .. tostring(bossName))
    if CrusaderStrikeBosses.IsFinalBoss(run.gameVersion, run.instance.id, npcId) then
      CrusaderStrikeRunLifecycle.MarkCompleted(run, killedAt)
      CS.Print("Dungeon completed: " .. (run.instance.name or ""))
    end
    CS.StoreRun(run)
    return true
  end
  return false
end

-- Primary Forever path: ENCOUNTER_END / BOSS_KILL with verified encounter IDs.
function DL.HandleEncounterEnd(encounterID, encounterName, _difficultyID, _groupSize, success)
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return false
  end
  if CS.DebugEvents then
    CS.DebugEvents.Note("ENCOUNTER_END", now(), {
      encounterID = encounterID,
      encounterName = encounterName,
      success = success,
    })
  end
  if not CrusaderStrikeDetection.EncounterSucceeded(success) then
    CS.Debug("Encounter wipe (not a kill): " .. tostring(encounterName or encounterID))
    return false
  end
  local row = CrusaderStrikeBosses.LookupByEncounter(run.gameVersion, encounterID)
  if not row then
    -- TODO(unverified): encounter fired but no verified npc mapping (e.g. Mana Elemental).
    CS.Debug("Unmapped encounter kill: " .. tostring(encounterID) .. " " .. tostring(encounterName))
    return false
  end
  if row.instanceMapId and run.instance.id and row.instanceMapId ~= run.instance.id then
    CS.Debug("Encounter map mismatch: " .. tostring(row.instanceMapId) .. " vs " .. tostring(run.instance.id))
    return false
  end
  return apply_boss_kill(run, row.npcId, row.name or encounterName, now())
end

function DL.HandleBossKill(encounterID, encounterName)
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return false
  end
  if CS.DebugEvents then
    CS.DebugEvents.Note("BOSS_KILL", now(), {
      encounterID = encounterID,
      encounterName = encounterName,
    })
  end
  local row = CrusaderStrikeBosses.LookupByEncounter(run.gameVersion, encounterID)
  if not row then
    CS.Debug("Unmapped BOSS_KILL: " .. tostring(encounterID) .. " " .. tostring(encounterName))
    return false
  end
  if row.instanceMapId and run.instance.id and row.instanceMapId ~= run.instance.id then
    return false
  end
  return apply_boss_kill(run, row.npcId, row.name or encounterName, now())
end

-- Fallback when encounter events are missing: boss1-5 UnitIsDead after engage.
function DL.RefreshEngagedBosses()
  for i = 1, 5 do
    local unit = "boss" .. i
    if UnitExists and UnitExists(unit) then
      local guid = UnitGUID and UnitGUID(unit)
      local npcId = creature_id_from_guid(guid)
      local name = UnitName and UnitName(unit)
      if npcId then
        engagedBosses[unit] = { npcId = npcId, name = name, guid = guid }
      end
    end
  end
end

function DL.HandleBossUnitDead(unit)
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return false
  end
  local info = engagedBosses[unit]
  if not info or not info.npcId then
    -- Try live read
    if not (UnitExists and UnitExists(unit)) then
      return false
    end
    local guid = UnitGUID and UnitGUID(unit)
    local npcId = creature_id_from_guid(guid)
    if not npcId then
      return false
    end
    info = { npcId = npcId, name = UnitName and UnitName(unit), guid = guid }
    engagedBosses[unit] = info
  end
  local boss = CrusaderStrikeBosses.Lookup(run.gameVersion, run.instance.id, info.npcId)
  if not boss then
    return false
  end
  if CS.DebugEvents then
    CS.DebugEvents.Note("BOSS_UNIT_DEAD", now(), { unit = unit, npcId = info.npcId, name = info.name })
  end
  return apply_boss_kill(run, info.npcId, boss.name or info.name, now())
end

local function record_party_death(unit, name, realm)
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return false
  end
  if not name then
    name, realm = unit_name_realm(unit)
  end
  if not name then
    return false
  end
  CrusaderStrikeRunLifecycle.RecordDeath(run, name, realm, now(), nil)
  CS.StoreRun(run)
  CS.Debug("Death: " .. name)
  if CS.DebugEvents then
    CS.DebugEvents.Note("PARTY_DEATH", now(), { unit = unit, name = name, realm = realm })
  end
  return true
end

-- Poll path: alive->dead edge via UnitIsDeadOrGhost (counts once; rez clears).
function DL.HandlePartyDeath(unit)
  if not (UnitExists and UnitExists(unit)) then
    if deathTracker.dead[unit] then
      CrusaderStrikeDetection.DeathTransition(deathTracker, unit, false, now())
    end
    return false
  end
  local isDead = CrusaderStrikeDetection.IsUnitDeadOrGhost(unit)
  local transition = CrusaderStrikeDetection.DeathTransition(deathTracker, unit, isDead, now())
  if transition ~= "death" then
    return false
  end
  return record_party_death(unit)
end

-- Force a death edge (PLAYER_DEAD), with debounce against Forever double-fire.
function DL.HandlePlayerDeadEvent()
  local name, realm = unit_name_realm("player")
  if not name then
    return false
  end
  local transition = CrusaderStrikeDetection.DeathTransition(deathTracker, "player", true, now())
  if transition ~= "death" then
    return false
  end
  local ok = record_party_death("player", name, realm)
  if ok and CS.DebugEvents then
    CS.DebugEvents.Note("PLAYER_DEAD", now(), { name = name, realm = realm })
  end
  return ok
end

function DL.PollPartyDeathRez()
  for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    DL.HandlePartyDeath(unit)
  end
end

-- Debug / guarded only: never used for production boss/death detection.
function DL.OnCombatLogEventUnfiltered()
  if CS.DebugEvents then
    local ok, info, detail = CrusaderStrikeDetection.TryReadCombatLog()
    CS.DebugEvents.Note("COMBAT_LOG_EVENT_UNFILTERED", now(), {
      cleuCallable = ok,
      detail = detail,
      subevent = info and info.subevent or nil,
    })
  end
end

local frame = CreateFrame("Frame", "CrusaderStrikeDungeonLogFrame")
safe_register(frame, "PLAYER_ENTERING_WORLD")
safe_register(frame, "ZONE_CHANGED_NEW_AREA")
safe_register(frame, "GROUP_ROSTER_UPDATE")
safe_register(frame, "ENCOUNTER_START")
safe_register(frame, "ENCOUNTER_END")
safe_register(frame, "BOSS_KILL")
safe_register(frame, "INSTANCE_ENCOUNTER_ENGAGE_UNIT")
safe_register(frame, "PLAYER_DEAD")
safe_register(frame, "UNIT_HEALTH")
safe_register(frame, "UNIT_FLAGS")
-- CLEU: may error on Forever registration; probe only for /cs debug events.
cleuRegistered = safe_register(frame, "COMBAT_LOG_EVENT_UNFILTERED")

-- UNIT_* needs unit tokens on some clients
if frame.RegisterUnitEvent then
  pcall(function()
    for _, u in ipairs({ "player", "party1", "party2", "party3", "party4", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
      frame:RegisterUnitEvent("UNIT_HEALTH", u)
      frame:RegisterUnitEvent("UNIT_FLAGS", u)
    end
  end)
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    DL.OnCombatLogEventUnfiltered()
  elseif event == "ENCOUNTER_START" then
    if CS.DebugEvents then
      CS.DebugEvents.Note("ENCOUNTER_START", now(), {
        encounterID = arg1,
        encounterName = arg2,
        difficultyID = arg3,
        groupSize = arg4,
      })
    end
    DL.RefreshEngagedBosses()
  elseif event == "ENCOUNTER_END" then
    DL.HandleEncounterEnd(arg1, arg2, arg3, arg4, arg5)
  elseif event == "BOSS_KILL" then
    DL.HandleBossKill(arg1, arg2)
  elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
    if CS.DebugEvents then
      CS.DebugEvents.Note("INSTANCE_ENCOUNTER_ENGAGE_UNIT", now(), {})
    end
    DL.RefreshEngagedBosses()
  elseif event == "PLAYER_DEAD" then
    DL.HandlePlayerDeadEvent()
  elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
    local unit = arg1
    if not unit then
      return
    end
    if unit:match("^boss%d$") then
      if CrusaderStrikeDetection.IsUnitDeadOrGhost(unit) or (UnitIsDead and UnitIsDead(unit)) then
        DL.HandleBossUnitDead(unit)
      end
    elseif unit == "player" or unit:match("^party%d$") then
      DL.PollPartyDeathRez()
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    engagedBosses = {}
    deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
    if in_party_dungeon() then
      DL.TryStartOrResume()
    else
      DL.ReconcileStale(nil)
      DL.CloseActive(event)
      local active = CS.GetActiveRun()
      if active and active.status ~= "in_progress" then
        CS.ClearActiveRunKey()
      end
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    local run = CS.GetActiveRun()
    if run and run.status == "in_progress" then
      run.party = snapshot_party()
      CrusaderStrikeRunLifecycle.Touch(run, now())
      CS.StoreRun(run)
    end
  end
end)

function DL.OnLogin()
  if in_party_dungeon() then
    DL.TryStartOrResume()
  else
    DL.ReconcileStale(nil)
  end
end

function DL.CleuRegistered()
  return cleuRegistered
end

DL.CreatureIdFromGuid = creature_id_from_guid
DL.SnapshotParty = snapshot_party
DL._deathTracker = function()
  return deathTracker
end
DL._resetDeathTracker = function()
  deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
end

--[[
  Instance detection, party snapshot, boss/death tracking for WoW Forever.

  Forever 1.60.1 (12.x): the combat log is off-limits. Registering
  COMBAT_LOG_EVENT_UNFILTERED or calling CombatLogGetCurrentEventInfo triggers
  ADDON_ACTION_BLOCKED; pcall does not hide the popup. This file never touches
  CLEU. Boss kills use ENCOUNTER_END (success=1) / BOSS_KILL with verified
  DungeonEncounter IDs, plus a boss-unit UnitIsDead fallback. Party deaths use
  PLAYER_DEAD and UNIT_HEALTH/UNIT_FLAGS on player/party1-4.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.DungeonLog = CS.DungeonLog or {}
local DL = CS.DungeonLog

local deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
local engagedBosses = {} -- [unitToken] = { npcId=..., name=..., guid=... }

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
  if DL._simulating and not run.simulated then
    return false -- simulations only ever write into their own sandbox run
  end
  if CrusaderStrikeRunLifecycle.RecordBossKill(run, npcId, bossName, killedAt) then
    if DL._simulating then
      run.bosses[#run.bosses].simulated = true
    end
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
  if DL._simulating and not run.simulated then
    return false -- simulations only ever write into their own sandbox run
  end
  CrusaderStrikeRunLifecycle.RecordDeath(run, name, realm, now(), nil)
  if DL._simulating then
    run.deaths[#run.deaths].simulated = true
  end
  CS.StoreRun(run)
  CS.Debug("Death: " .. name)
  if CS.DebugEvents then
    CS.DebugEvents.Note("PARTY_DEATH", now(), { unit = unit, name = name, realm = realm })
  end
  return true
end

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }

-- Stable per-character key so slot shifts (party2 -> party1) don't re-count.
local function death_key(unit)
  local guid = UnitGUID and UnitGUID(unit)
  if guid and guid ~= "" then
    return "guid:" .. guid
  end
  local name, realm = unit_name_realm(unit)
  if name then
    return "name:" .. name .. "-" .. (realm or "")
  end
  return nil
end
DL.DeathKey = death_key

-- Mark already-dead/ghost members as dead WITHOUT recording a death
-- (after /reload, re-zone, or a roster change / join).
function DL.SeedDeathState()
  for _, unit in ipairs(PARTY_UNITS) do
    if UnitExists and UnitExists(unit) then
      local key = death_key(unit)
      if key and CrusaderStrikeDetection.IsUnitDeadOrGhost(unit) then
        deathTracker.dead[key] = true
      end
    end
  end
end

-- Alive->dead edge for one changed unit via UnitIsDeadOrGhost (counts once; rez clears).
function DL.HandlePartyDeath(unit)
  if not (UnitExists and UnitExists(unit)) then
    return false
  end
  local key = death_key(unit)
  if not key then
    return false
  end
  local isDead = CrusaderStrikeDetection.IsUnitDeadOrGhost(unit)
  local transition = CrusaderStrikeDetection.DeathTransition(deathTracker, key, isDead, now())
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
  local key = death_key("player")
  local transition = CrusaderStrikeDetection.DeathTransition(deathTracker, key, true, now())
  if transition ~= "death" then
    return false
  end
  local ok = record_party_death("player", name, realm)
  if ok and CS.DebugEvents then
    CS.DebugEvents.Note("PLAYER_DEAD", now(), { name = name, realm = realm })
  end
  return ok
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

-- UNIT_HEALTH/UNIT_FLAGS only for player, party1-4, boss1-5. Prefer
-- RegisterUnitEvent; otherwise register globally and filter in OnEvent.
local WATCHED_UNITS = {}
for _, u in ipairs({ "player", "party1", "party2", "party3", "party4", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
  WATCHED_UNITS[u] = true
end
DL.WATCHED_UNITS = WATCHED_UNITS


local function on_event(_, event, arg1, arg2, arg3, arg4, arg5, ...)
  if event == "ENCOUNTER_START" then
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
    if not unit or not WATCHED_UNITS[unit] then
      return
    end
    if unit:match("^boss%d$") then
      if CrusaderStrikeDetection.IsUnitDeadOrGhost(unit) or (UnitIsDead and UnitIsDead(unit)) then
        DL.HandleBossUnitDead(unit)
      end
    else
      DL.HandlePartyDeath(unit)
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    engagedBosses = {}
    deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
    DL.SeedDeathState()
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
    DL.SeedDeathState()
    local run = CS.GetActiveRun()
    if run and run.status == "in_progress" then
      run.party = snapshot_party()
      CrusaderStrikeRunLifecycle.Touch(run, now())
      CS.StoreRun(run)
    end
  end
end
frame:SetScript("OnEvent", on_event)

-- RegisterUnitEvent takes at most two units and each call replaces the
-- previous unit filter, so use one small frame per unit pair. If the API is
-- missing or errors, register globally and filter by WATCHED_UNITS in on_event.
local function register_unit_events()
  local units = { "player", "party1", "party2", "party3", "party4", "boss1", "boss2", "boss3", "boss4", "boss5" }
  if frame.RegisterUnitEvent then
    local ok = pcall(function()
      for i = 1, #units, 2 do
        local uf = CreateFrame("Frame")
        uf:RegisterUnitEvent("UNIT_HEALTH", units[i], units[i + 1])
        uf:RegisterUnitEvent("UNIT_FLAGS", units[i], units[i + 1])
        uf:SetScript("OnEvent", on_event)
      end
    end)
    if ok then
      return "unit"
    end
  end
  safe_register(frame, "UNIT_HEALTH")
  safe_register(frame, "UNIT_FLAGS")
  return "global"
end
DL._unitEventMode = register_unit_events()
DL._onEvent = on_event


function DL.OnLogin()
  DL.SeedDeathState()
  if in_party_dungeon() then
    DL.TryStartOrResume()
  else
    DL.ReconcileStale(nil)
  end
end

DL.CreatureIdFromGuid = creature_id_from_guid
DL.SnapshotParty = snapshot_party
DL._deathTracker = function()
  return deathTracker
end
-- /cs debug simulate (addon#22) swaps in a throwaway tracker so a fake
-- PLAYER_DEAD never leaves the real player marked dead.
DL._swapDeathTracker = function(t)
  local old = deathTracker
  deathTracker = t
  return old
end
DL._recordPartyDeath = record_party_death
DL._resetDeathTracker = function()
  deathTracker = CrusaderStrikeDetection.NewDeathTracker(5)
end

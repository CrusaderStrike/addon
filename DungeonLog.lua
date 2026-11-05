--[[
  Instance detection, party snapshot, CLEU boss/death tracking, close/resume/abandon.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.DungeonLog = CS.DungeonLog or {}
local DL = CS.DungeonLog

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
  -- Unit GUID: Creature-0-xxxx-xxxx-xxxx-NPCID-spawn
  local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if id then
    return tonumber(id)
  end
  -- Older / alternate forms
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
  -- Dungeons are "party"; reject raids/pvp for addon#1.
  return instanceType == "party"
end

local function read_instance()
  -- name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID
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

-- Abandon any in_progress run that does not match the current party instance
-- (nil currentInstanceId = outside a dungeon). Persists abandoned rows and clears
-- activeRunKey when the active run was among them.
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

  -- Close leftovers from another dungeon / crash before starting or resuming.
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

  -- Also search recent closed runs for same instance (leave-reenter within window).
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
    return -- already tracking
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

local function on_cleu()
  local run = CS.GetActiveRun()
  if not run or run.status ~= "in_progress" then
    return
  end

  local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags =
    CombatLogGetCurrentEventInfo()

  if subevent ~= "UNIT_DIED" then
    return
  end

  local npcId = creature_id_from_guid(destGUID)
  if npcId then
    local boss, dungeon = CrusaderStrikeBosses.Lookup(run.gameVersion, run.instance.id, npcId)
    if boss then
      local killedAt = now()
      if CrusaderStrikeRunLifecycle.RecordBossKill(run, npcId, boss.name, killedAt) then
        CS.Debug("Boss kill: " .. boss.name)
        if CrusaderStrikeBosses.IsFinalBoss(run.gameVersion, run.instance.id, npcId) then
          CrusaderStrikeRunLifecycle.MarkCompleted(run, killedAt)
          CS.Print("Dungeon completed: " .. (run.instance.name or ""))
        end
        CS.StoreRun(run)
      end
    end
    return
  end

  -- Player death: destGUID Unit- / Player-
  if destGUID and (destGUID:match("^Player%-") or destGUID:match("^Unit%-")) then
    -- Only log if dest is in our party snapshot names (or current group).
    local name = destName
    local realm = run.realm
    if name then
      local n, r = CrusaderStrikeRunLifecycle.SplitNameRealm(name)
      if r then
        name, realm = n, r
      end
    end
    local inParty = false
    for _, p in ipairs(run.party or {}) do
      if p.name == name then
        inParty = true
        realm = p.realm or realm
        break
      end
    end
    -- Also accept current group
    if not inParty then
      if UnitInParty and destName then
        -- Best-effort: match party units by name
        local pname = UnitName("player")
        if CrusaderStrikeRunLifecycle.NameMatches(destName, pname) then
          inParty = true
        end
        for i = 1, 4 do
          local pn = UnitName("party" .. i)
          if CrusaderStrikeRunLifecycle.NameMatches(destName, pn) then
            inParty = true
            break
          end
        end
      end
    end
    if inParty and name then
      CrusaderStrikeRunLifecycle.RecordDeath(run, name, realm, now(), sourceName)
      CS.StoreRun(run)
      CS.Debug("Death: " .. name)
    end
  end
end

local frame = CreateFrame("Frame", "CrusaderStrikeDungeonLogFrame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    on_cleu()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if in_party_dungeon() then
      DL.TryStartOrResume()
    else
      -- Hearth / port / zone change outside the instance: abandon any leftover in_progress.
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
      -- Refresh party snapshot on roster changes (join mid-run).
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
    -- Crash / relog outside the dungeon: abandon stale in_progress runs.
    DL.ReconcileStale(nil)
  end
end

-- Expose pure helpers for tests (mirrors Logic, with GUID parse).
DL.CreatureIdFromGuid = creature_id_from_guid
DL.SnapshotParty = snapshot_party

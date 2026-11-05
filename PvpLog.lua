--[[
  World PvP + battleground capture (WoW Forever only). Event glue over Logic/PvpHistory.lua.

  Forever 1.60.1 is built on the 12.x client. CombatLogGetCurrentEventInfo /
  C_CombatLog.GetCurrentEventInfo are NOT in the Forever global API for addons
  (moved to the secure environment in 12.0; see docs/sources.md). So:
    * honorable kills come from PLAYER_PVP_KILLS_CHANGED (unitTarget payload);
    * pet-only kill exclusion and the killer on death use the
      combat log ONLY when CombatLogGetCurrentEventInfo is callable (pcall), and
      otherwise degrade gracefully (HK credit = "kill", killer from target).
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.PvpLog = CS.PvpLog or {}
local PL = CS.PvpLog
local P = CrusaderStrikePvp

local KB_WINDOW_SEC = 3        -- our killing blow must precede HK credit by <= this
local ATTACKER_WINDOW_SEC = 10 -- last enemy player hit before PLAYER_DEAD

local state = {
  inDuel = false,
  duelEndedAt = nil,
  killingBlows = {},   -- [destGUID] = { t, byPet }
  lastAttacker = nil,  -- { guid, name, t }
}
PL._state = state

local function now()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

local function ident()
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
  return { realm = realm, character = UnitName("player") }
end

local function pvp_db()
  local charDB = CS.GetCharDB()
  if not charDB then
    return nil
  end
  return P.Ensure(charDB)
end

local function zone_pvp_type()
  if C_PvP and C_PvP.GetZonePVPInfo then
    return (C_PvP.GetZonePVPInfo())
  end
  if GetZonePVPInfo then
    return (GetZonePVPInfo())
  end
  return nil
end

local function context()
  local inInstance = IsInInstance()
  return {
    now = now(),
    inInstance = inInstance and true or false,
    pvpZoneType = zone_pvp_type(),
    inDuel = state.inDuel,
    duelEndedAt = state.duelEndedAt,
    zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or nil,
    subzone = GetSubZoneText and GetSubZoneText() or nil,
  }
end

function PL.HasCombatLog()
  if type(CombatLogGetCurrentEventInfo) ~= "function" then
    return false
  end
  return (pcall(CombatLogGetCurrentEventInfo))
end

local function split_name(full)
  if not full then return nil, nil end
  local n, r = full:match("^([^%-]+)%-(.+)$")
  if n then return n, r end
  return full, nil
end

local function opponent_from_unit(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  local name, realm = UnitName(unit)
  local _, classFile = UnitClass(unit)
  local level = UnitLevel(unit)
  return {
    opponentName = name,
    opponentRealm = (realm ~= "" and realm) or nil,
    opponentClass = classFile,
    opponentLevel = (level and level > 0) and level or nil, -- -1 = skull / unknown
    opponentFaction = UnitFactionGroup and UnitFactionGroup(unit) or nil,
    opponentIsPlayer = UnitIsPlayer(unit) and true or false,
    opponentGUID = UnitGUID and UnitGUID(unit) or nil,
  }
end

local function opponent_from_guid(guid, fallbackName)
  local ev = { opponentName = fallbackName, opponentIsPlayer = guid and guid:match("^Player%-") ~= nil }
  if guid and GetPlayerInfoByGUID then
    local _, classFile, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
    ev.opponentClass = classFile
    ev.opponentName = name or fallbackName
    ev.opponentRealm = (realm and realm ~= "") and realm or nil
  end
  if ev.opponentName and not ev.opponentRealm then
    ev.opponentName, ev.opponentRealm = split_name(ev.opponentName)
  end
  return ev
end

local function record_world(ev)
  local db = pvp_db()
  if not db then return nil end
  local rec, reason = P.RecordWorld(db, ident(), ev, context())
  if rec then
    CS.Debug("PvP " .. rec.result .. ": " .. tostring(rec.opponent.name))
  else
    CS.Debug("PvP event skipped: " .. tostring(reason))
  end
  return rec, reason
end

-- PLAYER_PVP_KILLS_CHANGED: honorable kill credit (killing blow or group credit).
function PL.OnHonorableKill(unitTarget)
  local ev = opponent_from_unit(unitTarget) or {}
  ev.honorable = true
  ev.result = "kill"
  if PL.HasCombatLog() and ev.opponentGUID then
    -- Only used to drop pet-only killing blows; HK credit is always recorded as "kill".
    local kb = state.killingBlows[ev.opponentGUID]
    if kb and (now() - kb.t) <= KB_WINDOW_SEC then
      ev.killerIsPet = kb.byPet
    end
  end
  return record_world(ev)
end

function PL.OnPlayerDead()
  local ev
  local a = state.lastAttacker
  if a and (now() - a.t) <= ATTACKER_WINDOW_SEC then
    ev = opponent_from_guid(a.guid, a.name)
    ev.opponentIsPet = a.isPet
    ev.killerSource = "combat_log"
  elseif UnitIsPlayer("target") and UnitIsEnemy and UnitIsEnemy("player", "target") then
    ev = opponent_from_unit("target") -- no combat log: best effort from target
    ev.killerSource = "target"
  else
    return nil, "no_player_killer"
  end
  ev.result = "death"
  ev.honorable = false
  state.lastAttacker = nil
  return record_world(ev)
end

local function prune_killing_blows(t)
  for guid, kb in pairs(state.killingBlows) do
    if (t - kb.t) > KB_WINDOW_SEC then
      state.killingBlows[guid] = nil
    end
  end
end
PL._pruneKillingBlows = prune_killing_blows

local function on_cleu()
  local ok, _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID =
    pcall(CombatLogGetCurrentEventInfo)
  if not ok or not subevent then return end
  local me = UnitGUID and UnitGUID("player")
  local pet = UnitGUID and UnitGUID("pet")
  if subevent == "PARTY_KILL" and destGUID and destGUID:match("^Player%-")
    and (sourceGUID == me or (pet and sourceGUID == pet)) then
    local t = now()
    prune_killing_blows(t)
    state.killingBlows[destGUID] = { t = t, byPet = sourceGUID ~= me }
  elseif destGUID == me and sourceGUID and subevent:match("_DAMAGE$") then
    local isPlayer = sourceGUID:match("^Player%-") ~= nil
    local isPet = sourceGUID:match("^Pet%-") ~= nil
    if isPlayer or isPet then
      state.lastAttacker = { guid = sourceGUID, name = sourceName, t = now(), isPet = isPet }
    end
  end
end

-- Battlegrounds ---------------------------------------------------------------

local function in_battleground()
  local inInstance, instanceType = IsInInstance()
  if not inInstance or instanceType ~= "pvp" then
    return false
  end
  if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
    return false
  end
  return true
end

local function player_score_row()
  local guid = UnitGUID and UnitGUID("player")
  if C_PvP and C_PvP.GetScoreInfoByPlayerGuid and guid then
    local row = C_PvP.GetScoreInfoByPlayerGuid(guid)
    if row then return row end
  end
  if C_PvP and C_PvP.GetScoreInfo and GetNumBattlefieldScores then
    local me = UnitName("player")
    for i = 1, GetNumBattlefieldScores() do
      local row = C_PvP.GetScoreInfo(i)
      if row and (row.name == me or split_name(row.name) == me) then
        return row
      end
    end
  end
  return nil
end

local function match_winner()
  local w = GetBattlefieldWinner and GetBattlefieldWinner() or nil
  if w == nil and C_PvP and C_PvP.GetActiveMatchWinner and C_PvP.GetActiveMatchState
    and Enum and Enum.PvPMatchState and C_PvP.GetActiveMatchState() == Enum.PvPMatchState.Complete then
    w = C_PvP.GetActiveMatchWinner()
  end
  return w
end

function PL.CheckBattleground()
  local db = pvp_db()
  if not db then return end
  if in_battleground() then
    local name, _, _, _, _, _, _, mapId = GetInstanceInfo()
    P.StartBattleground(db, ident(), {
      mapId = mapId, mapName = name, faction = UnitFactionGroup("player"), now = now(),
    })
  elseif db.activeBattleground or db.finishedBattleground then
    -- Left early, deserted, or logged back in after a disconnect (no-op for a
    -- finished match other than clearing the finished marker).
    local active = db.activeBattleground
    local rec = P.ExitedBattleground(db, active and active.lastSeenAt or now())
    if rec then CS.Debug("BG left early: " .. rec.addon_pvp_id) end
  end
end

function PL.OnScoreUpdate()
  local db = pvp_db()
  if not db or not db.activeBattleground then return end
  db.activeBattleground.lastSeenAt = now()
  P.UpdateScore(db, player_score_row())
  local winner = match_winner()
  if winner ~= nil then
    local runMs = GetBattlefieldInstanceRunTime and GetBattlefieldInstanceRunTime() or nil
    local rec = P.FinishBattleground(db, winner, now(), (runMs and runMs > 0) and runMs / 1000 or nil)
    if rec then
      CS.Print(string.format("Battleground %s: %s", rec.mapName or "?", rec.result))
    end
  end
end

function PL.Summary()
  local db = pvp_db()
  if not db then return { "No PvP data yet." } end
  return P.FormatSummary(db, 5)
end

local handlers = {
  PLAYER_PVP_KILLS_CHANGED = function(unit) PL.OnHonorableKill(unit) end,
  PLAYER_DEAD = function() PL.OnPlayerDead() end,
  COMBAT_LOG_EVENT_UNFILTERED = on_cleu,
  DUEL_REQUESTED = function() state.inDuel = true end,
  DUEL_INBOUNDS = function() state.inDuel = true end,
  DUEL_FINISHED = function() state.inDuel = false; state.duelEndedAt = now() end,
  PLAYER_ENTERING_WORLD = function() PL.CheckBattleground() end,
  ZONE_CHANGED_NEW_AREA = function() PL.CheckBattleground() end,
  UPDATE_BATTLEFIELD_STATUS = function() PL.CheckBattleground() end,
  UPDATE_BATTLEFIELD_SCORE = function() PL.OnScoreUpdate() end,
  PVP_MATCH_COMPLETE = function()
    if RequestBattlefieldScoreData then RequestBattlefieldScoreData() end
    PL.OnScoreUpdate()
  end,
}

function PL.HandleEvent(event, ...)
  local fn = handlers[event]
  if not fn then return end
  local ok, err = pcall(fn, ...)
  if not ok then
    CS.Debug("PvP handler error (" .. event .. "): " .. tostring(err))
  end
end

local frame = CreateFrame("Frame", "CrusaderStrikePvpLogFrame")
for event in pairs(handlers) do
  -- CLEU payload isn't readable by addons on Forever 1.60.1; only listen when it is.
  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or PL.HasCombatLog() then
    frame:RegisterEvent(event)
  end
end
PL._frame = frame
frame:SetScript("OnEvent", function(_, event, ...)
  PL.HandleEvent(event, ...)
end)

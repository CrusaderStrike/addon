--[[
  World PvP + battleground capture (WoW Forever only). Event glue over Logic/PvpHistory.lua.

  Forever 1.60.1 (12.x): the combat log is never used. Registering
  COMBAT_LOG_EVENT_UNFILTERED or calling CombatLogGetCurrentEventInfo triggers
  ADDON_ACTION_BLOCKED (pcall does not suppress the popup). So:
    * honorable kills come from PLAYER_PVP_KILLS_CHANGED (unitTarget payload);
    * pet-only kills cannot be excluded;
    * killer on death comes only from the current enemy-player target
      (killer_source = "target"; schema still allows "combat_log" but it is unused).
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.PvpLog = CS.PvpLog or {}
local PL = CS.PvpLog
local P = CrusaderStrikePvp

local state = {
  inDuel = false,
  duelEndedAt = nil,
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
  -- No combat log: cannot distinguish pet-only kills; every HK credit is "kill".
  return record_world(ev)
end

function PL.OnPlayerDead()
  -- No combat log: killer comes only from the current enemy-player target.
  -- Schema still allows killer_source="combat_log" but Forever never sets it.
  if not (UnitIsPlayer("target") and UnitIsEnemy and UnitIsEnemy("player", "target")) then
    return nil, "no_player_killer"
  end
  local ev = opponent_from_unit("target")
  ev.killerSource = "target"
  ev.result = "death"
  ev.honorable = false
  return record_world(ev)
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
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever treats it as Blizzard-UI-only.
for event in pairs(handlers) do
  frame:RegisterEvent(event)
end
PL._frame = frame
frame:SetScript("OnEvent", function(_, event, ...)
  PL.HandleEvent(event, ...)
end)

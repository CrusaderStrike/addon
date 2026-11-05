-- Pure world PvP / battleground history logic. Safe to unit-test without WoW APIs.
-- Storage lives in CrusaderStrikeCharDB.pvp (see docs/pvp-schema.md):
--   pvp.world[]          oldest first, capped at WORLD_CAP
--   pvp.battlegrounds[]  oldest first, capped at BG_CAP
--   pvp.activeBattleground  in-progress match (survives /reload and disconnects)
-- Every record has a stable addon_pvp_id (same pattern as addon_run_id) and a
-- synced flag that a future uploader sets via MarkSynced.

CrusaderStrikePvp = CrusaderStrikePvp or {}
local P = CrusaderStrikePvp

P.RECORD_VERSION = 1
P.WORLD_CAP = 1000
P.BG_CAP = 500
-- Deaths/kills within this many seconds after DUEL_FINISHED are treated as duel noise.
P.DUEL_GRACE_SEC = 3

local SEP = "|"

-- No "assist": Forever 1.60.1 addons can't read the combat log, so killing blow
-- vs assist is unknowable. Re-add if a later build makes the payload readable.
local VALID_WORLD_RESULTS = { kill = true, death = true }
local VALID_KILLER_SOURCES = { target = true, combat_log = true }

-- Faction index used by the scoreboard / GetBattlefieldWinner: 0 Horde, 1 Alliance.
local FACTION_INDEX = { horde = 0, alliance = 1 }

-- Platform contract (OpenAPI Character.faction): "alliance" | "horde" | nil.
function P.NormalizeFaction(f)
  if type(f) ~= "string" then return nil end
  f = f:lower()
  if f == "alliance" or f == "horde" then return f end
  return nil
end
P.WINNER_DRAW = 255

function P.Ensure(charDB)
  charDB.pvp = charDB.pvp or {}
  local pvp = charDB.pvp
  pvp.world = pvp.world or {}
  pvp.battlegrounds = pvp.battlegrounds or {}
  -- pvp.finishedBattleground = { addon_pvp_id, mapId } while still inside an ended match
  pvp.seq = pvp.seq or 0
  return pvp
end

-- World id: realm|character|W|timeUnix|result|seq
-- seq is a per-character counter so two events in the same second never collide;
-- once written the id never changes, so a sync can deduplicate on it.
-- (No opponent name in the id: keeps other players' names out of indexed keys.)
function P.MakeWorldId(realm, character, timeUnix, result, seq)
  assert(realm and realm ~= "", "realm required")
  assert(character and character ~= "", "character required")
  assert(type(timeUnix) == "number", "timeUnix must be number")
  return table.concat({
    tostring(realm), tostring(character), "W",
    tostring(math.floor(timeUnix)), tostring(result), tostring(seq or 0),
  }, SEP)
end

-- BG id: realm|character|BG|startTimeUnix|mapId  (mirrors addon_run_id)
function P.MakeBattlegroundId(realm, character, startTimeUnix, mapId)
  assert(realm and realm ~= "", "realm required")
  assert(character and character ~= "", "character required")
  assert(type(startTimeUnix) == "number", "startTimeUnix must be number")
  return table.concat({
    tostring(realm), tostring(character), "BG",
    tostring(math.floor(startTimeUnix)), tostring(mapId or "?"),
  }, SEP)
end

local function trim(list, cap)
  local dropped = 0
  while #list > cap do
    table.remove(list, 1)
    dropped = dropped + 1
  end
  return dropped
end

-- ctx: { inInstance, pvpZoneType, inDuel, duelEndedAt, now }
-- ev:  { result, opponentName, opponentIsPlayer, opponentIsPet, killerIsPet }
-- Returns (true) or (false, reason).
function P.ShouldRecordWorld(ev, ctx)
  if not ev or not VALID_WORLD_RESULTS[ev.result] then
    return false, "bad_result"
  end
  if ctx.inInstance then
    return false, "instance"
  end
  if ctx.pvpZoneType == "sanctuary" then
    return false, "sanctuary"
  end
  if ctx.inDuel then
    return false, "duel"
  end
  if ctx.duelEndedAt and ctx.now and (ctx.now - ctx.duelEndedAt) <= P.DUEL_GRACE_SEC then
    return false, "duel"
  end
  if ev.opponentIsPet then
    return false, "pet" -- the victim/killer was a pet, not a player
  end
  if ev.killerIsPet and ev.result ~= "death" then
    return false, "pet" -- our pet alone got the kill
  end
  if ev.opponentIsPlayer == false then
    return false, "not_player"
  end
  return true
end

-- Appends a world event. ident = { realm, character }. Returns record or nil, reason.
function P.RecordWorld(pvp, ident, ev, ctx)
  local okRec, reason = P.ShouldRecordWorld(ev, ctx)
  if not okRec then
    return nil, reason
  end
  pvp.seq = (pvp.seq or 0) + 1
  local t = math.floor(ctx.now)
  local rec = {
    v = P.RECORD_VERSION,
    addon_pvp_id = P.MakeWorldId(ident.realm, ident.character, t, ev.result, pvp.seq),
    time = t,
    zone = ctx.zone,
    subzone = (ctx.subzone ~= "" and ctx.subzone) or nil,
    result = ev.result,
    honorable = ev.honorable and true or false,
    -- deaths only: how the killer was identified ("target" | "combat_log"), nil = unknown
    killer_source = (ev.result == "death" and VALID_KILLER_SOURCES[ev.killerSource]) and ev.killerSource or nil,
    opponent = {
      name = ev.opponentName,
      realm = ev.opponentRealm,
      class = ev.opponentClass,
      level = ev.opponentLevel,
      faction = P.NormalizeFaction(ev.opponentFaction),
    },
    synced = false,
  }
  table.insert(pvp.world, rec)
  trim(pvp.world, P.WORLD_CAP)
  return rec
end

-- info: { mapId, mapName, faction ("Horde"/"Alliance"), now }
-- Returns the active record, or nil when this instance's match already finished
-- (pvp.finishedBattleground marker, cleared by P.ExitedBattleground).
function P.StartBattleground(pvp, ident, info)
  local done = pvp.finishedBattleground
  if done and done.mapId == info.mapId then
    return nil
  end
  local existing = pvp.activeBattleground
  if existing and existing.mapId == info.mapId then
    return existing -- /reload inside the same match resumes it
  end
  if existing then
    P.LeaveBattleground(pvp, info.now)
  end
  local t = math.floor(info.now)
  local bg = {
    v = P.RECORD_VERSION,
    addon_pvp_id = P.MakeBattlegroundId(ident.realm, ident.character, t, info.mapId),
    mapId = info.mapId,
    mapName = info.mapName,
    faction = P.NormalizeFaction(info.faction),
    startedAt = t,
    endedAt = nil,
    durationSec = nil,
    result = nil,
    stats = { killingBlows = 0, honorableKills = 0, deaths = 0, honor = 0 },
    synced = false,
  }
  pvp.activeBattleground = bg
  return bg
end

-- row: a PVPScoreInfo-like table for the player (C_PvP.GetScoreInfo*).
function P.UpdateScore(pvp, row)
  local bg = pvp.activeBattleground
  if not bg or type(row) ~= "table" then
    return false
  end
  bg.stats = {
    killingBlows = tonumber(row.killingBlows) or bg.stats.killingBlows or 0,
    honorableKills = tonumber(row.honorableKills) or bg.stats.honorableKills or 0,
    deaths = tonumber(row.deaths) or bg.stats.deaths or 0,
    honor = tonumber(row.honorGained) or bg.stats.honor or 0,
  }
  return true
end

local function finalize(pvp, bg, endedAt, result, winner)
  bg.endedAt = math.floor(endedAt)
  bg.durationSec = math.max(0, bg.endedAt - bg.startedAt)
  bg.result = result
  bg.winner = winner
  table.insert(pvp.battlegrounds, bg)
  trim(pvp.battlegrounds, P.BG_CAP)
  pvp.activeBattleground = nil
  return bg
end

-- Called when the player is no longer inside a BG instance.
function P.ExitedBattleground(pvp, endedAt)
  pvp.finishedBattleground = nil
  return P.LeaveBattleground(pvp, endedAt)
end

-- winner: GetBattlefieldWinner() / C_PvP.GetActiveMatchWinner() (0 Horde, 1 Alliance, 255 draw).
function P.FinishBattleground(pvp, winner, endedAt, durationSec)
  local bg = pvp.activeBattleground
  if not bg then
    return nil
  end
  local result
  local mine = FACTION_INDEX[bg.faction]
  if winner == nil then
    result = "left"
  elseif winner == P.WINNER_DRAW then
    result = "draw"
  elseif mine ~= nil and winner == mine then
    result = "win"
  else
    result = "loss"
  end
  local rec = finalize(pvp, bg, endedAt, result, winner)
  -- Stay "finished" for this instance until the player leaves it, so post-end
  -- scoreboard/status events (and a /reload) can't open or close a second record.
  pvp.finishedBattleground = { addon_pvp_id = rec.addon_pvp_id, mapId = rec.mapId }
  if durationSec then
    rec.durationSec = math.floor(durationSec)
  end
  return rec
end

-- Leaving early, being kicked, or disconnecting: keeps partial stats.
function P.LeaveBattleground(pvp, endedAt)
  local bg = pvp.activeBattleground
  if not bg then
    return nil
  end
  return finalize(pvp, bg, endedAt or bg.startedAt, "left", nil)
end

function P.MarkSynced(pvp, ids)
  local want = {}
  for _, id in ipairs(ids or {}) do
    want[id] = true
  end
  local n = 0
  for _, list in ipairs({ pvp.world, pvp.battlegrounds }) do
    for _, rec in ipairs(list) do
      if want[rec.addon_pvp_id] and not rec.synced then
        rec.synced = true
        n = n + 1
      end
    end
  end
  return n
end

function P.Summary(pvp, recentN)
  recentN = recentN or 5
  local s = { kills = 0, deaths = 0, wins = 0, losses = 0, left = 0, draws = 0, recent = {} }
  for _, r in ipairs(pvp.world or {}) do
    if r.result == "kill" then s.kills = s.kills + 1
    elseif r.result == "death" then s.deaths = s.deaths + 1 end
  end
  for _, b in ipairs(pvp.battlegrounds or {}) do
    if b.result == "win" then s.wins = s.wins + 1
    elseif b.result == "loss" then s.losses = s.losses + 1
    elseif b.result == "draw" then s.draws = s.draws + 1
    else s.left = s.left + 1 end
  end
  local w = pvp.world or {}
  for i = #w, math.max(1, #w - recentN + 1), -1 do
    s.recent[#s.recent + 1] = w[i]
  end
  return s
end

function P.FormatSummary(pvp, recentN)
  local s = P.Summary(pvp, recentN)
  local lines = {
    string.format("World PvP: %d kills, %d deaths", s.kills, s.deaths),
    string.format("Battlegrounds: %d W / %d L (%d left early%s)", s.wins, s.losses, s.left,
      s.draws > 0 and (", " .. s.draws .. " draws") or ""),
  }
  for _, r in ipairs(s.recent) do
    local o = r.opponent or {}
    lines[#lines + 1] = string.format("  %s %s %s%s in %s", r.result,
      o.name or "unknown", o.level and ("(" .. o.level .. " ") or "(",
      (o.class or "?") .. ")", r.subzone or r.zone or "?")
  end
  return lines
end

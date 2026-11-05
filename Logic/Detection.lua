-- Pure detection helpers for Forever (no combat-log dependency).
-- WoW-facing code supplies events and unit polls; this module is unit-tested.

CrusaderStrikeDetection = CrusaderStrikeDetection or {}

-- ENCOUNTER_END success: 1 = kill, 0 = wipe. Wipes must not count as kills.
function CrusaderStrikeDetection.EncounterSucceeded(success)
  return success == 1 or success == true
end

-- Combat log is NOT used on Forever 1.60.1. COMBAT_LOG_EVENT_UNFILTERED
-- registration and CombatLogGetCurrentEventInfo both trigger
-- ADDON_ACTION_BLOCKED ("blocked from an action only available to the Blizzard UI").
-- pcall does not suppress that popup. Boss/death detection uses ENCOUNTER_*,
-- BOSS_KILL, PLAYER_DEAD, and UNIT_HEALTH/UNIT_FLAGS only.

-- Party / player death tracker: count each death once; release+rez must not
-- double-count while the unit stays dead/ghost. PLAYER_DEAD may fire twice on
-- Forever (forever-lint FL013); debounceSec suppresses the echo.
function CrusaderStrikeDetection.NewDeathTracker(debounceSec)
  return {
    debounceSec = debounceSec or 5,
    dead = {}, -- [key] = true while UnitIsDeadOrGhost
    lastDeathAt = {}, -- [key] = unix for debounce
  }
end

-- key: stable id (e.g. "player" or "party1" or "name:Realm")
-- isDead: current UnitIsDeadOrGhost (or PLAYER_DEAD force)
-- now: unix seconds
-- Returns: "death" | "rez" | nil
function CrusaderStrikeDetection.DeathTransition(tracker, key, isDead, now)
  if not tracker or not key then
    return nil
  end
  now = now or 0
  local wasDead = tracker.dead[key] and true or false
  if isDead and not wasDead then
    local last = tracker.lastDeathAt[key] or 0
    if now > 0 and (now - last) < (tracker.debounceSec or 5) then
      tracker.dead[key] = true
      return nil -- echo / duplicate
    end
    tracker.dead[key] = true
    tracker.lastDeathAt[key] = now
    return "death"
  elseif isDead and wasDead then
    return nil
  elseif (not isDead) and wasDead then
    tracker.dead[key] = nil
    return "rez"
  end
  return nil
end

function CrusaderStrikeDetection.IsUnitDeadOrGhost(unit)
  if UnitIsDeadOrGhost then
    return UnitIsDeadOrGhost(unit) and true or false
  end
  if UnitIsDead and UnitIsDead(unit) then
    return true
  end
  return false
end

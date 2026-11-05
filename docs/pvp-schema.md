# Crusader Strike PvP history schema (groomed ticket A)

World of Warcraft: Forever only. Captured locally by `PvpLog.lua` + `Logic/PvpHistory.lua`
into `CrusaderStrikeCharDB.pvp`. Nothing is uploaded yet; the World PvP rankings sync
will read these records later.

**SavedVariables `schemaVersion`: `2`** (was `1`; v2 adds `pvp`). The dungeon-run export
payload in [run-schema.md](run-schema.md) keeps its own `schemaVersion: 1` and is unchanged.
Each PvP record also carries `v: 1` (record format version).

## Layout

```lua
CrusaderStrikeCharDB.pvp = {
  seq = 42,                -- per-character counter used in world ids
  world = { ... },         -- oldest first, capped at 1000
  battlegrounds = { ... }, -- oldest first, capped at 500
  activeBattleground = nil, -- in-progress match; survives /reload and disconnects
  finishedBattleground = nil -- { addon_pvp_id, mapId } while still inside an ended match
}
```

When a list exceeds its cap the **oldest** records are dropped first. Every record has
`synced = false` until the uploader acknowledges it (`CrusaderStrikePvp.MarkSynced(pvp, ids)`
sets `synced = true`).

## Dedupe ids (`addon_pvp_id`)

Same pattern as `addon_run_id` (pipe-separated, stable once written):

| Kind | Format | Example |
|------|--------|---------|
| World | `{realm}\|{character}\|W\|{timeUnix}\|{result}\|{seq}` | `Ironhollow\|Aldric\|W\|1730000000\|kill\|1` |
| Battleground | `{realm}\|{character}\|BG\|{startTimeUnix}\|{instanceMapID}` | `Ironhollow\|Aldric\|BG\|1730000000\|489` |

`seq` keeps two events in the same second distinct. No opponent name or GUID is part of any id, and opponent GUIDs are never stored.

## World record (`pvp.world[]`)

| Field | Type | Notes |
|-------|------|-------|
| `v` | int | `1` |
| `addon_pvp_id` | string | See above |
| `time` | int | `GetServerTime()` |
| `zone` / `subzone` | string/null | `GetRealZoneText()` / `GetSubZoneText()` |
| `result` | string | `kill` \| `death` (no `assist` on Forever; see limits) |
| `honorable` | bool | `true` for honorable-kill credit (`PLAYER_PVP_KILLS_CHANGED`); deaths are `false` |
| `killer_source` | string/null | Deaths only: `"target"` when the killer is the player's current enemy-player target (`"combat_log"` reserved for a build where the combat log is readable); null on kills or when unknown |
| `opponent.name` / `.realm` | string/null | |
| `opponent.class` | string/null | Class token, e.g. `WARRIOR` |
| `opponent.level` | int/null | null when the client hides it (skull) |
| `opponent.faction` | string/null | `alliance` \| `horde` \| null (lowercase, platform `Character.faction`) |
| `synced` | bool | |

Excluded: anything inside an instance (BGs are tracked separately), sanctuary zones
(`C_PvP.GetZonePVPInfo() == "sanctuary"`), events during a duel or within 3 s of
`DUEL_FINISHED`, kills of pets/non-players, and kills where only our pet landed the
killing blow (needs the combat log, see limitations).

## Battleground record (`pvp.battlegrounds[]`)

| Field | Type | Notes |
|-------|------|-------|
| `v` | int | `1` |
| `addon_pvp_id` | string | See above |
| `mapId` / `mapName` | int / string | `GetInstanceInfo()` instanceMapID and name |
| `faction` | string/null | `alliance` \| `horde` \| null, lowercased from `UnitFactionGroup("player")` |
| `startedAt` / `endedAt` | int | Unix seconds |
| `durationSec` | int | `GetBattlefieldInstanceRunTime()/1000` when available, else `endedAt - startedAt` |
| `result` | string | `win` \| `loss` \| `left` (also `draw` when the winner is 255) |
| `winner` | int/null | 0 Horde, 1 Alliance, 255 draw; null when `left` |
| `stats.killingBlows` / `honorableKills` / `deaths` / `honor` | int | Player's scoreboard row (`C_PvP.GetScoreInfoByPlayerGuid`, fallback `C_PvP.GetScoreInfo` loop); partial when `left` |
| `synced` | bool | |

Once a match ends it stays finished (`finishedBattleground`, same `addon_pvp_id`) until
the player leaves the BG instance, so post-end scoreboard refreshes, status/zone events
and a `/reload` can't open or close a second record. `honor` reads `PVPScoreInfo.honorGained`
(confirmed in the Forever `PvpInfoDocumentation.lua`, see docs/sources.md).

Leaving early, deserting, or disconnecting and logging back in outside the BG finalizes
the active match as `left` with the last scoreboard row seen. Logging back into the
same match resumes it.

## Forever client limitations (accepted by PM)

Forever 1.60.1 is built on the 12.x client, where the combat-log payload getter
(`CombatLogGetCurrentEventInfo` / `C_CombatLog.GetCurrentEventInfo`) is not exposed
to addons. PM accepted these limits for ticket A:

- **(a)** Kills and assists can't be told apart: every honorable-kill credit is `kill`, and there is no `assist` result.
- **(b)** Pet-only kills can't be excluded.
- **(c)** Dishonorable kills (no honor credit) aren't recorded.
- **(d)** The killer on a death only comes from the player's current target (`killer_source = "target"`); deaths with no enemy-player target aren't recorded.

The addon never registers `COMBAT_LOG_EVENT_UNFILTERED` and never calls
`CombatLogGetCurrentEventInfo` (both trigger ADDON_ACTION_BLOCKED on Forever).
`killer_source = "combat_log"` remains schema-valid but unused. Revisit if a later
Forever build unprotects the combat log.

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
  activeBattleground = nil -- in-progress match; survives /reload and disconnects
}
```

When a list exceeds its cap the **oldest** records are dropped first. Every record has
`synced = false` until the uploader acknowledges it (`CrusaderStrikePvp.MarkSynced(pvp, ids)`
sets `synced = true`).

## Dedupe ids (`addon_pvp_id`)

Same pattern as `addon_run_id` (pipe-separated, stable once written):

| Kind | Format | Example |
|------|--------|---------|
| World | `{realm}\|{character}\|W\|{timeUnix}\|{result}\|{opponent}\|{seq}` | `Ironhollow\|Aldric\|W\|1730000000\|kill\|Grukk\|1` |
| Battleground | `{realm}\|{character}\|BG\|{startTimeUnix}\|{instanceMapID}` | `Ironhollow\|Aldric\|BG\|1730000000\|489` |

`opponent` is `?` when unknown. `seq` keeps two events in the same second distinct.

## World record (`pvp.world[]`)

| Field | Type | Notes |
|-------|------|-------|
| `v` | int | `1` |
| `addon_pvp_id` | string | See above |
| `time` | int | `GetServerTime()` |
| `zone` / `subzone` | string/null | `GetRealZoneText()` / `GetSubZoneText()` |
| `result` | string | `kill` \| `death` \| `assist` |
| `honorable` | bool | `true` for honorable-kill credit (`PLAYER_PVP_KILLS_CHANGED`); deaths are `false` |
| `opponent.name` / `.realm` | string/null | |
| `opponent.class` | string/null | Class token, e.g. `WARRIOR` |
| `opponent.level` | int/null | null when the client hides it (skull) |
| `opponent.faction` | string/null | `Horde` / `Alliance` |
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
| `faction` | string | `UnitFactionGroup("player")` |
| `startedAt` / `endedAt` | int | Unix seconds |
| `durationSec` | int | `GetBattlefieldInstanceRunTime()/1000` when available, else `endedAt - startedAt` |
| `result` | string | `win` \| `loss` \| `left` (also `draw` when the winner is 255) |
| `winner` | int/null | 0 Horde, 1 Alliance, 255 draw; null when `left` |
| `stats.killingBlows` / `honorableKills` / `deaths` / `honor` | int | Player's scoreboard row (`C_PvP.GetScoreInfoByPlayerGuid`, fallback `C_PvP.GetScoreInfo` loop); partial when `left` |
| `synced` | bool | |

Leaving early, deserting, or disconnecting and logging back in outside the BG finalizes
the active match as `left` with the last scoreboard row seen. Logging back into the
same match resumes it.

## Forever client limitations

Forever 1.60.1 is built on the 12.x client, where the combat-log payload getter
(`CombatLogGetCurrentEventInfo` / `C_CombatLog.GetCurrentEventInfo`) is not exposed
to addons. Without it:

- every honorable-kill credit is recorded as `kill` (killing blow vs `assist` can't be told apart);
- pet-only killing blows can't be excluded;
- the killer on a death is taken from the player's current target when it's an enemy
  player; deaths with no identifiable enemy player are not recorded;
- dishonorable kills (no honor credit) aren't recorded.

The code uses the combat log automatically if `CombatLogGetCurrentEventInfo` is callable.

<p align="center"><img src="assets/logo.svg" alt="Crusader Strike logo" width="160"></p>

# CrusaderStrike (WoW addon)

Addon for **World of Warcraft: Forever only** that logs dungeon runs for the Crusader Strike platform. Retail, Classic Era and Season of Discovery are not supported.

## Scope (addon#1)

- Detect dungeon instances and start/close/resume runs
- Snapshot the party
- Record player deaths and boss kills without combat-log reads (encounter IDs + unit fallbacks)
- Export a versioned copy-paste string via `/cs export` (MVP upload path)
- SavedVariables shaped so a future companion uploader can read them directly

## Layout

| Path | Role |
|------|------|
| `CrusaderStrike.toc` | Interface `16001` (WoW Forever 1.60.1) |
| `Core.lua` | Bootstrap, SavedVariables, slash commands |
| `DungeonLog.lua` | Instance + Forever encounter/unit detection (no CLEU reads) |
| `PvpLog.lua` | World PvP + battleground history (`/cs pvp`) |
| `Logic/Detection.lua` | Pure boss/death detection helpers |
| `Logic/DebugEvents.lua` | `/cs debug events` ring buffer |
| `Export.lua` | `/cs export` copy box |
| `Data/Bosses.lua` | Forever boss NPC ids + `byEncounterId` (DungeonEncounter 1.60.1.70790) |
| `docs/forever-event-check.md` | In-game Forever event checklist for Drew |
| `Logic/*` | Pure Lua (unit-tested) |
| `docs/run-schema.md` | Schema for platform#3 |
| `docs/sources.md` | Citations for client/dungeon data |
| `docs/pvp-schema.md` | PvP SavedVariables schema |
| `docs/companion-app-issue.md` | Draft issue for companion uploader |

## PvP history (`/cs pvp`)

World PvP kills/deaths and battlegrounds are saved to `CrusaderStrikeCharDB.pvp`; see [docs/pvp-schema.md](docs/pvp-schema.md). Forever limits accepted by PM (combat log isn't readable by addons on 1.60.1):

- (a) Kills and assists can't be told apart; every honorable-kill credit is a `kill`.
- (b) Pet-only kills can't be excluded.
- (c) Dishonorable kills aren't recorded.
- (d) The killer on a death only comes from your current target (`killer_source = "target"`).

These get revisited if a later Forever build unprotects the combat log.

## Dungeon detection method (Forever 1.60.1)

Forever cannot read the combat log from addon code (`CombatLogGetCurrentEventInfo`
missing / secure). Boss kills use `ENCOUNTER_END` (`success=1`) and `BOSS_KILL` matched
to verified `DungeonEncounter` IDs, with a `boss1`–`boss5` `UnitIsDead` fallback.
Party deaths use `PLAYER_DEAD` plus `UNIT_HEALTH`/`UNIT_FLAGS` on `player`/`party1-4` (deaths are keyed per character by GUID, falling back to name-realm; members already dead or ghosted after a /reload, a re-zone or a roster change are seeded and not counted again)
(each death counted once across release/rez). Wipes (`ENCOUNTER_END` success=0) are
not kills. `/cs debug events [on|off|dump]` records whether candidate events fire
in-game — see [docs/forever-event-check.md](docs/forever-event-check.md).

## Develop / test

```bash
lua tests/run_tests.lua
```

Requires Lua 5.1 for the test runner. No Ace/LibStub dependency in v0.1.

## Upload path

1. **MVP:** player runs `/cs export`, pastes into the website.
2. **Later:** companion desktop app watches `WTF/Account/<id>/SavedVariables/CrusaderStrike.lua` (see companion issue draft).

Do not push from the PM GitHub login. Use `crusaderstrike-addon` when that account is available.

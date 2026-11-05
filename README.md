<p align="center"><img src="assets/logo.svg" alt="Crusader Strike logo" width="160"></p>

# CrusaderStrike (WoW addon)

Addon for **World of Warcraft: Forever only** that logs dungeon runs for the Crusader Strike platform. Retail, Classic Era and Season of Discovery are not supported.

## Scope (addon#1)

- Detect dungeon instances and start/close/resume runs
- Snapshot the party
- Record player deaths and boss kills (bundled NPC id table; Forever ids still TODO-verify)
- Export a versioned copy-paste string via `/cs export` (MVP upload path)
- SavedVariables shaped so a future companion uploader can read them directly

## Layout

| Path | Role |
|------|------|
| `CrusaderStrike.toc` | Interface `16001` (WoW Forever 1.60.1; TODO: unconfirmed by official source) |
| `Core.lua` | Bootstrap, SavedVariables, slash commands |
| `DungeonLog.lua` | Instance + CLEU hooks |
| `Export.lua` | `/cs export` copy box |
| `Data/Bosses.lua` | Bundled Forever dungeon boss NPC ids (Classic ids, unverified) |
| `Logic/*` | Pure Lua (unit-tested) |
| `docs/run-schema.md` | Schema for platform#3 |
| `docs/sources.md` | Citations for client/dungeon data |
| `docs/companion-app-issue.md` | Draft issue for companion uploader |

## PvP history (`/cs pvp`)

World PvP kills/deaths and battlegrounds are saved to `CrusaderStrikeCharDB.pvp`; see [docs/pvp-schema.md](docs/pvp-schema.md). Forever limits accepted by PM (combat log isn't readable by addons on 1.60.1):

- (a) Kills and assists can't be told apart; every honorable-kill credit is a `kill`.
- (b) Pet-only kills can't be excluded.
- (c) Dishonorable kills aren't recorded.
- (d) The killer on a death only comes from your current target (`killer_source = "target"`).

These get revisited if a later Forever build unprotects the combat log.

## Develop / test

```bash
lua tests/run_tests.lua
```

Requires Lua 5.1 for the test runner. No Ace/LibStub dependency in v0.1.

## Upload path

1. **MVP:** player runs `/cs export`, pastes into the website.
2. **Later:** companion desktop app watches `WTF/Account/<id>/SavedVariables/CrusaderStrike.lua` (see companion issue draft).

Do not push from the PM GitHub login. Use `crusaderstrike-addon` when that account is available.

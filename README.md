<p align="center"><img src="assets/logo.svg" alt="Crusader Strike logo" width="160"></p>

# CrusaderStrike (WoW addon)

Addon for **World of Warcraft: Forever only** that logs dungeon runs for the Crusader Strike platform. Retail, Classic Era and Season of Discovery are not supported.

## Scope (addon#1)

- Detect dungeon instances and start/close/resume runs
- Snapshot the party
- Record player deaths and boss kills without combat-log reads (encounter IDs + unit fallbacks)
- Export versioned copy-paste strings via `/cs export` (CSRUN1 run + CSGEAR1 gear)
- Named gear sets via `/cs gearsets` and `/cs import` (CSGEAR1 sync)
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
| `Export.lua` | `/cs export` copy box (CSRUN1 + CSGEAR1, Copy gear) |
| `GearSetsUI.lua` | `/cs gearsets` armory-style editor |
| `Logic/GearSlots.lua` | 19 platform slot names |
| `Logic/EquippedGear.lua` | Read-only equipped scan + item-link parse |
| `Logic/GearEncoder.lua` | CSGEAR1 encode/decode + validation |
| `Logic/GearSets.lua` | SavedVariables gear sets + import merge |
| `Data/Bosses.lua` | Forever boss NPC ids + `byEncounterId` (DungeonEncounter 1.60.1.70790) |
| `Data/Loot.lua` | Bundled Forever dungeon loot (RFC verified sample; see docs/loot-data.md) |
| `Logic/WishList.lua` | Pure per-dungeon wish-list helpers (unit-tested) |
| `LootBrowser.lua` | `/cs loot` browser UI + CHAT_MSG_LOOT obtain marking |
| `Character/GearTab.lua` | Standalone Crusader Strike gear window (sets, browser, stats) |
| `Logic/GearBrowser.lua` | Dungeon / name / item-id adapter (empty Atlas-shaped baseline) |
| `Data/ForeverLootOverlay.lua` | Hand-curated Forever loot overlay example |
| `docs/character-gear-tab.md` | Character tab layout, Atlas GPL note, overlay plan |
| `docs/forever-event-check.md` | In-game Forever event checklist for Drew |
| `Logic/*` | Pure Lua (unit-tested) |
| `docs/run-schema.md` | Schema for platform#3 |
| `docs/sources.md` | Citations for client/dungeon data |
| `docs/pvp-schema.md` | PvP SavedVariables schema |
| `docs/companion-app-issue.md` | Draft issue for companion uploader |

## PvP history (`/cs pvp`)

World PvP kills/deaths and battlegrounds are saved to `CrusaderStrikeCharDB.pvp`; see [docs/pvp-schema.md](docs/pvp-schema.md). Forever limits accepted by PM (combat log is never used — registration/reads are blocked on 1.60.1):

- (a) Kills and assists can't be told apart; every honorable-kill credit is a `kill`.
- (b) Pet-only kills can't be excluded.
- (c) Dishonorable kills aren't recorded.
- (d) The killer on a death only comes from your current target (`killer_source = "target"`).

Schema still allows `killer_source = "combat_log"` but Forever never sets it. Revisit if a later Forever build unprotects the combat log.

## Dungeon detection method (Forever 1.60.1)

**The combat log is not used.** On Forever 1.60.1, registering
`COMBAT_LOG_EVENT_UNFILTERED` or calling `CombatLogGetCurrentEventInfo` triggers the
`ADDON_ACTION_BLOCKED` popup ("blocked from an action only available to the Blizzard UI");
`pcall` does not suppress it. This addon never registers CLEU and never calls the
combat-log APIs.

Boss kills use `ENCOUNTER_END` (`success=1`) and `BOSS_KILL` matched to verified
`DungeonEncounter` IDs, with a `boss1`–`boss5` `UnitIsDead` fallback. Party deaths use
`PLAYER_DEAD` plus `UNIT_HEALTH`/`UNIT_FLAGS` on `player`/`party1-4` (deaths are keyed
per character by GUID, falling back to name-realm; members already dead or ghosted after
a /reload, a re-zone or a roster change are seeded and not counted again)
(each death counted once across release/rez). Wipes (`ENCOUNTER_END` success=0) are
not kills. `/cs debug events [on|off|dump]` records whether candidate non-CLEU events
fire in-game — see [docs/forever-event-check.md](docs/forever-event-check.md).


## Gear sets (`/cs gearsets`, CSGEAR1)

Named leveling / max_level gear sets sync by copy-paste (`CSGEAR1:`). Equipped gear is read-only (export only). Open `/cs gearsets` to create and edit sets; `/cs import <CSGEAR1…>` applies a website export (any failure prints one `Import failed: …` line and saves nothing); `/cs gearsets check` prints addon version, CSGEAR version and saved set count. Cap: 20 active sets (`list_limit_reached`). Below level 60 new sets default to leveling with an editable Up to level; at 60 only max_level sets can be created. Import prints clear messages for `character_mismatch`, `list_limit_reached`, and `item_not_forever`. Companion `/sync` failures (`unauthenticated`, `session_expired`, `upstream_unavailable`, `rate_limited`, `version_mismatch` / `version_conflict`, `character_mismatch`, `ignored_op`, `internal_error`, …) print the same way via `FailSync` / `ParseErrorEnvelope` (platform#51/#52; stores `request_id`) and keep `pending_ops` for retry. In-game slot edits queue OpenAPI `set_slot`/`clear_slot` ops (platform#46) on `pending_ops` for companion sync; CSGEAR1 copy-paste unchanged. Schema lives with Platform/Web (CSGEAR1 v1); Forever `|Hitem:` field order is documented best-effort in `GearEncoder` (confirm in game — see `docs/forever-event-check.md`).

## Loot browser + wish lists (`/cs loot`)

In-game UI to browse Forever dungeon loot and build a per-character wish list per dungeon (addon#2). Open with `/cs loot` or `/cs wishlist`. Lists are stored in `CrusaderStrikeCharDB.wishLists` (schema v3). v0.2.0 ships verified Ragefire Chasm boss rares only; other dungeons appear in the list without loot rows until IDs are confirmed — see [docs/loot-data.md](docs/loot-data.md). No CLEU; obtain marking uses `CHAT_MSG_LOOT`.

## Character gear window (`/cs geartab`)

Standalone Crusader Strike window (own size and chrome, parented to `UIParent`). It does not cover or restyle the Character / PaperDoll tab. The left pane is the gear doll. Gear Sets, Browser, and Stats open in a right-side pop-out anchored to that window; closing the pop-out hides them. AtlasLoot Classic is a GPL-2.0 layout reference only — do not copy it wholesale. See [docs/character-gear-tab.md](docs/character-gear-tab.md).

## Develop / test

```bash
lua tests/run_tests.lua
```

Requires Lua 5.1 for the test runner. No Ace/LibStub dependency in v0.3.

## Upload path

1. **MVP:** player runs `/cs export`, pastes into the website.
2. **Later:** companion desktop app watches `WTF/Account/<id>/SavedVariables/CrusaderStrike.lua` (see companion issue draft).

Do not push from the PM GitHub login. Use `crusaderstrike-addon` when that account is available.

# Changelog

All notable changes to CrusaderStrike (World of Warcraft: Forever only).

## Unreleased

## 0.3.4 (WoW Forever)

- Release for #26 morning check: includes #45 platform#51/#52 error-envelope handling (#46). No schema change.

### Changed
- **Consume platform#51/#52 error envelopes (#45):** `ParseErrorEnvelope` maps `unauthenticated` / `session_expired` / `upstream_unavailable` / `rate_limited` / `version_mismatch` / `internal_error` (plus legacy codes) into FailSync / gear-sets UX; stores `request_id` when present; honors `retryable` and `Retry-After`. Pending ops kept; syncing cleared. Locked to CrusaderStrike/platform#52 (`6ecf719`). Refs #26.

### Fixed
- CHANGELOG: restore `(WoW Forever)` on 0.3.2 / 0.3.3 headings; Option A cleanup note cites web#47 (PR), not web#46 (issue).

## 0.3.3 (WoW Forever)

- Release for #26 morning check: includes #41 gear-sets harden (#42) and #39 legacy Option A removal (#40). No schema change.

### Added
- **Gear-sets harden for #26 morning check (#41):** true CSGEAR1 E2E round-trip tests (export → web id assign → re-import, `local_id→id`); Forever `CreateDefaults` / `AllowedSetTypes` for under-60 leveling+max_level dropdown; companion sync `BeginSync` / `FailSync` / `CompleteSync` with player-visible messages for API down and session/token expiry (pending_ops kept, syncing cleared — no silent stuck state).

### Removed
- **Legacy Option A gear ops (#39):** drop `GearOps.SetMode` / `legacy` emit path (`remove_item`+`add_item`). Slot writes are `set_slot` / `clear_slot` only (same cleanup as web#47). Forever-only `/ops` wire, `op_id` + `base_version`, ack/stale/pending_ops handling unchanged. CSGEAR1 import still accepts inbound `remove_item` in `list.removes`.

## 0.3.2 (WoW Forever)

- Includes #36: emit `set_slot`/`clear_slot` gear ops (platform#46) with legacy fallback.

### Added
- **Armory slot ops (platform#46):** in-game slot pick/clear queues OpenAPI `set_slot` / `clear_slot` on `list.pending_ops` (uuid `op_id`, `base_version`) for companion `/sync`. Primary path matches live platform; short `legacy` mode (`remove_item`+`add_item`) remains for fixtures/tests via `CrusaderStrikeGearOps.SetMode` (removed in #39).
- **Ops response handling:** `list.version` tracks the server; `DrainPendingOps` peeks (no clear) and `AckPendingOps` / `ApplyOpsResult` drop ops only after `applied`/`conflicts`/`duplicates`; stale ops rebuild with a new `op_id`; hard rejects revert the slot. Wire ops omit `source` (avoids `ignored[]`).

## 0.3.1 (WoW Forever)

### Changed
- Version bump to **0.3.1** and first GitHub Release zip for in-game install (addon#31 / Refs #26).
- Ships the CSGEAR1 round-trip harden from #30 (`490c1e0`) so Drew's morning check (#26) can use a tagged release instead of a SHA checkout.

## 0.3.0 (WoW Forever)

### Added
- **CSGEAR1 gear sets** (`/cs gearsets`, `/cs import`, gear line on `/cs export`): named leveling / max_level sets with copy-paste sync, read-only equipped gear scan, and an armory-style in-game editor. SavedVariables schema v4 (`CrusaderStrikeCharDB.gearSets`). Cap 20 active sets; over-cap reason code `list_limit_reached`.
- Equipped gear is read via `GetInventoryItemLink` (slots 1–19) on demand and on `PLAYER_EQUIPMENT_CHANGED` (debounced). Export includes equipped; import never writes it.

### Changed
- **CSGEAR1 round-trip hardening (#29):** `GearEncoder` owns Forever `|Hitem:` field-order docs + `ParseItemLink`; clear in-game reject messages for `character_mismatch` / `list_limit_reached` / `item_not_forever`; optional `rejects[]` on web re-import strings; `local_id→id` link never wiped by null; web-import fixture under `tests/fixtures/`.

### Notes
- Item-link field order is documented best-effort in `GearEncoder.ITEM_LINK_FIELDS` (`[1]=item_id`, `[2]=enchant_id`, `[7]=suffix_id`, …). **Confirm in game on Forever 1.60.1** as part of addon#26 morning check.
- CSRUN1 run export is unchanged.

## 0.2.0 (WoW Forever)

### Added
- **Dungeon loot browser** (`/cs loot` / `/cs wishlist`): pick a Forever dungeon, browse boss loot with search and slot filter, and manage a per-character per-dungeon wish list stored in `CrusaderStrikeCharDB.wishLists` (SavedVariables schema v3).
- Wish-list items can be added, removed, reordered (Shift/Alt-click), and marked obtained. Looting a wished item (`CHAT_MSG_LOOT`) marks it obtained automatically. While inside that dungeon, the browser banner shows how many wished items are still wanted.
- Bundled **Ragefire Chasm** boss-rare loot with verified Forever item IDs (`Data/Loot.lua`). Other dungeons are listed from `Data/Bosses.lua` but have no loot rows yet — see `docs/loot-data.md`. No invented item IDs.

### Notes
- No combat-log usage. Loot detection uses `CHAT_MSG_LOOT` only.
- Full Forever loot coverage is TODO(unverified); extend `Data/Loot.lua` using the format in `docs/loot-data.md` once IDs are confirmed.

## 0.1.1 (WoW Forever)

### Fixed
- Fixed the "CrusaderStrike has been blocked from an action only available to the Blizzard UI" popup. The addon no longer reads the combat log, which addons can't use on the WoW Forever client.

### Changed
- **World PvP:** honorable kills made by your pet now count as your honorable kills. Without the combat log, the addon can't tell your kills and your pet's kills apart.
- **Deaths:** the player who killed you is recorded only if you were targeting them when you died. Otherwise the death is saved without a killer.
- **Dungeons:** boss kills and deaths are tracked through the game's encounter and unit events (encounter end, boss kill, player death, and unit health/flags) instead of the combat log.

Older saved records, including ones whose killer came from the combat log, still load and upload as before.

# Changelog

All notable changes to CrusaderStrike (World of Warcraft: Forever only).

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

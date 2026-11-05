# Changelog

All notable changes to CrusaderStrike (World of Warcraft: Forever only).

## 0.1.1 (WoW Forever)

### Fixed
- Fixed the "CrusaderStrike has been blocked from an action only available to the Blizzard UI" popup. The addon no longer reads the combat log, which addons can't use on the WoW Forever client.

### Changed
- **World PvP:** honorable kills made by your pet now count as your honorable kills. Without the combat log, the addon can't tell your kills and your pet's kills apart.
- **Deaths:** the player who killed you is recorded only if you were targeting them when you died. Otherwise the death is saved without a killer.
- **Dungeons:** boss kills and deaths are tracked through the game's encounter and unit events (encounter end, boss kill, player death, and unit health/flags) instead of the combat log.

Older saved records, including ones whose killer came from the combat log, still load and upload as before.

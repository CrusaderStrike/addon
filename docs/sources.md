# Sources

Policy: interface number and dungeon/boss data must come from official Blizzard or Wowhead sources. Anything not confirmed there is marked `TODO(unverified)` in code.

## What WoW Forever is
- Wowhead, *World of Warcraft: Forever Overview*: a new evolution of WoW Classic, released Nov 4, 2026, fresh start from level 1, permanent max level 60, new zones, 9 new dungeons, raids. https://www.wowhead.com/forever/guide/overview-features-zones-raids
- Wowhead Forever hub: https://www.wowhead.com/forever

## Interface / TOC number
- TODO(unverified): `16001` (client 1.60.1). Not found on an official Blizzard or Wowhead page. Reported only by non-official sources:
  - CurseForge addon pages tagged "Forever / 1.60.1", e.g. https://www.curseforge.com/wow/addons/hebuka-ui-enhancements
  - Third-party addon doc citing `GetBuildInfo()` = `"1.60.1", "69913", ..., 16001`: https://github.com/realworldbuilder/wowwrapped/blob/main/docs/addon-api.md
  - https://mmonster.co/wow-forever/guides/addons/install

## Dungeons
- Wowhead, *Dungeons Overview for Forever*: lists the 9 new dungeons plus all Classic dungeons as available; says data for untested dungeons is "taken from Classic WoW or the Wowhead Database". https://www.wowhead.com/forever/guide/dungeons-overview-locations-details
- Map ids and boss NPC ids in `Data/Bosses.lua` are Classic values: TODO(unverified) for Forever.
- New Forever dungeons: no ids yet (TODO).

# Sources

Policy: interface number and dungeon/boss data must come from Wowhead Forever,
Blizzard patch notes / API, CurseForge or Wago Forever addon TOCs, or wago.tools
DB2 tables for the Forever build. Anything not confirmed there is marked
`TODO(unverified)` in code. `dungeon_id` on the platform is the addon's
`instance.id` / `instanceMapID` (platform OpenAPI v1 / platform#18).

## What WoW Forever is
- Wowhead, *World of Warcraft: Forever Overview*: released Nov 4, 2026, max level 60, 9 new dungeons. https://www.wowhead.com/forever/guide/overview-features-zones-raids
- Wowhead Forever hub: https://www.wowhead.com/forever
- Wowhead, *Dungeons Overview for Forever* (9 new + Classic dungeons): https://www.wowhead.com/forever/guide/dungeons-overview-locations-details

## Interface / TOC number
- **Verified: `16001`** for Forever client **1.60.1**
  - Warcraft Wiki TOC format table: Forever Beta and Forever Test = `16001`. https://warcraft.wiki.gg/wiki/TOC_format
  - wago.tools Forever branch build **1.60.1.70790** (product `wowf` / `_forever_`), 2026-11-04. Interface encoding for 1.60.1 is 16001. https://wago.tools/
  - Forever TOC game type / suffix: `forever` / `camelot` (Warcraft Wiki TOC naming). Addon TOC sets `## AllowLoadGameType: forever, camelot`.
- Project constant: `WOW_PROJECT_CAMELOT = 18` (Warcraft Wiki `WOW_PROJECT_ID`, patch 1.60.1). https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID

## Difficulty IDs
- **Verified: DifficultyID `1`** = 5-player Normal for Forever dungeon maps (including 36, 389, 3065, 2999, 2998, 2959) in `MapDifficulty.db2` for build 1.60.1.70790 (wago.tools).
- Other DifficultyID values (e.g. 201) exist on some maps; v1 logging records whatever `GetInstanceInfo()` returns and treats Normal as 1.

## Classic-lineage instanceMapIDs (Forever Map.db2)
Confirmed in wago.tools `Map` CSV build **1.60.1.70790** (InstanceType party dungeon):

| Map ID | MapName_lang |
|--------|----------------|
| 389 | Ragefire Chasm |
| 43 | Wailing Caverns |
| 36 | Deadmines |
| 33 | Shadowfang Keep |
| 48 | Blackfathom Deeps |
| 34 | Stormwind Stockade |
| 90 | Gnomeregan |
| 47 | Razorfen Kraul |
| 129 | Razorfen Downs |
| 189 | Scarlet Monastery |
| 209 | Zul'Farrak |
| 70 | Uldaman |
| 349 | Maraudon |
| 109 | Sunken Temple |
| 230 | Blackrock Depths |
| 229 | Blackrock Spire |
| 429 | Dire Maul |
| 329 | Stratholme |
| 289 | Scholomance |

DungeonEncounter rows on those maps still list the Classic final-boss **names** in the same Forever build (wago.tools `DungeonEncounter` CSV).

## Classic final-boss NPC IDs
Each `finalNpcId` below is present on Forever NPC databases (icy-veins Forever `npcs/{id}` pages report patch 1.60.1; Wowhead Forever `npc={id}` for samples such as Edwin VanCleef 639 and Bazzalan 11519):

| Map | Final boss | NPC ID |
|-----|------------|--------|
| 389 | Bazzalan | 11519 |
| 43 | Mutanus the Devourer | 3654 |
| 36 | Edwin VanCleef | 639 |
| 33 | Archmage Arugal | 4275 |
| 48 | Aku'mai | 4829 |
| 34 | Bazil Thredd | 1716 |
| 90 | Mekgineer Thermaplugg | 7800 |
| 47 | Charlga Razorflank | 4421 |
| 129 | Amnennar the Coldbringer | 7358 |
| 189 | High Inquisitor Whitemane | 3977 |
| 209 | Chief Ukorz Sandscalp | 7267 |
| 70 | Archaedas | 2748 |
| 349 | Princess Theradras | 12201 |
| 109 | Shade of Eranikus | 5709 |
| 230 | Emperor Dagran Thaurissan | 9019 |
| 229 | General Drakkisath | 10363 |
| 429 | King Gordok (East) | 11501 |
| 329 | Baron Rivendare | 10440 |
| 289 | Darkmaster Gandling | 1853 |

Intermediate Classic boss NPC IDs in `Data/Bosses.lua` are the Classic creature IDs retained by the Forever client; they were not each re-cited on Forever DB pages for addon#9.

## New Forever dungeons — map IDs
From wago.tools `Map` build 1.60.1.70790:

| Map ID | Name | Notes |
|--------|------|-------|
| 3065 | The Hall of Thanes | In build |
| 2999 | Ruins of Lordaeron | In build |
| 2998 | Excavation Site: Wetlands | In build |
| 2959 | City of Dalaran | In build (dungeon map; distinct from world map 2980) |

Announced on Wowhead Forever dungeons overview but **no Map.db2 row** in 1.60.1.70790 (listed in `CrusaderStrikeBosses.pendingForeverDungeons`, no invented IDs):

- The Drowned City (35–40)
- Krol'dok Stronghold (40–45)
- Alcaz Prison (48–53)
- Blackmaw Hold (55–60)
- Shaper's Terrace (58–60)

## New Forever dungeons — boss NPC IDs
Creature IDs from Wowhead Forever records as mirrored by wowfwiki ("is Forever creature N") and reachable on 60.tools `creatures/{id}-…`. Encounter order from wago.tools `DungeonEncounter` build 1.60.1.70790.

### The Hall of Thanes (3065) — final Durgen Dirgehammer 261319
| Order | Name | NPC ID | Notes |
|------|------|--------|-------|
| 1 | Faldrim Anvilmar | 261306 | |
| 2 | Magmatus | 261316 | DungeonEncounter name: Infurnus |
| 3 | Plunder | 261311 | |
| 4 | Durgen Dirgehammer | 261319 | Final |

### Ruins of Lordaeron (2999) — final Rath'mael 250657
| Order | Name | NPC ID | Notes |
|------|------|--------|-------|
| 1 | Witherfang | 250483 | |
| 2 | The Abandoned | 250631 | |
| 3 | The Baron | 250660 | DungeonEncounter name: The Butcher |
| 4 | Lordaeron Captain | 255699 | |
| 5 | Viktor the Vile | 256035 | |
| 6 | Bjork | 256097 | |
| 7 | Rath'mael | 250657 | Final |

### Excavation Site: Wetlands (2998) — final Relic Guardian 260326
| Order | Name | NPC ID | Notes |
|------|------|--------|-------|
| 1 | Saltspine | 260322 | |
| 2 | Shadetooth | 260325 | |
| 3 | Highland Horror | 260808 | Optional (encounter flags) |
| 4 | Relic Guardian | 260326 | Final |

### City of Dalaran (2959) — final Shade of the Archmage 246020
| Order | Name | NPC ID | Notes |
|------|------|--------|-------|
| 1 | Arcane Anomaly | 245999 | |
| 2 | Fel Ancient | 246003 | |
| 3 | Mana Devourer | 246008 | |
| 4 | Unstable Sentinel | 246017 | |
| 5 | Arcanic Enigma | 246016 | On Wowhead Forever boss list |
| 6 | Lyn the Ignored | 247032 | |
| 7 | Atrexis the Grave Knight | 247126 | |
| 8 | Shade of the Archmage | 246020 | Final |

### TODO(unverified) — City of Dalaran encounters without creature IDs
DungeonEncounter lists **Mana Elemental** and **Mana Wraith** on map 2959; wowfwiki pages state creature IDs remain unverified. Not keyed in `Data/Bosses.lua`.

## Reference exports used for addon#9
- `https://wago.tools/db2/Map/csv?build=1.60.1.70790`
- `https://wago.tools/db2/DungeonEncounter/csv?build=1.60.1.70790`
- `https://wago.tools/db2/MapDifficulty/csv?build=1.60.1.70790`

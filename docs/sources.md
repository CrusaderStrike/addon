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

## Groomed ticket B re-check (2026-11-04)
Latest wago.tools `wowf` build is still **1.60.1.70790** (`https://wago.tools/api/builds`).

- **5 pending dungeons** (The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace): still **no row** in `Map`, and no `DungeonEncounter` rows, in 1.60.1.70790. They remain TODO(unverified) in `pendingForeverDungeons`; no map, encounter or NPC IDs invented.
- **City of Dalaran (2959)**, `DungeonEncounter` 1.60.1.70790 (Name, ID, OrderIndex): Arcane Anomaly 3298/0, Fel Ancient 3299/1000, Mana Devourer 3300/2000, Mana Elemental 3301/3000, Unstable Sentinel 3302/4000, Lyn the Ignored 3310/6000, Atrexis the Grave Knight 3311/7000, Mana Wraith 3312/8000, Shade of the Archmage 3303/9000.
  - Final boss trigger: Shade of the Archmage has the highest OrderIndex (9000), so `finalNpcId = 246020` is unchanged.
  - **Mana Elemental (encounter 3301)**: creature ID TODO(unverified). Wowhead Forever search lists `npc=240352` "mana-elemental" (and Classic-era 14689), but the NPC page returned 403 to our fetch, and 60.tools `creatures/240352` returns "Record not found". wowfwiki `Mana_Elemental` says the creature ID is unverified, and notes the Power Overwhelming achievement names Mana Elemental in text but links its kill counter to Arcanic Enigma.
  - **Mana Wraith (encounter 3312)**: creature ID TODO(unverified). 60.tools `creatures/246931` exists as "Mana Wraith" (Elemental), but it has no recorded location, so nothing ties it to map 2959. wowfwiki `Mana_Wraith` says the creature ID is unverified.
  - Encounter IDs are recorded in `CrusaderStrikeBosses.pendingForeverEncounters` with `npcId = nil`.
- **Mismatch**: Arcanic Enigma (246016, in our table at order 5) has **no** `DungeonEncounter` row on map 2959. It may be the creature behind encounter 3301 "Mana Elemental" (per the wowfwiki achievement note), but that's unconfirmed, so the existing entry is left unchanged.

## PvP history (groomed ticket A, 2026-11-04)
Checked against Ketho/BlizzardInterfaceResources branch `forever` (`Resources/GlobalAPI.lua`, `Resources/Events.lua`, 1.60.1): https://github.com/Ketho/BlizzardInterfaceResources/tree/forever, and Warcraft Wiki Patch 1.60.1 API changes (Forever diffs against 12.1.5): https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes

- **Events present in Forever:** `PLAYER_PVP_KILLS_CHANGED`, `PLAYER_DEAD`, `DUEL_REQUESTED`, `DUEL_INBOUNDS`, `DUEL_FINISHED`, `UPDATE_BATTLEFIELD_STATUS`, `UPDATE_BATTLEFIELD_SCORE`, `PVP_MATCH_COMPLETE`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `COMBAT_LOG_EVENT_UNFILTERED`.
- **APIs present in Forever:** `C_PvP.GetScoreInfo`, `C_PvP.GetScoreInfoByPlayerGuid`, `C_PvP.GetZonePVPInfo`, `C_PvP.GetActiveMatchWinner`, `C_PvP.GetActiveMatchState`, `GetBattlefieldWinner`, `GetNumBattlefieldScores`, `GetBattlefieldInstanceRunTime`, `RequestBattlefieldScoreData`, `IsActiveBattlefieldArena`, `GetRealZoneText`, `GetSubZoneText`, `UnitFactionGroup`, `UnitIsPlayer`, `UnitIsEnemy`, `UnitGUID`, `GetPlayerInfoByGUID`, `GetInstanceInfo`, `IsInInstance`.
- **Not in Forever (mismatch with ticket A wording):**
  - `GetBattlefieldScore` is absent; the scoreboard is read with `C_PvP.GetScoreInfo*` (PVPScoreInfo: https://warcraft.wiki.gg/wiki/Structure_PVPScoreInfo).
  - Global `GetZonePVPInfo` is absent; `C_PvP.GetZonePVPInfo` is used.
  - `CombatLogGetCurrentEventInfo` is absent from the Forever global API. It was deprecated in 12.0 (https://warcraft.wiki.gg/wiki/API_CombatLogGetCurrentEventInfo); the Forever deprecation shim maps it to `C_CombatLog.GetCurrentEventInfo`, which "has been relocated to the secure environment" (https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_DeprecatedCombatLog/Deprecated_CombatLog.lua) and is not in GlobalAPI. `COMBAT_LOG_EVENT_UNFILTERED` still fires but its payload can't be read. PvpLog only uses the combat log behind a `pcall` capability check. **This also affects DungeonLog.lua boss/death tracking (UNIT_DIED via CLEU)** — TODO(unverified) in-game, needs its own ticket.
- TODO(unverified): whether `PLAYER_PVP_KILLS_CHANGED`'s `unitTarget` still resolves to the victim after it dies in Forever (Warcraft Wiki lists the event for mainline and classic game types, not `forever` explicitly: https://warcraft.wiki.gg/wiki/PLAYER_PVP_KILLS_CHANGED). If it doesn't, opponent fields are null and the kill is still counted.

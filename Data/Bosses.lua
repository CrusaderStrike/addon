-- Bundled dungeon bosses for World of Warcraft: Forever, keyed by instanceMapID.
-- Target client: WoW Forever ONLY (gameVersion "forever"). See docs/sources.md.
--
-- VERIFICATION STATUS (addon#9):
--  * Interface / TOC: ## Interface: 16001 matches Forever client 1.60.1 (wago.tools
--    Forever build 1.60.1.70790; Warcraft Wiki TOC table Forever Beta/Test).
--  * Classic-lineage instanceMapIDs: confirmed present in Forever Map.db2
--    (wago.tools build 1.60.1.70790). dungeon_id == instanceMapID (platform#18).
--  * Classic final-boss NPC IDs: confirmed on Forever databases (icy-veins Forever
--    NPC pages for each finalNpcId below; Wowhead Forever for samples).
--  * Intermediate Classic boss NPC IDs: retained Classic creature IDs (same IDs the
--    Forever client still uses for these encounters). Not each re-cited individually.
--  * New Forever dungeons with Map.db2 rows: Hall of Thanes 3065, Ruins of Lordaeron
--    2999, Excavation Site: Wetlands 2998, City of Dalaran 2959 — boss NPC IDs from
--    Wowhead Forever creature records via wowfwiki / 60.tools (see docs/sources.md).
--  * TODO(unverified): five announced Forever dungeons have no Map.db2 row yet
--    (listed in CrusaderStrikeBosses.pendingForeverDungeons). Mana Elemental and
--    Mana Wraith appear in Forever DungeonEncounter for map 2959 but have no
--    published creature IDs.
--  * Difficulty: Forever 5-player Normal uses DifficultyID 1 (MapDifficulty.db2).

CrusaderStrikeBosses = CrusaderStrikeBosses or {}

local FOREVER = {
  -- Ragefire Chasm
  [389] = {
    name = "Ragefire Chasm",
    finalNpcId = 11519, -- Bazzalan
    bosses = {
      [11517] = { name = "Oggleflint", order = 1 },
      [11520] = { name = "Taragaman the Hungerer", order = 2 },
      [11518] = { name = "Jergosh the Invoker", order = 3 },
      [11519] = { name = "Bazzalan", order = 4 },
    },
  },
  -- Wailing Caverns
  [43] = {
    name = "Wailing Caverns",
    finalNpcId = 3654, -- Mutanus the Devourer
    bosses = {
      [3671] = { name = "Lady Anacondra", order = 1 },
      [3669] = { name = "Lord Cobrahn", order = 2 },
      [3653] = { name = "Kresh", order = 3 },
      [3670] = { name = "Lord Pythas", order = 4 },
      [3674] = { name = "Skum", order = 5 },
      [3673] = { name = "Lord Serpentis", order = 6 },
      [5775] = { name = "Verdan the Everliving", order = 7 },
      [3654] = { name = "Mutanus the Devourer", order = 8 },
    },
  },
  -- The Deadmines
  [36] = {
    name = "The Deadmines",
    finalNpcId = 639, -- Edwin VanCleef
    bosses = {
      [644] = { name = "Rhahk'Zor", order = 1 },
      [642] = { name = "Sneed's Shredder", order = 2 },
      [643] = { name = "Sneed", order = 3 },
      [1763] = { name = "Gilnid", order = 4 },
      [646] = { name = "Mr. Smite", order = 5 },
      [647] = { name = "Captain Greenskin", order = 6 },
      [639] = { name = "Edwin VanCleef", order = 7 },
      [645] = { name = "Cookie", order = 8 },
    },
  },
  -- Shadowfang Keep
  [33] = {
    name = "Shadowfang Keep",
    finalNpcId = 4275, -- Archmage Arugal
    bosses = {
      [3914] = { name = "Rethilgore", order = 1 },
      [3886] = { name = "Razorclaw the Butcher", order = 2 },
      [3887] = { name = "Baron Silverlaine", order = 3 },
      [4278] = { name = "Commander Springvale", order = 4 },
      [4279] = { name = "Odo the Blindwatcher", order = 5 },
      [4274] = { name = "Fenrus the Devourer", order = 6 },
      [3927] = { name = "Wolf Master Nandos", order = 7 },
      [4275] = { name = "Archmage Arugal", order = 8 },
    },
  },
  -- Blackfathom Deeps
  [48] = {
    name = "Blackfathom Deeps",
    finalNpcId = 4829, -- Aku'mai
    bosses = {
      [4887] = { name = "Ghamoo-ra", order = 1 },
      [4831] = { name = "Lady Sarevess", order = 2 },
      [6243] = { name = "Gelihast", order = 3 },
      [12902] = { name = "Lorgus Jett", order = 4 },
      [12876] = { name = "Baron Aquanis", order = 5 },
      [4832] = { name = "Twilight Lord Kelris", order = 6 },
      [4830] = { name = "Old Serra'kis", order = 7 },
      [4829] = { name = "Aku'mai", order = 8 },
    },
  },
  -- The Stockade
  [34] = {
    name = "The Stockade",
    finalNpcId = 1716, -- Bazil Thredd (Classic)
    bosses = {
      [1696] = { name = "Targorr the Dread", order = 1 },
      [1666] = { name = "Kam Deepfury", order = 2 },
      [1717] = { name = "Hamhock", order = 3 },
      [1663] = { name = "Dextren Ward", order = 4 },
      [1716] = { name = "Bazil Thredd", order = 5 },
      [1720] = { name = "Bruegal Ironknuckle", order = 6 },
    },
  },
  -- Gnomeregan
  [90] = {
    name = "Gnomeregan",
    finalNpcId = 7800, -- Mekgineer Thermaplugg
    bosses = {
      [7361] = { name = "Grubbis", order = 1 },
      [7079] = { name = "Viscous Fallout", order = 2 },
      [6235] = { name = "Electrocutioner 6000", order = 3 },
      [6229] = { name = "Crowd Pummeler 9-60", order = 4 },
      [6228] = { name = "Dark Iron Ambassador", order = 5 },
      [7800] = { name = "Mekgineer Thermaplugg", order = 6 },
    },
  },
  -- Razorfen Kraul
  [47] = {
    name = "Razorfen Kraul",
    finalNpcId = 4421, -- Charlga Razorflank
    bosses = {
      [4424] = { name = "Aggem Thorncurse", order = 1 },
      [4428] = { name = "Death Speaker Jargba", order = 2 },
      [4420] = { name = "Overlord Ramtusk", order = 3 },
      [4422] = { name = "Agathelos the Raging", order = 4 },
      [4421] = { name = "Charlga Razorflank", order = 5 },
    },
  },
  -- Razorfen Downs
  [129] = {
    name = "Razorfen Downs",
    finalNpcId = 7358, -- Amnennar the Coldbringer
    bosses = {
      [7355] = { name = "Tuten'kash", order = 1 },
      [7357] = { name = "Mordresh Fire Eye", order = 2 },
      [8567] = { name = "Glutton", order = 3 },
      [7354] = { name = "Ragglesnout", order = 4 },
      [7358] = { name = "Amnennar the Coldbringer", order = 5 },
    },
  },
  -- Scarlet Monastery (shared map family; Classic map id 189)
  [189] = {
    name = "Scarlet Monastery",
    finalNpcId = 3977, -- High Inquisitor Whitemane
    bosses = {
      [3983] = { name = "Interrogator Vishas", order = 1 },
      [4543] = { name = "Bloodmage Thalnos", order = 2 },
      [3974] = { name = "Houndmaster Loksey", order = 3 },
      [6487] = { name = "Arcanist Doan", order = 4 },
      [3975] = { name = "Herod", order = 5 },
      [4542] = { name = "High Inquisitor Fairbanks", order = 6 },
      [3976] = { name = "Scarlet Commander Mograine", order = 7 },
      [3977] = { name = "High Inquisitor Whitemane", order = 8 },
    },
  },
  -- Zul'Farrak
  [209] = {
    name = "Zul'Farrak",
    finalNpcId = 7267, -- Chief Ukorz Sandscalp
    bosses = {
      [8127] = { name = "Antu'sul", order = 1 },
      [7272] = { name = "Theka the Martyr", order = 2 },
      [7271] = { name = "Witch Doctor Zum'rah", order = 3 },
      [7795] = { name = "Hydromancer Velratha", order = 4 },
      [7273] = { name = "Gahz'rilla", order = 5 },
      [7796] = { name = "Nekrum Gutchewer", order = 6 },
      [7275] = { name = "Shadowpriest Sezz'ziz", order = 7 },
      [7267] = { name = "Chief Ukorz Sandscalp", order = 8 },
    },
  },
  -- Uldaman
  [70] = {
    name = "Uldaman",
    finalNpcId = 2748, -- Archaedas
    bosses = {
      [6910] = { name = "Revelosh", order = 1 },
      [6906] = { name = "Baelog", order = 2 },
      [7228] = { name = "Ironaya", order = 3 },
      [7023] = { name = "Obsidian Sentinel", order = 4 },
      [7206] = { name = "Ancient Stone Keeper", order = 5 },
      [7291] = { name = "Galgann Firehammer", order = 6 },
      [4854] = { name = "Grimlok", order = 7 },
      [2748] = { name = "Archaedas", order = 8 },
    },
  },
  -- Maraudon
  [349] = {
    name = "Maraudon",
    finalNpcId = 12201, -- Princess Theradras
    bosses = {
      [13282] = { name = "Noxxion", order = 1 },
      [12258] = { name = "Razorlash", order = 2 },
      [12236] = { name = "Lord Vyletongue", order = 3 },
      [12225] = { name = "Celebras the Cursed", order = 4 },
      [12203] = { name = "Landslide", order = 5 },
      [13601] = { name = "Tinkerer Gizlock", order = 6 },
      [13596] = { name = "Rotgrip", order = 7 },
      [12201] = { name = "Princess Theradras", order = 8 },
    },
  },
  -- Temple of Atal'Hakkar
  [109] = {
    name = "The Temple of Atal'Hakkar",
    finalNpcId = 5709, -- Shade of Eranikus
    bosses = {
      [5710] = { name = "Jammal'an the Prophet", order = 1 },
      [5711] = { name = "Ogom the Wretched", order = 2 },
      [5720] = { name = "Weaver", order = 3 },
      [5721] = { name = "Dreamscythe", order = 4 },
      [5719] = { name = "Morphaz", order = 5 },
      [5722] = { name = "Hazzas", order = 6 },
      [8443] = { name = "Avatar of Hakkar", order = 7 },
      [5709] = { name = "Shade of Eranikus", order = 8 },
    },
  },
  -- Blackrock Depths
  [230] = {
    name = "Blackrock Depths",
    finalNpcId = 9019, -- Emperor Dagran Thaurissan
    bosses = {
      [9018] = { name = "High Interrogator Gerstahn", order = 1 },
      [9025] = { name = "Lord Roccor", order = 2 },
      [9319] = { name = "Houndmaster Grebmar", order = 3 },
      [10096] = { name = "High Justice Grimstone", order = 4 },
      [9024] = { name = "Pyromancer Loregrain", order = 5 },
      [9017] = { name = "Lord Incendius", order = 6 },
      [9041] = { name = "Warder Stilgiss", order = 7 },
      [9056] = { name = "Fineous Darkvire", order = 8 },
      [9016] = { name = "Bael'Gar", order = 9 },
      [9033] = { name = "General Angerforge", order = 10 },
      [8983] = { name = "Golem Lord Argelmach", order = 11 },
      [9537] = { name = "Hurley Blackbreath", order = 12 },
      [9543] = { name = "Ribbly Screwspigot", order = 13 },
      [9499] = { name = "Plugger Spazzring", order = 14 },
      [9156] = { name = "Ambassador Flamelash", order = 15 },
      [9035] = { name = "Anger'rel", order = 16 },
      [9938] = { name = "Magmus", order = 17 },
      [8929] = { name = "Princess Moira Bronzebeard", order = 18 },
      [9019] = { name = "Emperor Dagran Thaurissan", order = 19 },
    },
  },
  -- Lower Blackrock Spire
  [229] = {
    name = "Blackrock Spire",
    finalNpcId = 10363, -- General Drakkisath
    bosses = {
      [9196] = { name = "Highlord Omokk", order = 1 },
      [9236] = { name = "Shadow Hunter Vosh'gajin", order = 2 },
      [9237] = { name = "War Master Voone", order = 3 },
      [10596] = { name = "Mother Smolderweb", order = 4 },
      [10584] = { name = "Urok Doomhowl", order = 5 },
      [9736] = { name = "Quartermaster Zigris", order = 6 },
      [10268] = { name = "Gizrul the Slavener", order = 7 },
      [10220] = { name = "Halycon", order = 8 },
      [9568] = { name = "Overlord Wyrmthalak", order = 9 },
      [9816] = { name = "Pyroguard Emberseer", order = 10 },
      [10429] = { name = "Warchief Rend Blackhand", order = 11 },
      [10339] = { name = "Gyth", order = 12 },
      [10430] = { name = "The Beast", order = 13 },
      [10363] = { name = "General Drakkisath", order = 14 },
    },
  },
  -- Dire Maul
  [429] = {
    name = "Dire Maul",
    finalNpcId = 11501, -- King Gordok (East); also track Tortheldrin etc.
    bosses = {
      [14354] = { name = "Pusillin", order = 1 },
      [14327] = { name = "Lethtendris", order = 2 },
      [13280] = { name = "Hydrospawn", order = 3 },
      [11490] = { name = "Zevrim Thornhoof", order = 4 },
      [11492] = { name = "Alzzin the Wildshaper", order = 5 },
      [11489] = { name = "Tendris Warpwood", order = 6 },
      [11487] = { name = "Magister Kalendris", order = 7 },
      [11496] = { name = "Immol'thar", order = 8 },
      [11486] = { name = "Prince Tortheldrin", order = 9 },
      [14326] = { name = "Guard Mol'dar", order = 10 },
      [14322] = { name = "Stomper Kreeg", order = 11 },
      [14321] = { name = "Guard Fengus", order = 12 },
      [14323] = { name = "Guard Slip'kik", order = 13 },
      [14325] = { name = "Captain Kromcrush", order = 14 },
      [14324] = { name = "Cho'Rush the Observer", order = 15 },
      [11501] = { name = "King Gordok", order = 16 },
    },
  },
  -- Stratholme
  [329] = {
    name = "Stratholme",
    finalNpcId = 10440, -- Baron Rivendare (Classic)
    bosses = {
      [11032] = { name = "Malor the Zealous", order = 1 },
      [10811] = { name = "Archivist Galford", order = 2 },
      [10813] = { name = "Balnazzar", order = 3 },
      [10436] = { name = "Baroness Anastari", order = 4 },
      [10437] = { name = "Nerub'enkan", order = 5 },
      [10438] = { name = "Maleki the Pallid", order = 6 },
      [10435] = { name = "Magistrate Barthilas", order = 7 },
      [10439] = { name = "Ramstein the Gorger", order = 8 },
      [10440] = { name = "Baron Rivendare", order = 9 },
      [10558] = { name = "Hearthsinger Forresten", order = 10 },
      [10516] = { name = "The Unforgiven", order = 11 },
      [10808] = { name = "Timmy the Cruel", order = 12 },
      [10997] = { name = "Cannon Master Willey", order = 13 },
    },
  },
  -- Scholomance
  [289] = {
    name = "Scholomance",
    finalNpcId = 1853, -- Darkmaster Gandling
    bosses = {
      [10506] = { name = "Kirtonos the Herald", order = 1 },
      [10503] = { name = "Jandice Barov", order = 2 },
      [11622] = { name = "Rattlegore", order = 3 },
      [10433] = { name = "Marduk Blackpool", order = 4 },
      [10432] = { name = "Vectus", order = 5 },
      [10508] = { name = "Ras Frostwhisper", order = 6 },
      [10505] = { name = "Instructor Malicia", order = 7 },
      [11261] = { name = "Doctor Theolen Krastinov", order = 8 },
      [10901] = { name = "Lorekeeper Polkelt", order = 9 },
      [10507] = { name = "The Ravenian", order = 10 },
      [10504] = { name = "Lord Alexei Barov", order = 11 },
      [10502] = { name = "Lady Illucia Barov", order = 12 },
      [1853] = { name = "Darkmaster Gandling", order = 13 },
    },
  },
  -- ===== New Forever dungeons (Map.db2 + Wowhead Forever creature IDs) =====
  -- The Hall of Thanes (map 3065). Encounter table names Magmatus as "Infurnus";
  -- public Forever DB / Wowhead use Magmatus (npc 261316).
  [3065] = {
    name = "The Hall of Thanes",
    finalNpcId = 261319, -- Durgen Dirgehammer
    bosses = {
      [261306] = { name = "Faldrim Anvilmar", order = 1 },
      [261316] = { name = "Magmatus", order = 2 },
      [261311] = { name = "Plunder", order = 3 },
      [261319] = { name = "Durgen Dirgehammer", order = 4 },
    },
  },
  -- Ruins of Lordaeron (map 2999). Encounter name "The Butcher" == public "The Baron".
  [2999] = {
    name = "Ruins of Lordaeron",
    finalNpcId = 250657, -- Rath'mael
    bosses = {
      [250483] = { name = "Witherfang", order = 1 },
      [250631] = { name = "The Abandoned", order = 2 },
      [250660] = { name = "The Baron", order = 3 },
      [255699] = { name = "Lordaeron Captain", order = 4 },
      [256035] = { name = "Viktor the Vile", order = 5 },
      [256097] = { name = "Bjork", order = 6 },
      [250657] = { name = "Rath'mael", order = 7 },
    },
  },
  -- Excavation Site: Wetlands (map 2998). Highland Horror is optional (encounter flags).
  [2998] = {
    name = "Excavation Site: Wetlands",
    finalNpcId = 260326, -- Relic Guardian
    bosses = {
      [260322] = { name = "Saltspine", order = 1 },
      [260325] = { name = "Shadetooth", order = 2 },
      [260808] = { name = "Highland Horror", order = 3, optional = true },
      [260326] = { name = "Relic Guardian", order = 4 },
    },
  },
  -- City of Dalaran (map 2959).
  -- TODO(unverified): Mana Elemental + Mana Wraith are in DungeonEncounter but have
  -- no published creature NPC IDs yet (see docs/sources.md).
  [2959] = {
    name = "City of Dalaran",
    finalNpcId = 246020, -- Shade of the Archmage
    bosses = {
      [245999] = { name = "Arcane Anomaly", order = 1 },
      [246003] = { name = "Fel Ancient", order = 2 },
      [246008] = { name = "Mana Devourer", order = 3 },
      [246017] = { name = "Unstable Sentinel", order = 4 },
      [246016] = { name = "Arcanic Enigma", order = 5 },
      [247032] = { name = "Lyn the Ignored", order = 6 },
      [247126] = { name = "Atrexis the Grave Knight", order = 7 },
      [246020] = { name = "Shade of the Archmage", order = 8 },
    },
  },

}

CrusaderStrikeBosses.byVersion = {
  forever = FOREVER,
}


-- Announced Forever dungeons with no Map.db2 row in build 1.60.1.70790.
-- Do not invent instanceMapIDs; fill in when wago.tools / Wowhead publish them.
CrusaderStrikeBosses.pendingForeverDungeons = {
  { name = "The Drowned City", levelRange = "35-40" },
  { name = "Krol'dok Stronghold", levelRange = "40-45" },
  { name = "Alcaz Prison", levelRange = "48-53" },
  { name = "Blackmaw Hold", levelRange = "55-60" },
  { name = "Shaper's Terrace", levelRange = "58-60" },
}

-- City of Dalaran (map 2959) encounters present in Forever DungeonEncounter
-- (build 1.60.1.70790) whose creature NPC IDs are still TODO(unverified):
-- no Forever source ties a creature ID to these encounters in map 2959.
-- encounterId/orderIndex are verified; npcId stays nil until confirmed.
CrusaderStrikeBosses.pendingForeverEncounters = {
  { instanceMapId = 2959, name = "Mana Elemental", encounterId = 3301, orderIndex = 3000, npcId = nil },
  { instanceMapId = 2959, name = "Mana Wraith", encounterId = 3312, orderIndex = 8000, npcId = nil },
}

-- Forever 5-player Normal difficulty (MapDifficulty.db2 DifficultyID).
CrusaderStrikeBosses.normalDifficultyId = 1

CrusaderStrikeBosses.defaultVersion = "forever"

-- EncounterID -> boss mapping from wago.tools DungeonEncounter CSV build 1.60.1.70790,
-- matched to NPC IDs in FOREVER above. Name mismatches noted inline.
-- Pending unverified encounters (Mana Elemental 3301, Mana Wraith 3312) stay in
-- pendingForeverEncounters with npcId = nil.
CrusaderStrikeBosses.byEncounterId = {
  [227] = { instanceMapId = 230, npcId = 9018, name = "High Interrogator Gerstahn" },
  [228] = { instanceMapId = 230, npcId = 9025, name = "Lord Roccor" },
  [229] = { instanceMapId = 230, npcId = 9319, name = "Houndmaster Grebmar" },
  [231] = { instanceMapId = 230, npcId = 9024, name = "Pyromancer Loregrain" },
  [232] = { instanceMapId = 230, npcId = 9017, name = "Lord Incendius" },
  [233] = { instanceMapId = 230, npcId = 9041, name = "Warder Stilgiss" },
  [234] = { instanceMapId = 230, npcId = 9056, name = "Fineous Darkvire" },
  [235] = { instanceMapId = 230, npcId = 9016, name = "Bael'Gar" },
  [236] = { instanceMapId = 230, npcId = 9033, name = "General Angerforge" },
  [237] = { instanceMapId = 230, npcId = 8983, name = "Golem Lord Argelmach" },
  [238] = { instanceMapId = 230, npcId = 9537, name = "Hurley Blackbreath" },
  [240] = { instanceMapId = 230, npcId = 9543, name = "Ribbly Screwspigot" },
  [241] = { instanceMapId = 230, npcId = 9499, name = "Plugger Spazzring" },
  [242] = { instanceMapId = 230, npcId = 9156, name = "Ambassador Flamelash" },
  [244] = { instanceMapId = 230, npcId = 9938, name = "Magmus" },
  [267] = { instanceMapId = 229, npcId = 9196, name = "Highlord Omokk" },
  [268] = { instanceMapId = 229, npcId = 9236, name = "Shadow Hunter Vosh'gajin" },
  [269] = { instanceMapId = 229, npcId = 9237, name = "War Master Voone" },
  [270] = { instanceMapId = 229, npcId = 10596, name = "Mother Smolderweb" },
  [271] = { instanceMapId = 229, npcId = 10584, name = "Urok Doomhowl" },
  [272] = { instanceMapId = 229, npcId = 9736, name = "Quartermaster Zigris" },
  [273] = { instanceMapId = 229, npcId = 10268, name = "Gizrul the Slavener" },
  [274] = { instanceMapId = 229, npcId = 10220, name = "Halycon" },
  [275] = { instanceMapId = 229, npcId = 9568, name = "Overlord Wyrmthalak" },
  [343] = { instanceMapId = 429, npcId = 11490, name = "Zevrim Thornhoof" },
  [344] = { instanceMapId = 429, npcId = 13280, name = "Hydrospawn" },
  [345] = { instanceMapId = 429, npcId = 14327, name = "Lethtendris" },
  [346] = { instanceMapId = 429, npcId = 11492, name = "Alzzin the Wildshaper" },
  [348] = { instanceMapId = 429, npcId = 11487, name = "Magister Kalendris" },
  [349] = { instanceMapId = 429, npcId = 11496, name = "Immol'thar" },
  [350] = { instanceMapId = 429, npcId = 11489, name = "Tendris Warpwood" },
  [361] = { instanceMapId = 429, npcId = 11486, name = "Prince Tortheldrin" },
  [362] = { instanceMapId = 429, npcId = 14326, name = "Guard Mol'dar" },
  [363] = { instanceMapId = 429, npcId = 14322, name = "Stomper Kreeg" },
  [364] = { instanceMapId = 429, npcId = 14321, name = "Guard Fengus" },
  [365] = { instanceMapId = 429, npcId = 14323, name = "Guard Slip'kik" },
  [366] = { instanceMapId = 429, npcId = 14325, name = "Captain Kromcrush" },
  [367] = { instanceMapId = 429, npcId = 14324, name = "Cho'Rush the Observer" },
  [368] = { instanceMapId = 429, npcId = 11501, name = "King Gordok" },
  [422] = { instanceMapId = 349, npcId = 13282, name = "Noxxion" },
  [423] = { instanceMapId = 349, npcId = 12258, name = "Razorlash" },
  [424] = { instanceMapId = 349, npcId = 12236, name = "Lord Vyletongue" },
  [425] = { instanceMapId = 349, npcId = 12225, name = "Celebras the Cursed" },
  [426] = { instanceMapId = 349, npcId = 12203, name = "Landslide" },
  [427] = { instanceMapId = 349, npcId = 13601, name = "Tinkerer Gizlock" },
  [428] = { instanceMapId = 349, npcId = 13596, name = "Rotgrip" },
  [429] = { instanceMapId = 349, npcId = 12201, name = "Princess Theradras" },
  [444] = { instanceMapId = 189, npcId = 3983, name = "Interrogator Vishas" },
  [446] = { instanceMapId = 189, npcId = 3974, name = "Houndmaster Loksey" },
  [447] = { instanceMapId = 189, npcId = 6487, name = "Arcanist Doan" },
  [448] = { instanceMapId = 189, npcId = 3975, name = "Herod" },
  [449] = { instanceMapId = 189, npcId = 4542, name = "High Inquisitor Fairbanks" },
  [450] = { instanceMapId = 189, npcId = 3977, name = "High Inquisitor Whitemane" },
  [472] = { instanceMapId = 329, npcId = 10516, name = "The Unforgiven" },
  [473] = { instanceMapId = 329, npcId = 10558, name = "Hearthsinger Forresten" },
  [474] = { instanceMapId = 329, npcId = 10808, name = "Timmy the Cruel" },
  [475] = { instanceMapId = 329, npcId = 10997, name = "Cannon Master Willey" },
  [476] = { instanceMapId = 329, npcId = 11032, name = "Malor the Zealous" },
  [477] = { instanceMapId = 329, npcId = 10811, name = "Archivist Galford" },
  [478] = { instanceMapId = 329, npcId = 10813, name = "Balnazzar" },
  [479] = { instanceMapId = 329, npcId = 10436, name = "Baroness Anastari" },
  [480] = { instanceMapId = 329, npcId = 10437, name = "Nerub'enkan" },
  [481] = { instanceMapId = 329, npcId = 10438, name = "Maleki the Pallid" },
  [482] = { instanceMapId = 329, npcId = 10435, name = "Magistrate Barthilas" },
  [483] = { instanceMapId = 329, npcId = 10439, name = "Ramstein the Gorger" },
  [484] = { instanceMapId = 329, npcId = 10440, name = "Baron Rivendare" },
  [486] = { instanceMapId = 109, npcId = 5721, name = "Dreamscythe" },
  [487] = { instanceMapId = 109, npcId = 5720, name = "Weaver" },
  [488] = { instanceMapId = 109, npcId = 5710, name = "Jammal'an the Prophet" },
  [492] = { instanceMapId = 109, npcId = 8443, name = "Avatar of Hakkar" },
  [547] = { instanceMapId = 70, npcId = 6910, name = "Revelosh" },
  [549] = { instanceMapId = 70, npcId = 7228, name = "Ironaya" },
  [551] = { instanceMapId = 70, npcId = 7206, name = "Ancient Stone Keeper" },
  [552] = { instanceMapId = 70, npcId = 7291, name = "Galgann Firehammer" },
  [553] = { instanceMapId = 70, npcId = 4854, name = "Grimlok" },
  [554] = { instanceMapId = 70, npcId = 2748, name = "Archaedas" },
  [585] = { instanceMapId = 43, npcId = 3671, name = "Lady Anacondra" },
  [586] = { instanceMapId = 43, npcId = 3669, name = "Lord Cobrahn" },
  [587] = { instanceMapId = 43, npcId = 3653, name = "Kresh" },
  [588] = { instanceMapId = 43, npcId = 3670, name = "Lord Pythas" },
  [589] = { instanceMapId = 43, npcId = 3674, name = "Skum" },
  [590] = { instanceMapId = 43, npcId = 3673, name = "Lord Serpentis" },
  [591] = { instanceMapId = 43, npcId = 5775, name = "Verdan the Everliving" },
  [592] = { instanceMapId = 43, npcId = 3654, name = "Mutanus the Devourer" },
  [593] = { instanceMapId = 209, npcId = 7795, name = "Hydromancer Velratha" },
  [594] = { instanceMapId = 209, npcId = 7273, name = "Gahz'rilla" },
  [595] = { instanceMapId = 209, npcId = 8127, name = "Antu'sul" },
  [596] = { instanceMapId = 209, npcId = 7272, name = "Theka the Martyr" },
  [597] = { instanceMapId = 209, npcId = 7271, name = "Witch Doctor Zum'rah" },
  [598] = { instanceMapId = 209, npcId = 7796, name = "Nekrum Gutchewer" },
  [599] = { instanceMapId = 209, npcId = 7275, name = "Shadowpriest Sezz'ziz" },
  [600] = { instanceMapId = 209, npcId = 7267, name = "Chief Ukorz Sandscalp" },
  [1887] = { instanceMapId = 70, npcId = 7023, name = "Obsidian Sentinel" },
  [2694] = { instanceMapId = 48, npcId = 12876, name = "Baron Aquanis" },
  [2704] = { instanceMapId = 48, npcId = 6243, name = "Gelihast" },
  [2732] = { instanceMapId = 389, npcId = 11517, name = "Oggleflint" },
  [2733] = { instanceMapId = 389, npcId = 11520, name = "Taragaman the Hungerer" },
  [2734] = { instanceMapId = 389, npcId = 11518, name = "Jergosh the Invoker" },
  [2735] = { instanceMapId = 389, npcId = 11519, name = "Bazzalan" },
  [2741] = { instanceMapId = 36, npcId = 644, name = "Rhahk'Zor" },
  [2742] = { instanceMapId = 36, npcId = 643, name = "Sneed" },
  [2743] = { instanceMapId = 36, npcId = 1763, name = "Gilnid" },
  [2744] = { instanceMapId = 36, npcId = 647, name = "Captain Greenskin" },
  [2745] = { instanceMapId = 36, npcId = 646, name = "Mr. Smite" },
  [2746] = { instanceMapId = 36, npcId = 645, name = "Cookie" },
  [2747] = { instanceMapId = 36, npcId = 639, name = "Edwin VanCleef" },
  [2748] = { instanceMapId = 33, npcId = 3914, name = "Rethilgore" },
  [2749] = { instanceMapId = 33, npcId = 3886, name = "Razorclaw the Butcher" },
  [2750] = { instanceMapId = 33, npcId = 3887, name = "Baron Silverlaine" },
  [2751] = { instanceMapId = 33, npcId = 4278, name = "Commander Springvale" },
  [2752] = { instanceMapId = 33, npcId = 4279, name = "Odo the Blindwatcher" },
  [2753] = { instanceMapId = 33, npcId = 4274, name = "Fenrus the Devourer" },
  [2754] = { instanceMapId = 33, npcId = 3927, name = "Wolf Master Nandos" },
  [2755] = { instanceMapId = 33, npcId = 4275, name = "Archmage Arugal" },
  [2756] = { instanceMapId = 34, npcId = 1696, name = "Targorr the Dread" },
  [2757] = { instanceMapId = 34, npcId = 1666, name = "Kam Deepfury" },
  [2758] = { instanceMapId = 34, npcId = 1717, name = "Hamhock" },
  [2759] = { instanceMapId = 34, npcId = 1663, name = "Dextren Ward" },
  [2760] = { instanceMapId = 34, npcId = 1716, name = "Bazil Thredd" },
  [2768] = { instanceMapId = 90, npcId = 7361, name = "Grubbis" },
  [2769] = { instanceMapId = 90, npcId = 7079, name = "Viscous Fallout" },
  [2770] = { instanceMapId = 90, npcId = 6235, name = "Electrocutioner 6000" },
  [2771] = { instanceMapId = 90, npcId = 6229, name = "Crowd Pummeler 9-60" },
  [2772] = { instanceMapId = 90, npcId = 7800, name = "Mekgineer Thermaplugg" },
  [2774] = { instanceMapId = 47, npcId = 4424, name = "Aggem Thorncurse" },
  [2775] = { instanceMapId = 47, npcId = 4428, name = "Death Speaker Jargba" },
  [2776] = { instanceMapId = 47, npcId = 4420, name = "Overlord Ramtusk" },
  [2777] = { instanceMapId = 47, npcId = 4422, name = "Agathelos the Raging" },
  [2778] = { instanceMapId = 47, npcId = 4421, name = "Charlga Razorflank" },
  [2779] = { instanceMapId = 189, npcId = 4543, name = "Bloodmage Thalnos" },
  [2780] = { instanceMapId = 129, npcId = 7355, name = "Tuten'kash" },
  [2782] = { instanceMapId = 129, npcId = 7357, name = "Mordresh Fire Eye" },
  [2783] = { instanceMapId = 129, npcId = 7354, name = "Ragglesnout" },
  [2784] = { instanceMapId = 129, npcId = 8567, name = "Glutton" },
  [2785] = { instanceMapId = 129, npcId = 7358, name = "Amnennar the Coldbringer" },
  [2789] = { instanceMapId = 230, npcId = 8929, name = "Princess Moira Bronzebeard" },
  [2790] = { instanceMapId = 230, npcId = 9019, name = "Emperor Dagran Thaurissan" },
  [2792] = { instanceMapId = 429, npcId = 14354, name = "Pusillin" },
  [2801] = { instanceMapId = 289, npcId = 1853, name = "Darkmaster Gandling" },
  [2802] = { instanceMapId = 289, npcId = 11261, name = "Doctor Theolen Krastinov" },
  [2803] = { instanceMapId = 289, npcId = 10505, name = "Instructor Malicia" },
  [2804] = { instanceMapId = 289, npcId = 10503, name = "Jandice Barov" },
  [2805] = { instanceMapId = 289, npcId = 10506, name = "Kirtonos the Herald" }, -- DungeonEncounter name: Kirtonos
  [2806] = { instanceMapId = 289, npcId = 10502, name = "Lady Illucia Barov" },
  [2807] = { instanceMapId = 289, npcId = 10504, name = "Lord Alexei Barov" },
  [2808] = { instanceMapId = 289, npcId = 10901, name = "Lorekeeper Polkelt" },
  [2809] = { instanceMapId = 289, npcId = 10433, name = "Marduk Blackpool" },
  [2810] = { instanceMapId = 289, npcId = 10508, name = "Ras Frostwhisper" }, -- DungeonEncounter name: Ras Frostwhisperer
  [2811] = { instanceMapId = 289, npcId = 11622, name = "Rattlegore" },
  [2812] = { instanceMapId = 289, npcId = 10507, name = "The Ravenian" },
  [2813] = { instanceMapId = 289, npcId = 10432, name = "Vectus" },
  [2910] = { instanceMapId = 48, npcId = 4829, name = "Aku'mai" },
  [2911] = { instanceMapId = 48, npcId = 4832, name = "Twilight Lord Kelris" },
  [2912] = { instanceMapId = 48, npcId = 4830, name = "Old Serra'kis" },
  [2913] = { instanceMapId = 48, npcId = 12902, name = "Lorgus Jett" },
  [2915] = { instanceMapId = 48, npcId = 4831, name = "Lady Sarevess" },
  [2916] = { instanceMapId = 48, npcId = 4887, name = "Ghamoo-ra" },
  [3062] = { instanceMapId = 229, npcId = 9816, name = "Pyroguard Emberseer" },
  [3063] = { instanceMapId = 229, npcId = 10429, name = "Warchief Rend Blackhand" },
  [3068] = { instanceMapId = 229, npcId = 10430, name = "The Beast" },
  [3069] = { instanceMapId = 229, npcId = 10363, name = "General Drakkisath" },
  [3298] = { instanceMapId = 2959, npcId = 245999, name = "Arcane Anomaly" },
  [3299] = { instanceMapId = 2959, npcId = 246003, name = "Fel Ancient" },
  [3300] = { instanceMapId = 2959, npcId = 246008, name = "Mana Devourer" },
  [3302] = { instanceMapId = 2959, npcId = 246017, name = "Unstable Sentinel" },
  [3303] = { instanceMapId = 2959, npcId = 246020, name = "Shade of the Archmage" },
  [3310] = { instanceMapId = 2959, npcId = 247032, name = "Lyn the Ignored" },
  [3311] = { instanceMapId = 2959, npcId = 247126, name = "Atrexis the Grave Knight" },
  [3353] = { instanceMapId = 2999, npcId = 250483, name = "Witherfang" },
  [3354] = { instanceMapId = 2999, npcId = 250657, name = "Rath'mael" },
  [3355] = { instanceMapId = 2999, npcId = 250660, name = "The Baron" }, -- DungeonEncounter name: The Butcher
  [3357] = { instanceMapId = 2999, npcId = 250631, name = "The Abandoned" },
  [3408] = { instanceMapId = 2999, npcId = 255699, name = "Lordaeron Captain" },
  [3411] = { instanceMapId = 2999, npcId = 256035, name = "Viktor the Vile" },
  [3412] = { instanceMapId = 2999, npcId = 256097, name = "Bjork" },
  [3480] = { instanceMapId = 2998, npcId = 260322, name = "Saltspine" },
  [3481] = { instanceMapId = 2998, npcId = 260325, name = "Shadetooth" },
  [3482] = { instanceMapId = 2998, npcId = 260326, name = "Relic Guardian" },
  [3493] = { instanceMapId = 3065, npcId = 261306, name = "Faldrim Anvilmar" },
  [3494] = { instanceMapId = 3065, npcId = 261311, name = "Plunder" },
  [3495] = { instanceMapId = 3065, npcId = 261316, name = "Magmatus" }, -- DungeonEncounter name: Infurnus
  [3496] = { instanceMapId = 3065, npcId = 261319, name = "Durgen Dirgehammer" },
  [3584] = { instanceMapId = 109, npcId = 5709, name = "Shade of Eranikus" },
  [3585] = { instanceMapId = 109, npcId = 5722, name = "Hazzas" },
  [3586] = { instanceMapId = 109, npcId = 5719, name = "Morphaz" },
  [3644] = { instanceMapId = 2998, npcId = 260808, name = "Highland Horror" },
}



function CrusaderStrikeBosses.LookupByEncounter(gameVersion, encounterId)
  -- gameVersion reserved for future multi-version maps; Forever-only today.
  local row = CrusaderStrikeBosses.byEncounterId and CrusaderStrikeBosses.byEncounterId[encounterId]
  if not row then
    return nil
  end
  return row
end

function CrusaderStrikeBosses.IsFinalBossByEncounter(gameVersion, encounterId)
  local row = CrusaderStrikeBosses.LookupByEncounter(gameVersion, encounterId)
  if not row then
    return false
  end
  return CrusaderStrikeBosses.IsFinalBoss(gameVersion, row.instanceMapId, row.npcId)
end

function CrusaderStrikeBosses.GetTable(gameVersion)
  local v = gameVersion or CrusaderStrikeBosses.defaultVersion
  return CrusaderStrikeBosses.byVersion[v] or CrusaderStrikeBosses.byVersion.forever
end

function CrusaderStrikeBosses.Lookup(gameVersion, instanceMapId, npcId)
  local t = CrusaderStrikeBosses.GetTable(gameVersion)
  local dungeon = t and t[instanceMapId]
  if not dungeon then
    return nil, nil
  end
  return dungeon.bosses[npcId], dungeon
end

function CrusaderStrikeBosses.IsFinalBoss(gameVersion, instanceMapId, npcId)
  local t = CrusaderStrikeBosses.GetTable(gameVersion)
  local dungeon = t and t[instanceMapId]
  return dungeon and dungeon.finalNpcId == npcId or false
end

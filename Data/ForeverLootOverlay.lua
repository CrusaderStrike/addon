-- Hand-curated Forever loot overlay for the character-pane gear browser.
--
-- AtlasLoot Classic's AtlasLootClassic_DungeonsAndRaids data.lua (GPL-2.0) is a
-- layout reference only. Do not copy Atlas Loot Lua wholesale into this addon.
-- Shape we mirror (our own tables, not theirs):
--   dungeon string key
--     InstanceID  -- preferred lookup key; Forever instanceMapId
--     MapID       -- stored when known; never used as the lookup key
--     items[]     -- bosses
--       npcID
--       [difficulty] = { { slotIndex, itemID }, ... }
--         slotIndex is the Atlas button position, not a paper-doll inv slot.
--         difficulty 1 is Forever Normal (docs/sources.md, MapDifficulty.db2).
--
-- This file is the overlay for dungeons Atlas does not have and for drops that
-- differ on Forever. It wins over any future baseline of the same shape
-- (Logic/GearBrowser.lua). Item IDs must be re-verified the same way as
-- Data/Loot.lua — see docs/loot-data.md and docs/sources.md. Do not invent IDs.
--
-- Verified item rows below are copied from Data/Loot.lua (Ragefire Chasm only).
-- Every other Forever/Classic dungeon with a Map.db2 id is listed by
-- Logic/GearBrowser.lua from Data/Bosses.lua (empty loot until verified).
-- Do not invent item IDs. Pending dungeons with no map id stay unlisted.

CrusaderStrikeForeverLootOverlay = CrusaderStrikeForeverLootOverlay or {}

CrusaderStrikeForeverLootOverlay.byVersion = {
  forever = {
    RagefireChasm = {
      name = "Ragefire Chasm",
      verified = true,
      InstanceID = 389,
      MapID = 389,
      items = {
        {
          name = "Oggleflint",
          npcID = 11517,
          [1] = {
            { 1, 272999 },
            { 2, 272998 },
            { 3, 272996 },
          },
        },
        {
          name = "Taragaman the Hungerer",
          npcID = 11520,
          [1] = {
            { 1, 14145 },
            { 2, 14148 },
            { 3, 14149 },
          },
        },
        {
          name = "Jergosh the Invoker",
          npcID = 11518,
          [1] = {
            { 1, 14147 },
            { 2, 14150 },
            { 3, 14151 },
          },
        },
        {
          name = "Bazzalan",
          npcID = 11519,
          [1] = {
            { 1, 273003 },
            { 2, 273005 },
            { 3, 273007 },
          },
        },
      },
    },
  },
}

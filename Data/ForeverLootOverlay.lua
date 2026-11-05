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
-- The table below is an example shape, not a dungeon import. Only Oggleflint's
-- rares are listed, and only because those item IDs are already verified in
-- Data/Loot.lua (Ragefire Chasm, instanceMapId 389).

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
      },
    },
  },
}

# Character pane gear tab (scaffold)

Wishlist builder on the Forever character pane (addon#2, related to the addon#25
redesign). This is not an equip system. There is no Equip button and no sync
with the game's Equipment Manager (that sidebar already exists on the character
sheet).

The addon stays Lua-only. `Character/GearTab.lua` builds the tab with
`CreateFrame` and appends it at runtime. An XML child would not insert into
`CharacterFrame.ModeTabs`, which Forever creates itself.

## Where it sits

Forever 1.60.1 uses the Camelot character frame
(`Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua` in the Forever UI source).
Mode tabs are the vertical side tabs `CharacterFrameModeTab1`–`6`
(Character, Reputation, Skills, PvP, Currency, Statistics). This addon adds the
next tab.

Selecting it keeps `PaperDollFrame` visible and opens
`CrusaderStrikeCharacterGearFrame` on top of the non-slot areas:

- **Gear Sets** and **Browser** are 42px icons on the right-pane header, in the
  same strip as `PaperDollSidebarTabs` (Character Stats / Equipment Manager /
  Titles). Names are tooltips. The level/class line stays on the left pane
  (`CharacterLevelText` / `PaperDollLevelInfo`).
- The mode tab icon is `assets/logo.tga` (the Crusader Strike shield, gold so
  it reads on the dark side tab). Gear Sets uses `INV_Misc_Gear_01`. Browser
  uses `INV_Misc_Bag_08`.
- Paper-doll slots are the real buttons (`CharacterHeadSlot`,
  `CharacterNeckSlot`, … `CharacterTabardSlot` on `PaperDollItemsFrame`).
  Clicks are `HookScript` post-hooks, not `SetScript` replacements. Clicking a
  slot opens the browser filtered to that gear slot (Head, and so on) via
  `CrusaderStrikeLoot` slot names. The hook does not call equip APIs.
- `ShowSubFrame` is observed with `hooksecurefunc` and CS enter work runs on
  `C_Timer.After(0)`. The addon does not call `CharacterFrame:RefreshDisplay`.
- Right side (`CharacterFrame.RightPaneHost`), under the icon row: live stat
  totals. The scaffold shows classic stat names and a filled-slot count.
  Totals are not computed yet.
- Center of the doll (between the slot columns, below the level line, above
  the weapon row): the gear-set list or the browser.

`/cs geartab` opens the tab. Closing the character frame or picking another
mode tab disables the wishlist post-hooks. Blizzard's own slot scripts stay
installed.

## Loot data

AtlasLoot Classic `AtlasLootClassic_DungeonsAndRaids` `data.lua` is **GPL-2.0**.
Use it as a **layout reference only**. Do not copy Atlas Loot Lua wholesale.

Structure we mirror, in our own tables:

- Dungeon string keys.
- `InstanceID` and `MapID` on the dungeon. Forever lookups prefer `InstanceID`,
  set to `instanceMapId` (the same id `Data/Loot.lua` and `Data/Bosses.lua` use).
  `MapID` is not a fallback key.
- `items[]` bosses with `npcID`.
- Difficulty buckets whose rows are `{slotIndex, itemID}`.
  `slotIndex` is the Atlas button position, not a paper-doll inventory slot.
  Bucket `1` is Forever Normal (`docs/sources.md`).

`Logic/GearBrowser.lua` holds an **empty baseline** of that shape.
`Data/ForeverLootOverlay.lua` is the hand-curated overlay for extra Forever
dungeons and changed drops. The overlay replaces a baseline dungeon with the
same string key. The checked-in overlay is one example: Oggleflint in Ragefire
Chasm, using item IDs already verified in `Data/Loot.lua`. Re-verify any new
Forever item ID the same way (`docs/loot-data.md`, `docs/sources.md`). Do not
invent IDs.

The browser filters by dungeon (`InstanceID`), by paper-doll gear slot, or
searches by item name or item ID. Names and loot slots come from
`CrusaderStrikeLoot.LookupItem`. The shipped overlay has no Head items yet, so
a head click shows an empty Head list until a verified head drop is added.

## Next implementation step

Wire wishlist slot clicks through to real preview stats: when a browser row
assigns an item onto the selected paper-doll slot, resolve that item's Forever
stats and sum them in the right-hand panel. The click path already stores the
preview (`CharacterGearTab.AssignPreviewItem`) and refreshes the panel; the
totals function is still a placeholder. After that, extend
`Data/ForeverLootOverlay.lua` with hand-verified dungeons — still no Atlas copy,
and still no Equipment Manager sync.

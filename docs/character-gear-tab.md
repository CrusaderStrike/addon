# Character pane gear tab

Gear-set builder for Forever (addon#2, related to the addon#25 redesign).
Crusader Strike is **its own window**, parented to `UIParent`, with its own
size and chrome. It is not an overlay on `CharacterFrame` and not a paper-doll
silhouette: no portrait, no player model, no `SetAllPoints(CharacterFrame)`.
Opening it does not resize, cover, or restyle the Character / PaperDoll tab.
There are no shared slot buttons, no script swaps on Blizzard frames, and no
Equipment Manager sync. Left-click a browser item to equip it into the current
gear set; right-click a CS gear-set slot to unequip.

The addon stays Lua-only. `Character/GearTab.lua` builds
`CrusaderStrikeCharacterGearFrame` with `CreateFrame`.

## Where it sits

Forever 1.60.1 uses the Camelot character frame
(`Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua` in the Forever UI source).
Mode tabs are the vertical side tabs `CharacterFrameModeTab1`–`6`
(Character, Reputation, Skills, PvP, Currency, Statistics). **This addon does
not append a seventh ModeTabs.Tabs entry** (that injection caused Character
open taint). It **does** reuse `CharacterFrameModeSideTabTemplate` for the
launcher chrome only.

- A CS-owned toggle (`CrusaderStrikeGearTabToggle`) is parented to `ModeTabs`
  with `CharacterFrameModeSideTabTemplate`, anchored under the last Forever
  side tab (`TOPLEFT` → last tab `BOTTOMLEFT`, 2px gap) so the logo sits in
  the strip. The Tabs table is never mutated. Logo: `assets/logo.tga`.
  Clicking it shows or hides the CS window. It does not select a mode tab.
- `/cs geartab` opens the same window even when `CharacterFrame` is closed.
  CS never calls `ShowUIPanel`, `CharacterFrame:Show`, `ShowSubFrame`,
  `SetSelectedModeTabByFrame`, `Expand`, `RefreshDisplay`, or
  `SecureActionButton:Click`.
- There is **no** `hooksecurefunc` on `CharacterFrame.ShowSubFrame`, `OnShow`,
  or `OnHide`. The CS window is a `HIGH` strata frame centered on `UIParent`
  (offset so it is not stacked on the character sheet), titled "Crusader
  Strike", movable, and closed with the Close button or Escape.
- The left pane is the CS gear-set doll. **Gear Sets**, **Browser**, and
  **Stats** are a right-side pop-out (`CrusaderStrikeGearPopout`), the same
  arrangement as PaperDoll stats / equipment manager / titles: main pane on
  the left, pane attached to the frame's right edge. 42px icons on the main
  pane (`INV_Misc_Gear_01`, `INV_Misc_Bag_08`, `INV_Misc_Note_01`) toggle it.
  Names are tooltips. Clicking the open pane's icon closes the pop-out and
  hides all three panels so nothing draws on the doll.
- Pop-out content is anchored to the pop-out (dungeon list stretches to the
  browser panel, search matches the list width, the result grid fills the
  pane's inner width). It is not positioned with a fixed offset inside the
  doll.
- Gear-set slots are **CS-owned buttons** (`CrusaderStrikeHeadSlot` …
  `CrusaderStrikeTabardSlot` on `CrusaderStrikeGearDoll`). They never share
  frames or scripts with `CharacterHeadSlot` / PaperDoll. Left-click selects
  the slot (opens Browser filtered to that slot). Right-click unequips /
  clears the slot on the current gear set via `CrusaderStrikeGearSets.SetSlot`.
- Browser icons resolve through `C_Item.GetItemIconByID` / `GetItemIcon` /
  `GetItemInfoInstant`, with `RequestLoadItemDataByID` +
  `GET_ITEM_INFO_RECEIVED` so Forever item textures replace the question-mark
  placeholder once the client has them. Tooltips stay on
  `GameTooltip:SetItemByID`.
- Left-click a browser item **equips** it into the current gear set (preview
  slots + `SetSlot` when a set is selected). This is gear-set state, not the
  game's EquipItem / Equipment Manager APIs.
- The dungeon control is a **scrollable list** of dungeon names (All + every
  indexed dungeon) — not a cycling button or a menu of `UIPanelButtonTemplate`
  options. Name / item-ID search stays.
- Browser layout chains off the dungeon list, which stretches to the pop-out:
  search matches that width, a status line sits under the search, then a
  **scrollable icon grid** (`CrusaderStrikeGearResultScroll`) whose column
  count fills the pop-out inner width. There is no hard 8-row cap; every
  matching Forever-overlay item is reachable.
- Stats pane shows classic stat name placeholders and a filled-slot count.
  Totals are not computed yet.

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
same string key. The checked-in overlay is one example: Ragefire Chasm (all
four bosses), using item IDs already verified in `Data/Loot.lua`. Re-verify any
new Forever item ID the same way (`docs/loot-data.md`, `docs/sources.md`). Do
not invent IDs.

The browser filters by dungeon (`InstanceID`), by gear-set slot, or searches by
item name or item ID. Names and loot slots come from
`CrusaderStrikeLoot.LookupItem`. The shipped overlay has no Head items yet, so
a head click shows an empty Head list until a verified head drop is added.

## Next implementation step

Wire gear-set slot fills through to real preview stats: when a browser row
equips an item onto a CS slot, resolve that item's Forever stats and sum them
in the Stats pane. The equip path already stores the slot
(`CharacterGearTab.EquipItem`) and refreshes the panel; the totals function is
still a placeholder. After that, extend `Data/ForeverLootOverlay.lua` with
hand-verified dungeons — still no Atlas copy, and still no Equipment Manager
sync.

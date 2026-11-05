# Character pane gear tab

Gear-set builder for Forever (addon#2, related to the addon#25 redesign).
Crusader Strike is a mode-tab sibling of Character, Reputation, Skills, PvP,
Currency, and Statistics. `CrusaderStrikeCharacterGearFrame` is a content pane
on `CharacterFrame`, in the rectangle PaperDoll uses. It is not a
`SetAllPoints` cover and it does not paint over the side-tab strip. There are
no shared slot buttons, no script swaps on Blizzard frames, and no Equipment
Manager sync. Left-click a browser item to equip it into the current gear set;
right-click a CS gear-set slot to unequip.

The addon stays Lua-only. `Character/GearTab.lua` builds the pane with
`CreateFrame`.

## Where it sits

Forever 1.60.1 uses the Camelot character frame
(`Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua` in the Forever UI source).
Mode tabs are the vertical side tabs `CharacterFrameModeTab1`–`6`
(Character, Reputation, Skills, PvP, Currency, Statistics). **This addon does
not append a seventh ModeTabs.Tabs entry** (that injection caused Character
open taint). It **does** reuse `CharacterFrameModeSideTabTemplate` for the
logo button in the strip.

- `CrusaderStrikeGearTabToggle` is parented to `ModeTabs` with
  `CharacterFrameModeSideTabTemplate`, anchored under the last Forever side
  tab. Logo: `assets/logo.tga`. The Tabs table is never written.
- Selecting it hides `CharacterFrame.activeSubframe` (`_G[name]:Hide()`) and
  shows `CrusaderStrikeCharacterGearFrame`. It unchecks the existing mode
  tabs with a read-only walk. It does not call `ShowSubFrame`.
- An observe-only `hooksecurefunc(CharacterFrame, "ShowSubFrame", …)` hides
  the CS pane and unchecks the logo button when Forever switches tabs. The
  original `ShowSubFrame` is not replaced. One click on Statistics (or any
  other mode tab) leaves CS.
- `/cs geartab` selects the same tab only while `CharacterFrame` is already
  shown. CS never calls `ShowUIPanel`, `CharacterFrame:Show`, `ShowSubFrame`,
  `SetSelectedModeTabByFrame`, `Expand`, `RefreshDisplay`, or
  `SecureActionButton:Click`.
- Close and Escape leave CS and show the previous pane (`PaperDollFrame` if
  none was recorded).
- Inside the pane, the left side is the CS gear-set doll. **Gear Sets**,
  **Browser**, and **Stats** are a right column (`CrusaderStrikeGearPopout`).
  42px icons (`INV_Misc_Gear_01`, `INV_Misc_Bag_08`, `INV_Misc_Note_01`)
  toggle it. Names are tooltips. Clicking the open pane's icon closes the
  column so nothing draws on the doll.
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

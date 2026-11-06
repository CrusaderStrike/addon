# Loot browser + wish-list data format (addon#2)

WoW Forever only. SavedVariables schema version **3** adds
`CrusaderStrikeCharDB.wishLists`. Bundled loot lives in `Data/Loot.lua`.

## Bundled loot table (`CrusaderStrikeLoot`)

```lua
CrusaderStrikeLoot.byVersion.forever[instanceMapId] = {
  name = "Ragefire Chasm",
  verified = true,  -- false / omit when IDs are not Forever-confirmed
  bosses = {
    {
      npcId = 11517,           -- creature ID (matches Data/Bosses.lua)
      name = "Oggleflint",
      order = 1,
      items = {
        {
          itemId = 272999,     -- Forever item ID — never invent
          name = "Barbaric Crossbow",
          slot = "Ranged",     -- one of CrusaderStrikeLoot.SLOTS values
          quality = 3,         -- 0 poor .. 5 legendary
        },
      },
    },
  },
}
```

Helpers:

| Function | Role |
|----------|------|
| `GetDungeon(gameVersion, mapId)` | One dungeon table |
| `ListDungeons(gameVersion)` | Sorted `{instanceMapId, name, verified, itemCount}` |
| `FilterDungeon(dungeon, {search=, slot=})` | Boss list with filtered items |
| `LookupItem(gameVersion, itemId)` | `item, boss, dungeon, mapId` |

### Verification policy

Same as `docs/sources.md`: item IDs must come from Wowhead Forever, Forever
client/DB2 exports, or another Forever-cited database (e.g. questing.wiki Forever
item pages). **Do not invent item IDs.** Dungeons without a verified table stay
out of `Data/Loot.lua` (or ship with `verified = false` and empty `items`) until
IDs are confirmed.

### Coverage in v0.2.0

| Map ID | Dungeon | Status |
|--------|---------|--------|
| 389 | Ragefire Chasm | **Verified** boss rares (12 items) |
| others | Classic-lineage + new Forever dungeons | TODO(unverified) — no invented IDs |

RFC sources (2026-10 / 2026-11):

- questing.wiki Forever NPC/item records for Oggleflint (272996/272998/272999) and
  Bazzalan (273003/273005/273007)
- Ladderly Forever beta-client pages for Taragaman/Jergosh Classic-retained IDs
  (14145–14151)
- Wowhead Forever RFC overview loot table (names / boss mapping)

## Wish lists (`CrusaderStrikeCharDB.wishLists`)

Per-character, keyed by `tostring(instanceMapId)`:

```lua
CrusaderStrikeCharDB.wishLists = {
  ["389"] = {
    items = {
      { itemId = 14145, bossNpcId = 11520, obtained = false, order = 1 },
    },
  },
}
```

Pure helpers in `Logic/WishList.lua`: `Add`, `Remove`, `Reorder`, `MarkObtained`,
`MarkObtainedAny`, `IsWished`, `GetDungeonList`, `WantedCount`, `WantedItemIds`.

## UI / commands

- `/cs loot [mapId]` or `/cs wishlist` — open the browser (`LootBrowser.lua`)
- `/cs geartab` — standalone Crusader Strike gear window (`Character/GearTab.lua`).
  AtlasLoot Classic `data.lua` is a GPL-2.0 layout reference only (do not copy
  it wholesale). Forever drops go through `Data/ForeverLootOverlay.lua`. See
  `docs/character-gear-tab.md`.
- Search box + slot filter cycle (All → Weapon → …)
- Add / Remove on loot rows; wish-list view toggles obtained on click;
  Shift/Alt-click reorders
- While inside a dungeon, the banner notes remaining wanted items
- `CHAT_MSG_LOOT` auto-marks matching wish-list items obtained (no CLEU), but
  only on the player's own lines: the message must match a self-loot pattern
  built from the localized `LOOT_ITEM_SELF`, `LOOT_ITEM_SELF_MULTIPLE`,
  `LOOT_ITEM_PUSHED_SELF`, `LOOT_ITEM_PUSHED_SELF_MULTIPLE`,
  `LOOT_ITEM_CREATED_SELF` or `LOOT_ROLL_YOU_WON` globals, and the event's
  looter name (arg 5), when present, must equal `UnitName("player")`. Party and
  raid loot lines never mark an item obtained.

Optional platform sync of wish lists is out of scope for v0.2.0 (see
CrusaderStrike/platform#3). When it is scoped, wire it to the platform's
`/gear-lists` + `/sync` endpoints (event-sourced web wish lists), not
`/uploads`, which carries runs and PvP only.

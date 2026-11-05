# Forever in-game event check (dungeon detection)

WoW Forever **1.60.1** blocks addon use of the combat log. Registering
`COMBAT_LOG_EVENT_UNFILTERED` or calling `CombatLogGetCurrentEventInfo` raises
`ADDON_ACTION_BLOCKED` ("Crusader Strike has been blocked from an action only available
to the Blizzard UI"). **`pcall` does not prevent that popup.** This addon therefore
never registers CLEU and never calls combat-log APIs. Boss kills and party deaths use
only the non-CLEU signals below.

Related: groomed P0 tickets `addon-dungeon-combatlog.md` and `addon-p0-remove-cleu.md`
(in-game popup follow-up).

## Install

1. Copy this addon into `Interface/AddOns/CrusaderStrike` (or your usual Forever AddOns path).
2. Confirm TOC `## Interface: 16001` and `## AllowLoadGameType: forever, camelot`.
3. Log in on Forever 1.60.1. `/reload`, then confirm there is **no** "action blocked" /
   Blizzard-UI popup from Crusader Strike. `/cs status` should print without errors.

## Capture events

1. Enter a 5-player dungeon with at least one other party member if you can.
2. Run: `/cs debug events on`
3. Pull and kill at least one boss (ideally the final boss too). Confirm the kill is logged.
4. Have a party member die once, release spirit, and resurrect (or rez in place). Confirm the death is logged once.
5. Optionally wipe on a boss (to confirm wipes are **not** counted as kills).
6. Run: `/cs debug events dump`
7. Screenshot or copy the dump lines, plus `/cs status` and `/cs export` for the run.

## What to report

From the dump, note whether each of these fired and with what args:

| Signal | Expected use |
|--------|----------------|
| `ENCOUNTER_START` / `ENCOUNTER_END` | Primary boss tracking; `success=1` kill, `success=0` wipe |
| `BOSS_KILL` | Secondary kill signal (encounterID + name) |
| `INSTANCE_ENCOUNTER_ENGAGE_UNIT` | Fallback: boss1–5 tokens engaged |
| `UNIT_HEALTH` / `UNIT_FLAGS` on `bossN` | Fallback kill when a boss unit goes dead |
| `PLAYER_DEAD` | Player death (may fire twice — should count once) |
| `UNIT_HEALTH` / `UNIT_FLAGS` on `partyN` | Party deaths without CLEU |

`COMBAT_LOG_EVENT_UNFILTERED` must **not** appear (the addon does not register it).

Also confirm in `/cs status` / export:

- Each boss kill appears once in `bosses[]`.
- Wipes did **not** add a boss.
- Each party death appears once (release + rez did not double-count).
- Final boss sets `completed=true` / status completed (or closed after leave per existing rules).

## Turn off

`/cs debug events off` (or `clear` to empty the buffer). The buffer lives in
`CrusaderStrikeDB.debugEvents` (capped at ~500 entries).

## Gear sets morning check (addon#26 / #29)

Owner: in-game Forever client. Relates to addon#25 / #29.

Checklist:

1. **Item link field order** — Equip an enchanted item (and ideally one with a random suffix if available). `/cs export`, copy the CSGEAR1 line, and confirm `equipped.*.item_id` / `enchant_id` match the item. Field indices live in `Logic/GearEncoder.lua` (`ITEM_LINK_FIELDS`). Update that table + this note if Forever differs.
2. **`/cs gearsets` UI** — Layout renders; shift-click an item into chat and paste/assign into a set slot.
3. **Round-trip** — Export CSGEAR1 → paste on the live site (armory / gear-lists) → export back from the site → `/cs import` on the same character. Confirm `local_id` links to the server `id`, sets match, and any `item_not_forever` / `list_limit_reached` / `character_mismatch` messages are clear (not raw codes).

Done when all three pass, or when any failure is written up on the related issue.

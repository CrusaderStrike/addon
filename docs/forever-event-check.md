# Forever in-game event check (dungeon detection)

WoW Forever **1.60.1** protects combat-log reads (`CombatLogGetCurrentEventInfo` is
absent from the Forever global API / relocated to the secure environment). Dungeon
boss kills and party deaths therefore use non-CLEU signals. This checklist is for
Drew (or anyone with the Forever client) to confirm the rework in a real dungeon.

Related: groomed P0 ticket `addon-dungeon-combatlog.md`; Drew follow-up ticket
(SnipyWoW) for the live check.

## Install

1. Copy this addon into `Interface/AddOns/CrusaderStrike` (or your usual Forever AddOns path).
2. Confirm TOC `## Interface: 16001` and `## AllowLoadGameType: forever, camelot`.
3. Log in on Forever 1.60.1. `/cs status` should print without errors; the chat should
   **not** show "action blocked" / taint from CrusaderStrike.

## Capture events

1. Enter a 5-player dungeon with at least one other party member if you can.
2. Run: `/cs debug events on`
3. Pull and kill at least one boss (ideally the final boss too).
4. Have a party member die once, release spirit, and resurrect (or rez in place).
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
| `COMBAT_LOG_EVENT_UNFILTERED` | Debug only: whether it fired, and `cleu=false` / `missing` / error |

Also confirm in `/cs status` / export:

- Each boss kill appears once in `bosses[]`.
- Wipes did **not** add a boss.
- Each party death appears once (release + rez did not double-count).
- Final boss sets `completed=true` / status completed (or closed after leave per existing rules).

## Turn off

`/cs debug events off` (or `clear` to empty the buffer). The buffer lives in
`CrusaderStrikeDB.debugEvents` (capped at ~500 entries).

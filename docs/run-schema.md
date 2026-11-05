# Crusader Strike dungeon-run schema (draft for platform#3)

**Status:** addon-side proposal for Platform Dev to adopt on [platform#3](https://github.com/CrusaderStrike/platform/issues/3).  
**schemaVersion:** `1`  
**Addon:** CrusaderStrike `0.1.0` (World of Warcraft: Forever only)

## Goals

- Idempotent ingest: the same run never creates two `dungeon_runs` rows.
- Versioned payload the website paste endpoint and a future companion uploader both accept.
- Align with existing platform columns (`addon_run_id`, `dungeon_*`, `started_at`, `completed_at`, `duration_ms`, `success`, `raw_payload`, participants).

## Idempotency key

```
{realm}|{character}|{startTimeUnix}|{instanceId}
```

| Part | Source | Notes |
|------|--------|-------|
| `realm` | `GetNormalizedRealmName()` (fallback `GetRealmName()`) | No spaces; normalized form preferred |
| `character` | `UnitName("player")` at run start | Case as returned by the client |
| `startTimeUnix` | `GetServerTime()` at run start | Integer seconds |
| `instanceId` | `instanceMapID` from `GetInstanceInfo()` | e.g. Deadmines `36` |

Examples:

- `CrusaderStrike|Snipy|1730000000|36`
- `WildGrowth|Aldric|1730001111|389`

**Platform mapping:** set `dungeon_runs.addon_run_id` to this string (also present as `addonRunId` / `idempotencyKey` in JSON). Unique with `guild_id` as today.

## JSON payload (`schemaVersion: 1`)

```json
{
  "schemaVersion": 1,
  "gameVersion": "forever",
  "idempotencyKey": "CrusaderStrike|Snipy|1730000000|36",
  "addonRunId": "CrusaderStrike|Snipy|1730000000|36",
  "realm": "CrusaderStrike",
  "character": "Snipy",
  "instance": {
    "id": 36,
    "name": "The Deadmines",
    "difficulty": 1,
    "difficultyName": "Normal"
  },
  "startedAt": 1730000000,
  "endedAt": 1730001800,
  "durationSec": 1800,
  "completed": true,
  "status": "completed",
  "party": [
    {
      "name": "Snipy",
      "realm": "CrusaderStrike",
      "class": "PALADIN",
      "level": 24,
      "isPlayer": true
    }
  ],
  "bosses": [
    { "npcId": 644, "name": "Rhahk'Zor", "killedAt": 1730000200 },
    { "npcId": 639, "name": "Edwin VanCleef", "killedAt": 1730001700 }
  ],
  "deaths": [
    {
      "name": "Snipy",
      "realm": "CrusaderStrike",
      "time": 1730000500,
      "source": "Defias Pirate"
    }
  ]
}
```

### Field reference

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `schemaVersion` | int | yes | Currently `1` |
| `gameVersion` | string | yes | Must be `"forever"` (World of Warcraft: Forever only). The server rejects any other value with HTTP 400. |
| `idempotencyKey` | string | yes | See above |
| `addonRunId` | string | yes | Same as key for v1; stable alias for DB |
| `realm` / `character` | string | yes | Logger character |
| `instance.id` | int | yes | Map / instance id |
| `instance.name` | string | yes | Display name |
| `instance.difficulty` | int/null | no | Client difficulty id (TODO: confirm Forever difficulty ids) |
| `instance.difficultyName` | string/null | no | |
| `startedAt` / `endedAt` | int/null | start yes | Unix seconds |
| `durationSec` | int/null | no | `endedAt - startedAt` when closed |
| `completed` | bool | yes | Final boss from bundled table killed |
| `status` | string | yes | `in_progress` \| `closed` \| `abandoned` \| `completed` |
| `party[]` | array | yes | Snapshot at start (refreshed on roster change) |
| `bosses[]` | array | yes | Unique by `npcId` |
| `deaths[]` | array | yes | Party player UNIT_DIED events |

### Suggested platform column mapping

| Payload | `dungeon_runs` / participants |
|---------|-------------------------------|
| `addonRunId` | `addon_run_id` |
| `instance.name` | `dungeon_name` |
| `instance.id` | `dungeon_id` |
| `instance.difficultyName` | `difficulty` |
| — | `keystone_level` null (not used in Forever v1) |
| `startedAt` | `started_at` (timestamptz from unix) |
| `endedAt` | `completed_at` |
| `durationSec * 1000` | `duration_ms` |
| `completed` | `success` |
| full JSON | `raw_payload` |
| `party[]` | `run_participants` rows |

Reject or soft-fail payloads with `schemaVersion` > server max. Any `gameVersion` other than `"forever"` is rejected with HTTP 400 (nothing is stored).

## Export string encoding

MVP paste path (no HTTP from the WoW client):

```
CSRUN1:<base64(utf8 json payload)>
```

- Prefix `CSRUN1:` identifies schema family + encoding version.
- Payload is the JSON object above (compact, sorted object keys from the addon encoder).
- Website paste box: strip whitespace, verify prefix, base64-decode, JSON-parse, validate required fields, ingest with `addon_run_id = addonRunId`.

Slash command: `/cs export` (optional key argument). UI is a selectable EditBox.

## SavedVariables layout (companion-ready)

Account file `WTF/Account/<account>/SavedVariables/CrusaderStrike.lua`:

```lua
CrusaderStrikeDB = {
  schemaVersion = 1,
  settings = { resumeWindowSec = 10800, debug = false },
  companion = { lastSeenExportAt = <unix|nil> },
}
```

Per-character `.../<realm>/<char>/SavedVariables/CrusaderStrike.lua`:

```lua
CrusaderStrikeCharDB = {
  schemaVersion = 1,
  gameVersion = "forever",
  activeRunKey = <string|nil>,
  runs = {
    ["Realm|Char|start|instanceId"] = { /* run table matching JSON fields */ },
  },
}
```

A companion uploader can parse these Lua tables, skip keys already ACK'd, and POST the same JSON shape (or the `CSRUN1:` string) to the platform ingest endpoint (`POST /runs` for the JSON, `POST /runs/import` for the `CSRUN1:` string; see platform#18 OpenAPI v1).

## Run lifecycle (addon)

1. Enter party instance → start run (or resume within `resumeWindowSec` if same `instance.id` and status is `in_progress` or `closed`).
2. While the run is active, bump internal `lastSeenAt` on combat events and zone/login pulses (not exported).
3. `COMBAT_LOG_EVENT_UNFILTERED` / `UNIT_DIED`:
   - Creature GUID NPC id in bundled Forever boss table (`Data/Bosses.lua`) → boss kill; final boss ⇒ `completed=true`.
   - Party player death → `deaths[]`.
4. Leave instance cleanly → `status=closed` (or remains `completed`), clear `activeRunKey`, keep row in `runs`.
5. Stale `in_progress` cleanup (addon#8): on `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD` / zone change, any `in_progress` run that does **not** match the current party instance (or whose `lastSeenAt` is outside `resumeWindowSec`) is closed as `status=abandoned`, `completed=false`, `endedAt=lastSeenAt` (no fake duration from a later login). `/reload` or reconnect inside the same instance within the window resumes; abandoned runs never resume.
6. Platform ingest (platform#18): a later fuller export with the same `addonRunId` upserts an unfinished row, so an abandoned paste can be replaced if the player later finishes and re-exports a completed run under a **new** key (new `startedAt`). Same-key richer updates still apply while a run stays unfinished under one id.

## Open decisions for Platform Dev

1. ~~Should ingest **update** an existing run when a richer payload arrives with the same `addon_run_id`~~ Resolved (platform#18): unfinished runs upsert; a richer payload with the same `addon_run_id` replaces the stored row.
2. Guild association on paste: Battle.net / guild invite code / character claim — out of scope for the addon; endpoint must define auth.
3. Max payload size and retention for `raw_payload`.
4. ~~Whether `gameVersion` becomes a first-class column~~ Resolved: stored as `game_version` (const `forever`) per platform#18.

## Change log

| schemaVersion | Notes |
|---------------|-------|
| 1 | Initial WoW Forever dungeon run schema + `CSRUN1` export |
| 1 | addon#8: `abandoned` status for stale hearth/crash runs; `lastSeenAt` (SavedVariables only) |

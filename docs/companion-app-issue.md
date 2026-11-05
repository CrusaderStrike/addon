# Draft GitHub issue: Companion uploader for CrusaderStrike SavedVariables

> **Do not file until Bot / PM asks.** Draft only (addon#1 follow-up). Platform ingest (`POST /api/v1/uploads`) shipped in platform#32; this draft is unblocked on the API side. Companion-token auth is still a platform follow-up.

## Title

Companion desktop uploader: read CrusaderStrike SavedVariables and POST to `/uploads` (post-MVP)

## Body

### Summary

WoW addons cannot make arbitrary HTTPS requests. MVP upload is `/cs export` → paste into the website (`CSRUN1:` string). We still want a **companion desktop app** that watches the addon's SavedVariables and uploads automatically via `POST /api/v1/uploads`.

### Goals

- Read `WTF/Account/<account>/SavedVariables/CrusaderStrike.lua` and per-character SV files.
- Parse `CrusaderStrikeCharDB.runs` (and `pvp` when ready), build schemaVersion 1 records (see `docs/run-schema.md`, `docs/pvp-schema.md`).
- POST an `AddonUpload` envelope to **`POST /api/v1/uploads`** (`https://api.crusaderstrike.com/api/v1/uploads`) with the same record IDs so retries are safe: dungeon runs send JSON `addonRunId` (stored as column `addon_run_id`); PvP records send `addon_pvp_id` (see `docs/pvp-schema.md`).
- Respect platform caps and limits: whole body ≤ **1 MiB**, `dungeonRuns` ≤ 100, `worldPvp` ≤ 1000, `battlegrounds` ≤ 500, and the **5 s** successful-upload cooldown (`429` + `Retry-After`). Split backlogs across requests.
- Remember acknowledged keys locally (and optionally write back under `CrusaderStrikeDB.companion`) so runs are not double-prompted.
- Cross-platform: Windows first (most WoW Forever players), macOS nice-to-have.
- Never ship user credentials in the addon repo; use the website's OAuth / device login for the companion. Today `/uploads` requires session cookie + CSRF; a dedicated companion `uploaderToken` is a platform follow-up.

### Non-goals (this issue)

- Building the companion in the same milestone as export-string MVP.
- Injecting into the WoW process or memory-reading.
- Supporting any client other than World of Warcraft: Forever (no Retail, Classic Era or Season of Discovery).

### Acceptance criteria

- [ ] Detect WoW install / account folders (manual path override allowed).
- [ ] Parse Lua SavedVariables safely (sandbox; no `loadstring` of untrusted extras).
- [ ] Upload only `status` in `{closed, completed}` unless user opts into in-progress sync.
- [ ] Idempotent against platform dedupe `(character_id, addon_run_id|addon_pvp_id)` (guild is not in the key; re-upload refreshes `guild_id`).
- [ ] Handle `accepted` / `duplicate` / `rejected[]` / `ignored[]` from the `/uploads` response; retry on `429` using `Retry-After`.
- [ ] Document install + first-run auth against crusaderstrike.com.
- [ ] Open source under the CrusaderStrike org (repo TBD: `companion` or `uploader`).

### Design notes from addon#1

- Storage format is already companion-friendly: flat `runs[idempotencyKey] = run`.
- Export encoding `CSRUN1:` remains valid as an alternate website-paste body; batch companion traffic should use `/uploads`, not the deprecated `POST /runs`.
- Resume window and active run keys mean the companion should prefer closed/completed runs.

### Dependencies

- ~~platform#3 upload/ingest API~~ Shipped as `POST /api/v1/uploads` in platform#32 (OpenAPI `uploadAddonData`).
- Companion auth beyond session cookie + CSRF (uploader token / device grant) — platform follow-up; do not block website paste on it.
- Website paste endpoint sharing validation with companion POST (paste may still use deprecated `/runs` until moved).

### Labels (suggested)

`enhancement`, `addon`, `companion`

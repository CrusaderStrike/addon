# Draft GitHub issue: Companion uploader for CrusaderStrike SavedVariables

> **Do not file until Bot / PM asks.** Draft only (addon#1 follow-up).

## Title

Companion desktop uploader: read CrusaderStrike SavedVariables and POST runs (post-MVP)

## Body

### Summary

WoW addons cannot make arbitrary HTTPS requests. MVP upload is `/cs export` → paste into the website (`CSRUN1:` string). We still want a **companion desktop app** that watches the addon's SavedVariables and uploads automatically.

### Goals

- Read `WTF/Account/<account>/SavedVariables/CrusaderStrike.lua` and per-character SV files.
- Parse `CrusaderStrikeCharDB.runs`, build the schemaVersion 1 JSON (see `docs/run-schema.md`).
- POST to the platform ingest endpoint (platform#3) with the same `addon_run_id` / idempotency key so retries are safe.
- Remember acknowledged keys locally (and optionally write back under `CrusaderStrikeDB.companion`) so runs are not double-prompted.
- Cross-platform: Windows first (most WoW Forever players), macOS nice-to-have.
- Never ship user credentials in the addon repo; use the website's OAuth / device login for the companion.

### Non-goals (this issue)

- Building the companion in the same milestone as export-string MVP.
- Injecting into the WoW process or memory-reading.
- Supporting any client other than World of Warcraft: Forever (no Retail, Classic Era or Season of Discovery).

### Acceptance criteria

- [ ] Detect WoW install / account folders (manual path override allowed).
- [ ] Parse Lua SavedVariables safely (sandbox; no `loadstring` of untrusted extras).
- [ ] Upload only `status` in `{closed, completed}` unless user opts into in-progress sync.
- [ ] Idempotent against platform `UNIQUE (guild_id, addon_run_id)`.
- [ ] Document install + first-run auth against crusaderstrike.gg.
- [ ] Open source under the CrusaderStrike org (repo TBD: `companion` or `uploader`).

### Design notes from addon#1

- Storage format is already companion-friendly: flat `runs[idempotencyKey] = run`.
- Export encoding `CSRUN1:` remains valid as an alternate upload body.
- Resume window and active run keys mean the companion should prefer closed/completed runs.

### Dependencies

- platform#3 upload/ingest API + auth story
- Website paste endpoint sharing validation with companion POST

### Labels (suggested)

`enhancement`, `addon`, `companion`, `blocked` (until platform ingest exists)

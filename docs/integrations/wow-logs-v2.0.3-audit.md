# Azeroth Stats v2.0.3 — WoW Logs AS integration: audited baseline and gates

Status: AUDIT IN PROGRESS. No runtime integration is implemented by this checkpoint. Never publish a public v2.0.3 release without owner native acceptance.

## Immutable starting point
- Official `v2.0.2` tag resolves to `5aa51561cbcf5783a7e3a0073df880e729ec7b82`.
- GitHub compare `v2.0.2...main` at kickoff: identical, 0 ahead/behind.
- `AzerothStats/AzerothStats.toc`: Version 2.0.2; SavedVariables `AzerothStatsDB`, `AzerothStatsBackup`, `AzerothStatsAutoBackup`.
- Dedicated feature branch `feat/v2.0.3-wowlogs-integration` created from the official tag.
- No WoW Logs AS dependency or network sender is permitted.

## Direct source findings (v2.0.2)
- `Database.lua` initializes schema-1 `AzerothStatsDB`, validates before mutation, maintains sequence/runs/totals/classes/settings/migrations, preserves favorites and normalizes settings. Do not bump schema merely to add optional metadata.
- `Tracker.lua` creates local IDs `azstats-<sequence>`, stores `identity`, class, hero, zone, heroic, `startedAt`, phase, status, counters, event/timeline, partial flag and packet baselines.
- The tracker currently says no server run UUID exists and resumes a last run **heuristically** if class/hero/zone/difficulty and monotonic server time match. This is not a proof that `AZS_ZONE.run` is absent: the field has not yet been audited.
- `A.Sample()` detects boundaries from ready packets, server time reset, identity/heroic changes, and some counter resets. A mismatch can close the previous run and start a new one; multiple reloads require tests with exact client event sequences.
- `Core.lua` receives ADDON_LOADED, VARIABLES_LOADED, CHAT_MSG_ADDON, PLAYER_LOGOUT and PLAYER_ENTERING_WORLD; PLAYER_LOGOUT samples and checkpoints, but the client controls when SavedVariables are flushed to disk.
- `DataManagement.lua` separates manual/automatic backups; restore validates a candidate and rolls back database pointers on failed initialization. Do not include either backup root in an external export.
- `V2Data.lua` contains per-run V2 persistence and explicitly avoids traversing the whole SavedVariables tree on every sample.
- `Database.lua` constrains retained runs to 10–1000, auto-backup retention 1–15 and cadence 0–20 completed runs. These defaults and existing data must survive.

## Unproven / external validation required
1. `AZS_ZONE.run` type, lifecycle, uniqueness, reload/restart behavior and desktop/browser parity: **NOT VERIFIED**. Do not equate it with a globally unique UUID or use it alone to merge runs.
2. Exact behavior of native reload under multiple transitions and whether the game resets counters: **NOT TESTED IN GAME**.
3. Real 2.0.2 SavedVariables size/latency and large-save restore: **NO MEASURED BASELINE**.
4. WoW Logs AS correlation keys, schema expectations and uploader privacy rules: **RAKESH CONFIRMATION PENDING**.

## Proposed contract principles (not yet implemented)
- Versioned, opt-in/on-demand normalized view of existing retained runs, without a second full history or embedded backups.
- Distinguish absent from zero and observed/calculated/inferred data; document timestamp units and provenance.
- Treat native run ID as optional and potentially collision-prone. Use conservative correlation hints (zone, difficulty, class, time window, local ID) and confidence, not forced identity.
- Never include partner names or personal identifiers by default. No automatic upload, backend, HTTP or mandatory second addon.
- Provide fixture-only examples clearly labeled synthetic.

## Release and regression gates
1. Finish source and native API audit; obtain game API evidence before implementing native-ID semantics.
2. Add fixtures and tests for normal/terminal/interrupted/reloaded/coop/legacy/missing-data runs.
3. Prove v2.0.2 data preservation, backup isolation and export size/performance.
4. Validate FR/EN and existing views; retain the accepted HUD and portrait behavior.
5. Deliver a CI-green installable ZIP for owner native recipe, **not** a public release.

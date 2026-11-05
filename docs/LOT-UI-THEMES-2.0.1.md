# AzerothStats 2.0.1 — Lot UI / themes / navigation

Status: IN PROGRESS. Began after HUD native 9/9 PASS on 2026-11-05. Work on PR #31 branch `feat/v2.0.1-aviiva-feedback`. Do not modify accepted HUD layout unless a reproducible regression is discovered.

## Scope and order

### UI-1 — Window geometry and themes
- Audit actual frame anchors, width/height constraints and backdrop/border rendering in default, Warcraft and other themes.
- Fix stretched default-theme borders, cramped window spacing, and clipped settings headings.
- Fix text 'Saved on normal game exit' intersecting its border.
- Keep existing saved window positions and theme preferences compatible.

### UI-2 — Navigation and history
- [Implemented; native pending] Center Search runs and Overview > History actions; also align Overview/All statistics and Records.
- Normalize horizontal menu spacing and Warcraft category hover outlines.
- [Implemented; native pending] Order recognized Blackrock Mountain, Scholomance, Ahn\'Qiraj and Naxxramas maps by campaign progression in both selectors; other maps use deterministic alphabetical fallback.

### UI-3 — Language and explanatory labels
- Correct Optional analyses terminology in EN/FR.
- [Implemented; native pending] Optional analyses now have contextual EN/FR descriptions, and Combat Intelligence is marked experimental. All 14 locale catalogs contain the keys (English fallback where translations are not yet reviewed); `Strings.lua` is regenerated from canonical `data/catalogs/uiText.json`.
- Clarify Partial and Sync without claiming data collection or synchronization guarantees not supported by implementation.

### UI-4 — Visual resources (separate verification gate)
- [Asset received; integration pending] Maintainer supplied a 1200x750 Scholomance screenshot on 2026-11-05. Converted source JPG and 256x256 WoW-compatible TGA are prepared locally. Integration still requires committing the binary assets, adding `scholo` to `gameText.json` and the image manifest, regenerating `GameText.lua` and `Theme.lua`, and updating checksum/package checks. Do not mark complete until those assets are in the branch and CI passes.
- [Partially implemented; native pending] Remove duplicate Warcraft class emblem from the sidebar; reduce native icon silhouette cropping (1.5% inset instead of 7%) and apply a half-texel inset to the 256px flat-theme icon atlas to avoid adjacent-cell bleeding. Original Chroniques glyph textures still need native visual verification.
- [Implemented; native pending] Add persisted circular minimap icon setting independent of theme, with native tracking ring and reversible square appearance.
- Any texture optimization must preserve native WoW 1.12 texture compatibility; do not blindly replace TGA with JPEG.

## Implementation requirements
- Inspect existing code, localization keys and tests before changing any view.
- Separate cosmetic changes from saved-variable schema changes.
- Update SHA256SUMS.txt for modified shipped files and add offline tests where practical.
- Do not declare a visual fix accepted solely from CI.

## Final recipe
- Install CI artifact on an existing profile with a backup.
- Compare all supported themes and both FR/EN locales, including long labels and resized windows.
- Verify navigation, map order, settings headings, hover states, and no Lua errors.
- `/reload` and restart: existing window positions, selected theme and preferences persist.
- Report individual PASS/FAIL and screenshots of visual issues. Only then mark this lot accepted.

## Release boundary
The remaining backup, Nemesis, Partial and Sync data-integrity investigations remain tracked in `docs/AVIIVA-FEEDBACK-2.0.1.md`; UI acceptance does not authorize the public V2.0.1 release.

## Code audit follow-up — 2026-11-05
- PR #31 diff reviewed: 17 files, 630 additions, 188 deletions at `b982767`; latest CI PASS. Changes to persistent settings are confined to the `miniRound` boolean; existing runs are not rewritten by that option.
- Legacy run mode now remains `unknown` without observed Solo/Co-op evidence. This changes filtering, not the stored run history. Regression assertions cover both legacy cases.
- **Risk:** `sortHistoryMaps` ranks English display strings, not canonical zone IDs. Localized map names may be sorted alphabetically instead of campaign order; fix before native acceptance.
- **Risk:** repeated `A.ApplyUI()` in square minimap mode invalidates material caches (`materialTheme`, `themeBackdrop`, `nativeEdge`) even when nothing changed. Reduce unnecessary repaints and test round/square transitions in all five themes.
- **Risk:** source screenshot and TGA exist in local staging but have not been committed to GitHub; do not treat the local preview ZIP as the release artifact. Re-run source hash, generated map, package checksum, and CI after integration.
- **Unverified:** real SavedVariables restore and large-save latency, full theme screenshots, FR/EN labels, corrupted/legacy records. A green offline CI cannot certify these native behaviors.
- Preserve the accepted HUD 9/9 recipe; do not modify its layout without a new reproducible defect.


## Recovery checkpoint — 2026-11-05, conversation migration

**Source of truth:** repository `Maidenquinn/AzerothStats`, draft PR #31, branch `feat/v2.0.1-aviiva-feedback`, inspected head `30abc19dbdfe76563dac77f7a9a23e5a5b34faa7`. This section is a durable handoff for future assistant sessions. Always re-fetch the PR head and CI before editing; never assume this SHA remains current. PR #30 is already merged. Do not merge PR #31 or publish 2.0.1 without explicit owner acceptance.

### What is actually committed at inspected head
- Scholomance files `AzerothStats/media/RunZone-scholo.tga` and `design/run-images/scholo.jpg` appear in PR #31, together with `Theme.lua`, `GameText.lua`, `data/run-image-sources.json` and package policy changes. Earlier "asset not committed" notes above are stale for this head. Native rendering and package integrity are **not** yet verified.
- `UI.lua` implements Search runs caption centering, settings headings and save note repositioning, overview History/Records label centering, campaign map ordering, circular minimap option and Warcraft class-emblem deduplication.
- `Theme.lua` adjusts glyph texture coordinates and panel edge bounds. `V2UI.lua` adds optional-analysis explanations; `Insights.lua` avoids inferring Solo for legacy runs.
- Accepted HUD lot: native 9/9 PASS, recorded in `docs/AVIIVA-FEEDBACK-2.0.1.md`. Do not reopen without a reproducible regression.
- GitHub workflow-run and combined-status connector queries for inspected head returned empty results. **This is not a CI PASS or FAIL.** Check GitHub Actions explicitly.

### Still open: priority-ordered
1. **Data safety:** inspect `DataManagement.lua` and backup/restore/migration call paths; verify pre-delete snapshots, duplicate backup growth, retention 1–15, opt-in every 0–20 completed runs, corrupted/legacy records, restore integrity, and 100/500/1000-run latency. Do not change persisted schema without compatibility tests. The reported 12 MB for 78 runs is user evidence, not a measured current benchmark.
2. **History and evidence:** investigate Nemesis 0 confirmed / 58 probable / 69 observed for Dread Creeper; explain confidence limits; clarify Partial (including possible FPS/event-loss correlation) and actual Sync behavior. Verify Solo/Co-op/Unknown labeling.
3. **UI:** native test all themes, FR/EN, scales and positions; verify stretched borders, category spacing, Warcraft hover, clipped/grainy Chronicle glyphs, map order for all localized zone names, and minimap round/square transitions. Existing code is not equivalent to visual acceptance.
4. **Assets and packaging:** verify Scholomance texture renders, source hashes, manifest, generated localization, SHA256SUMS, installable ZIP and CI.
5. **Release gate:** full offline suite plus native acceptance on a backed-up real SavedVariables file, before any public release.

### Safe working procedure for next session
- Fetch PR #31 info, head, changed-file patches, this document and `docs/AVIIVA-FEEDBACK-2.0.1.md`.
- Read relevant full source modules before editing; patch only the dedicated branch. Re-fetch blob SHA immediately before each file update.
- Run tests/checks if an execution environment is available; otherwise label them NOT RUN. Never claim a test passed solely from static inspection.
- Commit small coherent fixes, update both tracking documents after each completed sub-lot with commit SHA, CI URL/result and native PASS/FAIL.
- Preserve existing `AzerothStatsDB` and V1/V2 data compatibility; do not delete backups or overwrite user SavedVariables.
- Deliver a ZIP only after package verification; ask the owner for native tests that cannot be reproduced remotely.

**Checkpoint action:** documentation-only recovery update. No code change, no CI run and no native acceptance performed by this checkpoint.

### Follow-up checkpoint — backup deduplication regression (2026-11-05)
- Commit `c772c582b447d279a2b7e799fc1931fac0296613` adds assertions to `AzerothStats/tests/data_management.lua` that repeated identical automatic snapshots do not add an entry or advance `nextId`, and report explicit deduplication.
- Static review of `AzerothStats/DataManagement.lua`: `CreateDataBackup(true)` snapshots and validates the DB, then compares the latest automatic snapshot recursively with `sameSnapshot`; periodic snapshots are opt-in every 0–20 officially ended runs; pre-deletion safety snapshots are intentional; automatic retention is 1–15.
- **Tests not executed in this checkpoint.** The large-save cost of full snapshot creation and comparison remains open, as do native restore and real-file size measurements. No production backup logic changed.
- Next: check CI for the new head, inspect backup restore paths and performance, then proceed through Nemesis/Partial/Sync and native UI acceptance.

### Backup retention regression checkpoint
- Commit `959743c4fa2268e16ae193677feea1ad880e6a17` adds tests for changed automatic snapshots, retention set to one, and isolation of manual backups. Previous deduplication tests remain.
- Static inspection confirms `RestoreDataBackup` validates a copied snapshot before replacing `AzerothStatsDB`; however `A.InitDB()` failure handling does not explicitly roll back the previous global database. Audit this path before declaring restore atomic.
- **CI and native tests not run/verified for this commit.** Do not merge or release based on these assertions alone.

### Restore rollback hardening checkpoint — 2026-11-05
- `0ba1788c8043c0fa7ec7c5a6741133ef8792e613`: `RestoreDataBackup` now keeps the old `AzerothStatsDB`, `A.db` and pending removal plan until `A.InitDB` succeeds. A failed or throwing initializer restores those pointers and reports failure; the redundant second `V2Reconcile` call was removed because `InitDB` already performs it.
- `4f94e44089bd26ccd124e9cd320728f7b5f7c37e`: regression test injects a failed initializer and asserts pointer/plan rollback and user-visible error.
- **Important limitation:** this is pointer-level rollback; any side effects of an initializer before failure (theme state, other globals) are not fully transactionally rolled back. Native validation remains required. Tests/CI were not executed or confirmed during this checkpoint.
- Next session: inspect the new PR head, run `tests/data_management.lua` in the repository test harness and check CI before marking PASS. Do not release without native saved-variable backup/restore verification.

### Nemesis evidence checkpoint — 2026-11-05
- Reviewed `AzerothStats/Nemesis.lua`: an observed death increments `deathEvidence.deaths`; an attacker is **probable** only if the latest parsed hit is within 2 seconds; **confirmed** requires an explicit `ERR_KILLED_BY_S` native slain-by message. A late explicit message within 2 seconds can upgrade a probable attribution without increasing the death count.
- The reported Dread Creeper 69 observed / 58 probable / 0 confirmed is consistent with missing or unrecognized explicit slain-by messages; it does not by itself prove a data-loss bug. Need real native message/event capture (without sensitive chat contents) before changing attribution semantics.
- Commits `f1ee7db03925d23c3930a9df74ee06de041bb996` and `9abbef41a9da87ab0c834e16690ba123cf0f6869` add and reposition a regression scenario: explicit message **before** death transition should count one confirmed Dread Creeper death. Repositioning avoids disrupting existing tests that index five fixture deaths.
- **Not yet executed or CI-verified.** No production Nemesis behavior changed. Next audit native event registration, locale-specific templates and Partial/FPS evidence; only then propose production changes.

### CI unblock checkpoint — 2026-11-05
- Inspected real PR-head workflow `42088604597` for `2e77fa8`: **FAIL**. `lot1-regression` failed `tools/checks.py` with `release byte drift: DataManagement.lua`; `offline-checks` failed `black --check` for `tools/build_run_images.py`.
- `60f3022733f42dbe28896f00fbfa5703358528f5` updates image builder import spacing and the long assert layout to Black style.
- `38b516ab6ff61af200e4c27113cc5fcddef15009` refreshes the `DataManagement.lua` entry in `AzerothStats/SHA256SUMS.txt` to `4e65ec43d74675981851d306e50bc0bc1af051546c9df892731e75093d2c88e1`, computed from the exact branch file UTF-8 contents.
- **New CI is pending/unverified**, and native acceptance is still open. If CI remains red, inspect its job logs before changing anything else.
- No ZIP can be declared recipe-ready until package integrity and offline tests PASS; do not merge/release.

# Aviiva feedback — acceptance matrix (5 November 2026)

This work continues after PR #30, which was merged as a *regression hotfix*. No public 2.0.1 GitHub Release should be announced until this feedback is resolved or explicitly deferred. Do not silently treat a green CI as native acceptance.

## Priority 0 — Data safety and backups
- [x] Confirm pre-delete automatic safety snapshot is intentional (`DataManagement.lua`, `ConfirmDataAction`); audit duplicate snapshots across manual/auto stores remains open.
- [x] Existing: opt-in auto-backup every 0–20 completed runs, retention 1–15, manual backup cleanup with confirmation; re-test UI and edge cases rather than rebuild.
- [ ] Existing synthetic 100/500/1000-run benchmark; validate against real large save, byte growth and latency before redesign.
- [ ] Confirm the client SavedVariables file model; do not promise independent files or arbitrary compression unless client APIs support them.
- [ ] Test restore, deletion, retention, and corrupted/legacy records without data loss.

## Priority 1 — History and data correctness
- [x] Existing Solo/Co-op/Unknown filters; new branch removes legacy absence-as-Solo inference. Both historical-mode regression assertions updated; CI #837 PASS and native five-point smoke recipe accepted.
- [x] Legacy Solo inference removed; absence of evidence remains Unknown (native smoke recipe accepted).
- [ ] Order map options by campaign progression, not alphabetically.
- [ ] Center Search runs and Overview > History.
- [ ] Explain Partial inline, distinguish missing observations from confirmed zero, investigate FPS/lag sensitivity.
- [ ] Audit what sync actually does and expose its limitations accurately.
- [ ] Investigate Nemesis 0 confirmed vs 58 probable / 69 observed; document source confidence and native evidence limits.

## Priority 2 — HUD
- [x] Bound emblem by HUD height (native smoke recipe accepted at 28px).
- [x] Implement adaptive per-column widths and reduced conservative collapse thresholds; native final HUD recipe 9/9 PASS on 2026-11-05.
- [x] Background opacity 0–100% already implemented; default height reduced 46px to 40px; persistence confirmed by native HUD recipe 9/9 PASS.
- [x] Added automated viewport/height matrix and varied-label allocation tests; native HUD visual acceptance 9/9 PASS.

## HUD acceptance — 5 November 2026
- [x] Final native HUD recipe: **9/9 PASS** reported by owner, including 28px emblem, 40px preset, eight metrics, FR/EN labels, narrow/wide sizes, opacity, persistence, navigation and themes.
- [x] CI workflow #849: **PASS** on commit `5b4f23d` (https://github.com/Maidenquinn/AzerothStats/actions/runs/42040088893).
- [x] HUD lot accepted. Do not reopen without new reproducible regression; no public 2.0.1 release yet.

## Priority 3 — UI, themes, assets
- [ ] Restore missing Scholomance map image.
- [ ] Review stretched default-theme borders and window spacing.
- [ ] Center settings headings; fix 'Saved on normal game exit' clipping.
- [ ] Correct Optional analyses spelling; explain each optional analysis and mark Combat Intelligence experimental.
- [ ] Normalize category menu spacing; fix Warcraft hover outlines.
- [ ] Make minimap icon circular and independently selectable from theme; preserve sensible default.
- [ ] Audit clipped/grainy chronicle glyph icons, including Diagnostics, Overview skull, My runs clock, Progress trophy and Favorites heart.
- [ ] Remove redundant Warcraft class icon; consider class-specific icon instead of helmet.
- [ ] Check whether TGA assets can be optimized without losing WoW 1.12 compatibility.
- [ ] Assess backup-folder shortcut only if the client permits it; do not assume filesystem access.

## Release gates
1. Offline tests and package integrity PASS.
2. Native visual screenshots for each theme, HUD minimum size, history and settings.
3. Native data recipe on existing large history with backup/restore; compare SavedVariables bytes and latency.
4. Owner accepts outstanding limitations explicitly before release.

## Owner checkpoint — 6 November 2026: combined A–D review
- Owner explicitly **accepted native recipe #970** (class/difficulty-aware history facets, reset, reload); this does not certify fully interdependent numeric sliders or authorize release.
- Owner provided **39 in-game PNG screenshots** in `AzerothSurvivors_7JAcj8PeOJ.zip` for UI audit. The image set covers Diagnostics, Settings, backups, My Progress, Analyze Run, My Runs, and overview/records. Screenshots are review references, not source files or proof of every interaction.
- Visually inspect all 39 originals at native resolution for text clipping, overlapping labels, spacing, category navigation, translations, modal bounds and the five themes. The giant center-screen `BOUGEZ POUR COMMENCER` text appears to originate from the underlying game; do not attribute it to addon without isolated reproduction.
- **Combined release gates A–D:** (A) numeric cross-facets and zero-result UX; (B) real SavedVariables backup/restore/retention and corrupted-record safety; (C) Nemesis evidence, Partial/Sync semantics; (D) screenshot-driven UI fixes and native FR/EN/theme regression.
- Automated green CI alone is insufficient. Do not merge draft PR #31, publish 2.0.1, or label the combined recipe ready before passing all gates. Maintain a safe copy of SavedVariables.

## Combined native recipe — candidate after CI (6 November 2026)

This is a **single A–D test session**, not four interim deliveries. Keep a copy of the existing `WTF/Account/<account>/SavedVariables/AzerothStats.lua` (exact account path depends on the client) before installing. Never test destructive actions against the only copy of a real save.

### A — Faceted history
1. Choose a class with few runs and a difficulty; confirm numeric ranges reflect that subset.
2. Change kills minimum while the advanced panel stays open. Confirm the level, gold and duration sliders react without closing it.
3. Change level and then kills again; verify the same result regardless of selection order. Apply, reopen, reload the UI, and verify the saved filters.
4. Enter incompatible constraints; verify the empty-state message says **no matching runs**, not **no data**. Reset filters and verify all retained runs reappear.
5. Verify old runs missing a `values` table do not crash history rendering.

### B — Data integrity
1. Record the current retained-run count, lifetime totals, favorites, auto/manual backup IDs and SavedVariables byte size.
2. Create a manual backup between runs. Verify automatic backup deduplication, 1–15 retention and manual retention independence.
3. On a **disposable copied save**, delete a run and restore the pre-delete snapshot. Confirm the run, totals and favorites recover.
4. Try restoring a corrupted snapshot and deleting an unknown ID; both must fail without changing the live database.
5. Reload or exit normally, restart, and verify persistence. Compare SavedVariables bytes and responsiveness against the baseline.

### C — Evidence and co-op
1. Check Nemesis confirmed/probable/unknown counts: only an explicit native death message is confirmed; nearby combat damage is probable.
2. In a co-op run, compare a synchronized party snapshot against independently observed samples; verify the scope note distinguishes them.
3. Confirm Partial indicates incomplete observations, not a measured zero. Test with and without available native evidence.

### D — UI and localization
1. Review Overview, My Runs, Analyze Run, Progress, Favorites, Nemesis, Settings, Diagnostics and backups in French and English.
2. Review all five themes at normal and minimum window sizes, with and without the advanced filters panel.
3. Check text wrapping, settings save note, tooltips, dialog bounds, button alignment and category navigation against the 39 screenshot references.
4. Confirm HUD recipe 9/9 remains unchanged, and Scholomance images display.

**Exit criteria:** report the four section results together. Automated checks are not native proof of screenshots, client SavedVariables persistence or frame-time performance. No merge or public release before owner acceptance.

## Stabilization freeze — owner approval, 6 November 2026

Owner has explicitly accepted the current portrait and history filters and requested that previously accepted work be frozen against regressions. The HUD native 9/9 recipe, portrait, date/filter persistence, Scholomance image, and already accepted visual work must not be redesigned without a reproducible regression. Keep PR #31 draft; no public release.

### Verified branch inventory at this checkpoint
- Branch head before this documentation change: `dfea25dd0829d318d49abd8f7aab99b202f905cb`; PR #31 open/draft, 205 commits ahead of `main`, 28 changed files.
- Backup code uses full independent database snapshots, exact structural deduplication for automatic backups, 1–15 automatic retention and opt-in 0–20 completed-run cadence. Manual backups remain separate. The existing regression suite covers duplicate snapshots, retention, invalid IDs, malformed metadata, corrupted snapshots, failed-initializer rollback, deletion safety and restore. These are **offline assertions**, not a substitute for native large-save validation.
- Nemesis explicitly confirms only native slain-by evidence; last-hit attribution within two seconds remains probable. A zero-confirmed count does not establish a bug without native event evidence.
- Co-op Sync exposes synchronized group snapshots versus independent partial samples; it is **not** evidence of a general-purpose lost-run recovery feature. Legacy runs without reliable mode evidence remain Unknown, not Solo.
- Existing UI changes include map-order logic, localized explanatory labels, circular minimap option, alignment work and Chronicle atlas adjustments. Five-theme FR/EN visual acceptance is still outstanding. Earlier unchecked boxes in this document may refer to already implemented work; do not treat them as proof that code is absent.

### Remaining gates in priority order
1. Preserve an independent copy of a real SavedVariables file. Benchmark actual file size and backup/restore latency with large histories; compare with synthetic 100/500/1000-run tests. Avoid introducing new backup formats until compatibility and rollback are proven.
2. Investigate Nemesis native message capture and Partial under FPS pressure without relabeling probable evidence as confirmed or incomplete samples as zeros. Clarify Sync capabilities in UI and documentation.
3. Visually validate all five themes in FR/EN against the 39 owner screenshots; fix only reproducible clipping/spacing defects and preserve accepted portrait/HUD/filter geometry.
4. Re-run package checks, full CI and a single combined native recipe, then request explicit owner acceptance before merging or publishing 2.0.1.

**Status:** stabilization plan recorded, not a claim that all gates have passed.


## Native checkpoint and backup stress regression — 6 November 2026

- Owner launched the 2.0.1 stabilization ZIP using the **usual SavedVariables with all existing runs**, reporting normal startup and no obvious problems. This validates a startup smoke test only; it does not prove every aggregate or restore path.
- The CI for `9c88d0f` and `d3fbf4c` passed both `offline-checks` and `lot1-regression`.
- The synthetic backup regression now covers 100, 500 and 1000 retained runs, independent deep snapshots after live mutation, exact automatic deduplication, retention of one, and three separate 1000-run recovery points with distinct sequence values.
- No shipped addon behavior was changed by these test commits. The previously delivered stabilization ZIP remains a valid native test build for the same addon code.
- **Not yet demonstrated:** real SavedVariables file-size reduction, frame-time measurements, a destructive restore on a disposable real save, or native Nemesis/Partial/Sync behavior. These remain release gates, not claims of success.

### Next owner-facing native recipe (non-destructive first)

1. **Before testing:** fully exit the game, copy the actual `AzerothStats.lua` SavedVariables file to a safe location, and record its byte size. Never delete or restore on the only copy.
2. **Baseline:** open My Runs, note retained-run count, totals, favorites and current backup IDs. Verify normal navigation and existing history filters.
3. **Backups:** between runs, create one manual backup; record the delay and resulting backup ID. Trigger a second automatic snapshot without changes and verify the duplicate is not retained. After a normal exit, compare the new SavedVariables byte size.
4. **Reload:** restart the game and check that runs, totals, favorites and backup IDs persist; verify no freezes or Lua errors. Record approximate backup/restore responsiveness rather than inventing timings.
5. **Disposable-save-only restore:** on a separate copied test save, delete one known run and restore the prior backup. Verify its return and check totals/favorites. Never run this step on the only real save.
6. **Nemesis:** compare observed/probable/confirmed counts against the available native combat evidence. A probable attribution is not an explicit confirmed kill.
7. **Partial/Sync:** inspect an incomplete run and one co-op run. Partial means insufficient observed evidence; Sync refers to synchronized party snapshots, not automatic recovery of missed runs.
8. **Visuals:** review all five themes in FR/EN at normal and narrow widths; verify Scholomance, the accepted 3D portrait, HUD and filters without changing their geometry.

**Pass criteria:** report observations for all steps, including any skipped destructive test. Owner approval is required before changing the draft PR into a release.


## Owner acceptance — 6 November 2026

- Owner explicitly approved the delivered 2.0.1 native review build (`AzerothStats-2.0.1-pr-review`, GitHub Actions run `42246208232`) and authorized moving on to the next workstream.
- The run completed with `offline-checks` and `lot1-regression` both successful. This approval closes the requested stabilization review; it does not establish that every optional destructive backup scenario was exercised.
- Known limitation accepted for now: without reliable native final-blow evidence, Nemesis must continue distinguishing confirmed, probable and unknown. Do not infer confirmed attribution from the game's death-screen pixels or a recent combat hit.
- Freeze previously accepted portrait, HUD, filters, history persistence and data-integrity behavior. Any new changes must have targeted regression coverage.
- Keep the pull request unmerged and do not publish a public release automatically; separate the next feature lot from this stabilization review.

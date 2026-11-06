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

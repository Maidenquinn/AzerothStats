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

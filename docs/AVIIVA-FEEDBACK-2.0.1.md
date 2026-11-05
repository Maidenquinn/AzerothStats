# Aviiva feedback — acceptance matrix (5 November 2026)

This work continues after PR #30, which was merged as a *regression hotfix*. No public 2.0.1 GitHub Release should be announced until this feedback is resolved or explicitly deferred. Do not silently treat a green CI as native acceptance.

## Priority 0 — Data safety and backups
- [ ] Reproduce manual + automatic backups created by deletion; distinguish expected pre-delete safety snapshot from unintended duplicates.
- [ ] Configurable auto-backup cadence (e.g. every N completed runs), retention and manual-vs-auto policy, with safe defaults and upgrade behavior.
- [ ] Profile size of 78/250/1000 runs, count bytes and save latency; reduce duplicated full snapshots without compromising recovery.
- [ ] Confirm the client SavedVariables file model; do not promise independent files or arbitrary compression unless client APIs support them.
- [ ] Test restore, deletion, retention, and corrupted/legacy records without data loss.

## Priority 1 — History and data correctness
- [ ] Add Solo/Co-op/Unknown filter to All runs; show run-mode labels wherever evidence supports them.
- [ ] Reconcile legacy Solo inference with owner's stated rule: absent co-op evidence alone must NOT prove Solo; use Unknown where unsupported.
- [ ] Order map options by campaign progression, not alphabetically.
- [ ] Center Search runs and Overview > History.
- [ ] Explain Partial inline, distinguish missing observations from confirmed zero, investigate FPS/lag sensitivity.
- [ ] Audit what sync actually does and expose its limitations accurately.
- [ ] Investigate Nemesis 0 confirmed vs 58 probable / 69 observed; document source confidence and native evidence limits.

## Priority 2 — HUD
- [ ] Fix left icon overflow at minimum height.
- [ ] Improve right-section width allocation per section and reduce premature collapse.
- [ ] Allow background opacity 0%, review default height and persist settings.
- [ ] Test min/max scale and narrow/wide screens.

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

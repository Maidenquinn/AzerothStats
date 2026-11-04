# Azeroth Stats 2.0.1 — Aviiva community feedback implementation plan

Status: work in progress; no merge into main, no public release until owner acceptance.

## Confirmed source findings
- Nemesis.lua: a confirmed death requires an explicit native slain-by message within 2 seconds. Otherwise the last recent hit may be probable. No evidence must stay unknown.
- DataManagement.lua: backupStore uses schema 2 with independent full database snapshots. Automatic entries are capped at 15, while manual entries are not. ConfirmDataAction always creates a safety auto backup before destructive actions.
- Tracker.lua: partial means the run was not fully observed from its beginning (missing/late native start timestamp).
- Views.lua: absence of co-op evidence is not proof of solo. Old runs must not be mislabeled solo.
- Bar.lua and BarUI.lua: bar opacity lower bound was 0.45; first fix in this branch changes it to 0.0 without changing global window opacity.
- BarUI.lua: current top-left seal is 22/30 px and may overflow the 28 px minimum-height bar. Needs in-client visual verification.

## Ordered lots
### Lot 1: Backup correctness and scalability (P1)
1. Add tests reproducing manual+automatic snapshots around deletion and retention/pruning.
2. Measure serialized data sizes, snapshot copy cost and restore roundtrips with 50/100/250/500/1000 runs.
3. Distinguish mandatory pre-destructive safety snapshots from user-configurable periodic backups.
4. Design safe duplicate detection (must not skip a required safety backup if there is no equivalent recoverable snapshot).
5. Offer periodic interval (every X completed runs), retention cap, and sensible defaults; avoid backup creation while a run is active.
6. Preserve schema-1 SavedVariables and schema-2 legacy backup readability. Do not silently discard user backups.
7. Investigate storage format, compression feasibility and client-side SavedVariables limitations before changing representation.

### Lot 2: Data provenance (P1)
- Audit native slain-by messages and event timing before changing Nemesis confirmation.
- Improve confirmed/probable/unknown labels, explain partial runs, and expose evidence source.
- Add Solo/Co-op/Unknown filter and tags only when positive evidence exists.
- Audit local sync semantics; never promise historical reconstruction unsupported by native APIs.

### Lot 3: HUD and presentation (P2)
- Scholomance asset/path check; center Search runs.
- Fix icon/seal clipping at minimum height; adaptive per-block width/overflow.
- Bar background opacity 0..100% (initial patch included); preserve readable labels.
- Evaluate smaller default bar only for fresh installs, not existing player preferences.
- Check class icon versus helmet and TGA compatibility/asset sizes.

## Release acceptance
- Offline CI green on exact head.
- No data loss on backup restore; manual backup preservation.
- Real game client tests for HUD, fonts, calendar, Scholomance, and save/reload.
- Owner approval before merging or publishing 2.0.1.

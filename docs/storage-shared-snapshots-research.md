# Storage research — shared immutable run versions and exact restoration

Status: **research only, not enabled in Azeroth Stats 2.0.4**. No live player files are read or rewritten by this proposal. The current implementation stores full independent copies of `A.db` in each manual/automatic backup entry (see `A.CreateDataBackup` in `AzerothStats/DataManagement.lua`).

## Decision

A shared store **could** reduce duplication significantly. A timestamp cutoff by itself **cannot restore a consistent historical database**: run details, favorites, notes, records, totals, class/co-op/usage ledgers, settings, pruned history and other aggregates may change independently or even refer to runs outside retained history.

The eventual checkpoint must reconstruct **every field**, not merely `runs` before a date. Dates can label a checkpoint, but cannot be its sole restoration key.

### Proposed representation (concept, not Lua production schema)

- Live database `AzerothStatsDB` stays unchanged for the WoW Logs AS direct reader. Do **not** convert it to references.
- An immutable pool associates a run content version with a unique key. A modified note, favorite mark or run detail produces a new version; the prior version remains if an older checkpoint needs it.
- Each manual or automatic checkpoint contains an **ordered list of version keys**, plus an independent frozen snapshot of *every non-run DB field*, including historical ledgers and schema.
- Full restore resolves all keys into a **newly allocated** DB, validates it completely, then atomically installs it. Missing/corrupt versions fail closed without touching live data.
- Every checkpoint type (manual, auto, safety-before-delete) references the same pool. Pruning or deleting a checkpoint garbage-collects an old version **only when no remaining checkpoint references it**. Counts of shared keys must be reconstructed/verified, not trusted blindly.
- An original full snapshot remains available as a fallback during a versioned migration. No in-place conversion of the only recovery copy; prove a successful next game session and rollback first.

### Critical implementation constraints

1. Do not rely on merely pointing several Lua tables to the same run table. The Azeroth Survivors client's SavedVariables serializer may serialize repeated objects independently; on-disk deduplication must use explicit keys and lists.
2. Never derive restore membership from timestamps alone. A 117-run-pruned lifetime ledger is not the same as retained `runs`.
3. A shared pool saved into a different physical SavedVariables file might not be written atomically with the checkpoint manifest. Prefer one physical save root/transaction and design recovery around interrupted writes, with verified client behavior.
4. The current game runtime is Lua 5.1. The Python model uses SHA-256+JSON **only for synthetic experiments**. A production Lua implementation needs safe canonical encoding/collision handling, strict memory caps, depth/node limits, and a native-client serialization roundtrip.
5. Snapshot creation, completion and garbage collection must never run per-frame or during a live run. Performance and load-time matter on the browser client too.
6. Preserve v2.0.4 restores and direct WoW Logs AS reading; neither may require a new addon or network call.
7. A snapshot can contain large non-run ledgers or v2 metadata; measure their size separately. Deduplicating only runs may not explain every reported 10 MB increase.
8. Existing 2.0.4 save files can be large (example: 91,360,490 bytes with 223 current runs, two manual snapshots and 439 copies in the snapshot roots). These figures do **not** establish an attainable real compression percentage.

## Executable isolated model

`tools/research_shared_snapshots.py`: Python-only surrogate content-addressed pool and manifests, sample 100/500/1000-run workload, reports synthetic JSON bytes. It is not in the addon TOC, not a production serializer, and never opens player data. `tools/test_research_shared_snapshots.py` verifies exact restoration of old/new run versions and non-run ledgers, fail-closed missing data, shared reference garbage collection and no mutable aliasing.

## Migration prototype — implementation status (13 November 2026)

The isolated Lua 5.1 research module in `AzerothStats/tests/shared_backup_research.lua` now includes:

- `M.importLegacy(live, manual, automatic)`: stage schema-1 legacy single slots and schema-2 manual + automatic roots together. Never mutate the caller's original roots or live DB. Preserve old IDs separately for manual/auto, timestamps, run counts, legacy flags and each root's next ID.
- `M.save`: explicit shared run IDs indexed by local run ID, but **reusing a version requires full deep equality**. Edits create separate immutable versions. The index is an in-memory accelerator, not a duplicated file payload.
- `M.restore`: reconstruct the whole historical DB from run references and a frozen *non-run* DB state, validate through the addon database validator, and return a fresh object without installing it.
- `M.verifyMigration`: require exact parity with every original manual/automatic snapshot after a simulated SavedVariables serialization and reload, including the catalogue metadata. Missing or inconsistent source entries fail the entire verification.
- `M.delete` and `M.collect`: remove only unreachable pooled run versions, refusing collection on dangling references.
- `M.fingerprint`: deterministic dual rolling checksums over ordered Lua table contents, catching **accidental** valid-shape corruption in stored runs and checkpoint state. **These are not cryptographic authentication or a substitute for native client verification.**
- Offline scale fixtures use 100, 500, and 1,000 synthetic runs, verifying that changing one run creates one new pooled version and changing only non-run state creates none.
- The production addon TOC, SavedVariables contract, default backup settings, live WoW Logs AS reader fields, and stable v2.0.4 ZIP remain unchanged.

This does **not yet** constitute an installable replacement for the old backup system, an automatic in-client conversion, a 100 MB production benchmark, or a demonstrated rollback after a real client crash. It is intentionally test-only until these guarantees are proven.

### Required player migration transaction (not yet implemented)

1. Exit the game completely and preserve a separately verifiable copy of the **actual** SavedVariables file(s); in some clients the three Lua roots share one `benilla-config/saved/AzerothStats.lua`.
2. Detect and validate both old backup roots and the active DB without changing them.
3. Stage the new shared store in a non-destructive shadow namespace, retain all source snapshots and sequence metadata, and compare every reconstructed backup byte-for-byte *logically* (deep structural equality) against the source, not just by date/count.
4. Close/reopen the client and re-verify persisted shared data before any old backup storage is eligible for reclamation. Treat interrupted writes, partial saves and invalid hashes as a reason to keep using the old roots.
5. Offer an explicit post-verification opt-in cleanup with preview of byte savings and rollback instructions. The stable release must not silently discard older snapshots on first launch.
6. Validate the original and reconstructed backups using current and older addon versions where applicable, plus the external WoW Logs AS SavedVariables reader.

`M.verifyMigration` can validate the research model after a serialized reload, but **the real game-client durable migration and recovery state machine remains to be built**.

## Required gates before any real implementation

- **Baseline:** profile anonymized run metadata (not raw save files published to GitHub), and before/after byte deltas from two closed-client save copies.
- **Replay:** seed a synthetic database with 100/500/1000 runs and deliberately mutable notes/favorites, pruned histories, missing keys, legacy backups and pre-delete safety points.
- **Proof:** compare original and restored complete database through deep structural equality, plus WoW Logs reader fixture parity, across simulated game restart and interrupted migration.
- **Backwards compatibility:** verify legacy restore/backup on 2.0.2/2.0.4 with fallback copies, including a rollback to old addon after a failed upgrade.
- **Performance:** memory peaks, shutdown save duration and startup parse time in the real client and browser; no claims based solely on JSON ratios.
- **Rollout:** explicit opt-in migration, preview of expected bytes and backup before action, then clear release recipe and abort path.

## Interim low-risk policy

Until a versioned shared store passes these gates: retain independent recovery snapshots; avoid automatic deletion or rewriting; provide byte measurement guidance; explain that redundant *identical* automatic backups are already skipped in 2.0.4 but distinct snapshots still duplicate history. Native round minimap rendering remains a separate issue.

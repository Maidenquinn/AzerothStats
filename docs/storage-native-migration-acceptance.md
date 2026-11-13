# Shared backup storage — native acceptance and rollback gates

**Status: design / offline research only. Not an installable migration.** The stable 2.0.4 SavedVariables and ZIP are untouched. No real player's file is accessed by CI.

## 0. Stop condition

Do **not** distribute, merge, run an automatic conversion on existing profiles, remove a legacy backup, or promise a percentage of disk savings until every gate below passes. The Python/Lua research models and simulated `SNAPSHOT` reload are not the native game serializer.

## 1. Preserve the actual 2.0.4 source

Fully exit the game. Some clients store all three Lua globals in one physical `benilla-config/saved/AzerothStats.lua`; others may use separate files. Never assume three distinct files must exist.

From a trusted local checkout, for Windows PowerShell 5.1+:

```powershell
.\tools\backup_savedvariables_safety.ps1 `
  -SourceSavedDirectory "H:\AzerothSurvivors\Jeu\benilla-config\saved" `
  -DestinationRoot "H:\AzerothStats-Safety-Copies" `
  -GameCompletelyClosed
```

Adjust the example source to the **real** installation path. The destination must be **outside** the game's live save directory. The script copies only existing `AzerothStats*.lua` roots with known names and verifies source/destination SHA-256 and byte lengths. It never modifies the originals. Keep the entire verified backup folder. **Do not publish raw SavedVariables or identifying details from them.**

Record the stable addon version and output of `/azstats storage` (counts only) before testing. Preserve the last stable ZIP locally for rollback.

## 2. Legacy compatibility matrix (on isolated copies)

| Scenario | Required proof |
| --- | --- |
| Schema 1 single-slot manual only | Restore original exactly; ID and legacy flag retained |
| Schema 2 multiple manual | All snapshots retained, original order/IDs/timestamps and next ID retained |
| Schema 2 auto + manual, colliding numeric IDs | Separate namespaces, all restore correctly |
| Missing auto backups | Valid empty auto catalogue, no invented backups |
| Auto retention 1 / 2 / 15 | No extra deletion or changes to originals |
| Run edited after a manual checkpoint | Old/new notes and detail remain independent |
| Old pruned runs and lifetime ledgers | Preserve cumulative totals/records as of each checkpoint |
| Invalid/unknown schema, duplicate IDs, unknown metadata | Reject migration without changes (no silent dropped data) |
| 100/500/1000 retained runs | Exact restore and bounded memory/time |
| Browser client versus desktop | Versioned save/reload and refresh parity |
| Same-file combined save globals | Durable transaction and valid load after restart |

The prototype checks many of these with synthetic Lua tables, but **native coverage remains outstanding**.

## 3. Two-session durable migration protocol (not yet in production)

1. On startup, validate `AzerothStatsDB`, legacy manual and automatic roots **without rewriting them**. If unknown metadata is found, abort with a read-only diagnostic.
2. Ask the user to complete and retain a verified external backup. Confirmation alone is not proof: do not delete originals.
3. Stage a new shared checkpoint catalogue under an independent, opt-in storage namespace; keep the old catalogues untouched. The active DB remains unchanged for WoW Logs AS.
4. Perform complete deep structural comparisons for **every** old checkpoint, including the full non-run DB state. Verify the manifest and per-run digests.
5. Exit the game normally so the actual client writes SavedVariables. Restart the game and validate persisted staged roots against originals. A changed original source or failed integrity check aborts the stage.
6. Run native manual and automatic restore tests using **copies** of the profile. Prove restoration after `/reload` and full exit/restart, not only in memory.
7. Measure real combined `AzerothStats.lua` byte lengths after a clean client shutdown, peak migration memory, startup parsing time, and time spent on save/restore.
8. Keep original backup roots and working rollback copies across the trial. Removal of the originals would require an additional release gate and explicit opt-in **after** proven real-world rollback.

The research `SharedBackupMigrationJournalResearch` models staging/reverification/abort and deliberately offers **no destructive commit or cleanup API**. Its session strings are test doubles, not a guarantee of a real restart or durable disk write.

## 4. Fault injection and fail-closed behavior

- Corrupt a run payload while keeping a valid table shape: restore must reject.
- Redirect one run reference to another valid run version: manifest checksum must reject.
- Damage a checkpoint's non-run state: restore must reject.
- Remove a shared pool entry or leave a dangling reference: restore and GC must reject without deleting anything.
- Truncate a checkpoint entry, remove `digests`, or modify a timestamp/ID: post-reload verification must reject.
- Change the source DB or backup catalogue between sessions: staged migration becomes invalid.
- Simulate interrupted file write, crash during staging, and crash between staging and restart. Old saved roots must always load with v2.0.4.
- Abort repeatedly: safe and idempotent, with old roots byte-identical.

**Do not use production data for deliberate corruption tests.** Only cloned and sanitized fixtures.

## 5. Compatibility and release exit gates

- Test the actual WoW Logs AS reader against identical `AzerothStatsDB` before/after; no network upload or client dependency.
- Test old-version rollback and restoring all original snapshots by replacing the addon folder while the game is closed, then restoring the verified external file(s).
- Confirm no unexpected double copies or unreferenced pool versions accumulate after normal backup rotation.
- Enforce maximum work per game session, latency budgets and low-memory failure behavior, especially for 100 MB saves. Synthetic 61% **backup-only** savings cannot be marketed as actual on-disk reduction.
- Only publish an opt-in alpha/RC once these gates pass. A subsequent stable requires native acceptance.

## 6. Safe rollback

Exit the game completely; preserve the failed experimental file separately for diagnosis. Replace the addon with the previous stable version. If needed, restore **all** original SavedVariables file(s) from the verified external folder, never selectively overwrite one of multiple dependent roots. Relaunch, verify runs/favorites/totals and test a known manual restore on a copy. Do not delete the independent backup afterward.

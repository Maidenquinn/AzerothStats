# Local data management — 1.7.0-dev.1 preview

This unmerged candidate adds explicit user-controlled removal of addon-owned local data. No file I/O, native game write, outgoing message or save import is added. The client serializes the resulting own SavedVariables normally.

## Exact scopes

- Delete run details: removes one unprotected retained run. Lifetime totals, records and Trends are unchanged. Removing the selected source returns to History rather than silently opening another run.
- Clear retained history: removes matching ordinary details globally or for an explicitly selected class; preserves tracked/active and bookmarked sources. Lifetime ledgers remain byte-for-byte unchanged. Pruned counters increase as with normal retention.
- Reset all statistics: clears runs, global/class aggregates, records, observed Trends/co-op/death statistics and all favorites. Preserves the exact UI/HUD settings object, schema/version, migration markers and sequence counter. New runs get fresh monotonic IDs. This is deliberately global, not a per-class cumulative reset.

Retained runs are not a complete lifetime ledger: older details may already have been pruned. This feature never subtracts those snapshots from aggregates or guesses replacement records. Fine-grained deletion of one lifetime counter/class contribution is not included.

## Confirmation and lifecycle

Opening Settings > Manage local data, `/azstats data` or `/azstats reset` only opens a dialog. Scope selection previews a bounded impact. Destructive application requires clicking Delete data; the current ID/protection/count signature must still match. If it changes, nothing is removed until the user reviews and confirms again. Cancel/Escape keeps data.

Full reset additionally requires the exact token RESET and an explicitly observed native ready phase; unknown/missing/active phase blocks it. Current run/observer references and pending notices are detached, stale native counters are gated, and old run IDs are never reused. Settings remain, including language, HUD layout, scale and retention. There is no persistent automatic-reset flag or immediate command argument that bypasses confirmation.

History-only removal protects source run/combat bookmarks. Other item/spell bookmarks keep their own saved display snapshots, as with ordinary retention. Full reset removes every favorite explicitly; the confirmation states this. There is no undo/export/automatic backup in the runtime. The user can back up own SavedVariables before choosing deletion.

## Validation recipe

Use a disposable backed-up own database for destructive native testing. Opening and cancelling on a real profile is safe to test without erasing it.

1. Restart with the candidate; open Settings > Manage local data or `/azstats data`.
2. Review one retained run and class/global history scopes; cancel and verify no change. Check menus stay above the dialog.
3. On disposable data only, remove one ordinary run and compare lifetime totals/records before/after. Protect another via a run/combat favorite and verify it cannot be removed.
4. Start a run while a reset plan is open: the reset must be blocked even with RESET typed. Unknown phase must also block it.
5. Between runs on disposable data, type RESET and confirm. Verify history, records, Trends, companions, Nemesis and favorites clear, but HUD/language/settings remain.
6. Close normally/restart; verify the reset persists. Start a new run and confirm it is counted once, has a new ID and does not restore old counters. Test Cancel/Escape and one CJK language.

Automated deletion tests use only synthetic in-memory databases and serialization. They never apply data actions to the player's actual save. Native focus/modal/sampling behavior still needs maintainer validation before merging or publishing.

## Offline validation

4,554 independent assertions passed, including 47 isolated data-management assertions. Full Lua 5.0.3 behavior/syntax/persistence checks passed. The exact 76-file player ZIP passed 27 class/outcome cases in 81 fresh processes (1,764 assertions). Fifteen Python tests and fourteen-language font coverage passed. Synthetic French/Japanese dialog previews were inspected; these are not native screenshots. No player save was erased during testing.

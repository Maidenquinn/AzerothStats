# P0 run integrity dev.20

## Recovery

`/azstats backup` stores a bounded validated snapshot in `AzerothStatsBackup`, independent of `AzerothStatsDB`. `/reload` persists both variables to disk. `/azstats restore confirm` restores the latest snapshot between runs; `/reload` recommended afterwards. A snapshot is automatically attempted before each destructive Manage Local Data action. If validation or capacity fails, the deletion is blocked. Only one backup is retained: make an external copy of SavedVariables before experimenting.

## Reconciliation

Explicit run/history deletion removes ledger-backed contributions and only replaces records that belonged to removed runs. Historical runs purged by retention cannot be reconstructed. The `/azstats resync` command refreshes V2 run references but does not claim to reconstruct lifetime totals from unavailable history. Previously corrupted data may require a manual recovery from a clean backup.

## In-game acceptance (pending)

1. Backup, `/reload`, confirm backup persistence.
2. Delete one completed unbookmarked run and verify lifetime/class counters and spell aggregates; restore backup.
3. Verify records from unrelated runs survive deletion.
4. Verify protected/active runs cannot be deleted.
5. Verify reset fences, old saves, history pruning, and V2 analysis.
6. Verify restore confirmation and `/reload` after restoration.

Do not claim full automatic reanalysis of unavailable native per-run values.

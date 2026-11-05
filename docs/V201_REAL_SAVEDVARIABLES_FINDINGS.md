# Real-world SavedVariables size audit (2026-11-04)

A user-provided AzerothStats.lua from v2.0.0 was inspected **locally, without uploading its contents**. No personal player data is committed.

- File size: 104,005,880 bytes (~99.19 MiB).
- Main database runs: ~16.19 MiB.
- Extensions: ~1.23 MiB.
- AzerothStatsBackup.entries: five embedded full snapshots, ~81.44 MiB total; individual snapshots ~15.87–16.39 MiB.
- AzerothStatsAutoBackup: nil.
- Therefore, the existing automatic retention/dedup feature alone cannot solve the largest real-world source of bloat: **manual snapshots**.

## Follow-up work before Lot 1 acceptance

1. Add safe **manual backup management**: list snapshots with dates and estimated sizes; allow explicit individual deletion and an explicit prune-old-manual-backups action, with confirmation and no silent data loss.
2. Prefer removing superseded redundant manual snapshots over changing snapshot schema without migration tests.
3. Benchmark loading/validation and backup creation on a representative large fixture. Synthetic runs alone are not representative of the real file.
4. Add tests for restore of retained snapshots, legacy schema compatibility, and cancellation/no-op deletion.
5. Never silently delete manual backups during update or initial migration. Offer a clearly explained cleanup option.
6. Evaluate serialization cost and optional export/backup outside SavedVariables only if runtime and client capabilities support it.

Do not commit the original save file, names, run details, or other player-specific data.

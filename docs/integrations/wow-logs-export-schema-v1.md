# Azeroth Stats Export Schema v1 — initial implementation

Status: experimental 2.0.3 development contract; subject to review with Rakesh. Not an uploader format or an on-disk export.

## Entry point
`AzerothStats.ExportRunV1(run)` returns a new Lua table or nil for an invalid input. The module is loaded from `InteropExport.lua`. For an explicitly requested retained local run ID, `AzerothStats.ExportRetainedRunV1(localId)` resolves the run in the current validated in-memory database and returns the same isolated projection; missing/pruned IDs return nil. This lookup does not expose the database table. It does not write to SavedVariables or disk, transmit data, or depend on WoW Logs AS. Consumers must not assume the projection is automatically serialized.

## Shape
- `schemaVersion`: string `1.0.0`
- `source.addon`, `source.version`: addon name and running addon version
- `run.localId`: existing local ID; not globally unique
- `run.nativeRunId`: nil until native semantics are verified
- `run.zone`, `run.class`, `run.heroic`: retained run metadata, nullable
- `run.status`, `run.outcome`, `run.partial`: retained run status, result, and tri-state partial observation flag (`true` = partial, `false` = explicitly not partial, absent = unknown)
- `run.startedAt`, `run.endedAt`: existing numeric wall timestamps when present; units and client clock provenance need native verification
- `metrics`: allowlisted keys duration, level, kills, gold, damage, taken, healing, peakDps, bosses, elites, guardians, chests, magnets. Each value is either `{availability="unavailable"}` or `{availability="available", value=<finite number>, provenance="retained-run"}`.

## Privacy and limitations
This projection never traverses `AzerothStatsBackup`, `AzerothStatsAutoBackup`, co-op roster, character names, raw events, equipment tooltips, or arbitrary internal fields. It is deliberately a minimal allowlist, not a full build or combat export. It does not claim that all values are native-observed: the provenance label indicates only that they come from the retained run, which may contain derived values. Do not use this preliminary field as an observation-quality guarantee.

The native `AZS_ZONE.run` lifecycle, uploader disk-read timing, identity collision handling, and external serialization contract remain unverified. This adapter must not be used to merge runs based on local IDs alone.

## Validation gates
- Lua 5.0 syntax and runtime loading, test with absent/malformed fields and nil-vs-zero.
- Compare old SavedVariables before/after initialization, with manual/automatic backups preserved.
- Ensure the projection has no alias to mutable internal tables.
- Review privacy allowlist and align field provenance with Rakesh.
- Confirm native game behavior before changing run continuity or persisting a native ID.

No public release before in-game acceptance.

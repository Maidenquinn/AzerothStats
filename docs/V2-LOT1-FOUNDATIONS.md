# V2 LOT 1 — API compatibility and data contracts

Base: `codex/v2-runtime` (`2.0.0-dev.13`). Scope: AzerothStats only. Client target: 0.139.2; legacy clients degrade safely.

## Decisions
- Combat Intelligence: opt-in, **off** by default.
- Co-op Intelligence: **on** by default, collection only after a confirmed active co-op context (not implemented in Lot 1).
- Encounter Intelligence: opt-in, **off** by default.
- Reports: **balanced** by default.

`V2Foundations.lua` provides **read-only** `V2NativeCapabilities()` and `V2FeaturePreferences()`. It never reads combat events, world catalogs, party-down lists or player position. Do not interpret capability presence as an active run, valid party or a guarantee that a subsequent call will succeed.

## API contracts verified against addon_docs.md (game 0.139.2)
| Feature | Capability | Reader | Semantics |
|---|---|---|---|
| Combat | `AZS_GetCombatTextCapabilities()` | `AZS_GetCombatTextEvents(cursor,limit)` | nil cursor subscribes at the tail; independent cursor per addon; report `droppedCount`, `STREAM_CHANGED` |
| Co-op | no separate capability | `AZS_GetDownedPartyMembers()` | nil + error is not an empty party; empty list is not a confirmed revive |
| Encounter | `AZS_GetWorldAnchorCapabilities()` | `AZS_GetWorldAnchors(query,cursor,limit)` | drain one catalog in one frame; restart on `CATALOG_CHANGED` or `STREAM_CHANGED` |
| Location | none | `AZS_GetPlayerPosition()` | only compare coordinates with matching `spaceId`; 0 is valid |

Additional legacy inputs: `AZS_REVIVE`, `AZS_UNITS`, `AZS_BOSSMETER`. Preserve existing V2 observer processing and prevent double counting in later lots.

## Future schemas, **not yet persisted**
- Combat: stream/world identifiers, batch gap and dropped counts, finite bounded summaries (source/target/unit/school/critical/periodic/distance). Combat text is *not* a meter or a complete healing/incoming-damage feed. Totals continue to come from verified native meters.
- Co-op: stable member ID, observed fall interval, attempted help, explicit confirmed/unconfirmed outcome; a member disappearing can mean leave/end/revive. Correlate with existing `AZS_REVIVE` support sequence without synthesizing successful revives.
- Encounter: stable `unitId` within the relevant run plus ephemeral `anchorId` within a particular stream/catalog; `dead` is evidence, `missing` alone is not a kill. Never persist `anchorId` as a cross-run identifier.

All future observations must include data provenance and partial/unavailable quality flags, bounded per-run retention, and grouped writes. Never call `V2Update()` for each combat event.

## Storage and architecture
- SavedVariables: `AzerothStatsDB`; V1 schema remains 1.
- V2 extension: `extensions.azerothStatsV2`, schema remains **1**.
- Existing enrichment: max 32 enriched runs; 32 stat samples per run; progression 120; support 40; encounters 16; boss samples 12. Do not raise limits without benchmark and migration tests.
- Lot 1 adds no persistent keys by itself and no background worker. Optional scalar values can be read when present in `preferences`; defaults are resolved without creating the extension.
- Unknown future extension schemas remain untouched.

## Scope boundaries
No FieldKit/Hub/Cursor changes. No game executable changes. No gameplay sampling, new UI controls, migrations or release-version changes in Lot 1. Native acceptance, cross-map behavior and the complete API fixture remain unverified until a real-game test.

## Test acceptance
`AzerothStats/tests/v2_foundations.lua` covers missing/partial/invalid/throwing APIs, non-subscription, preferences, retained schema and future-schema isolation. The established offline checks and release policy must still run; GitHub CI is the definitive evidence for the full suite. This document is not a claim of in-game testing.

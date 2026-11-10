# Native run identity and correlation contract — v2.0.3 proposal

Status: **diagnostic evidence only; persistence and automatic matching remain disabled.** This document records the owner's native observations and proposes a safe contract for review with Rakesh.

## Evidence observed in the game client

| Scenario | Azeroth Stats local run | Native candidate | Observation |
|---|---|---|---|
| Same run, five successive `/reload` operations | `azstats-327` | Same opaque prefix, counter `-11` | Stable through five reloads |
| Next run, same Elwynn map, same client session | `azstats-328` | Same prefix, counter `-12` | Counter advanced |
| New run after full client restart | `azstats-329` | Different opaque prefix, counter `-1` | New apparent session namespace |

Earlier owner observations also showed the same candidate token against two distinct local runs in different zones (`azstats-320` and `azstats-321`). This is a warning that candidate capture timing, stale values, and session transitions must be considered; it is not safe to assume every observation belongs to the current run merely because the value is non-empty.

## Interpretation (not yet a game API guarantee)

The observed candidate string has the apparent shape `<opaque-prefix>-<counter>`. The current evidence is consistent with:
- opaque prefix changing at full client process restart;
- counter remaining stable during reload continuation;
- counter advancing for a new run within the same process.

This suggests a process/session-scoped identifier. It does **not** prove prefix uniqueness across accounts, devices, time, cloned clients, or simultaneous sessions. Nor does it prove that the candidate is always sampled at the exact run-start boundary. No official global-uniqueness guarantee has been supplied.

## Proposed composite identity

Keep the existing Azeroth Stats local ID as the primary key inside its SavedVariables. If native persistence is later accepted, store an optional additive field on the exact run record:

- `nativeRunId`: exact scalar candidate read from `AZS_ZONE.run`, captured only while the owning run is active and after lifecycle validation.
- `nativeIdScope`: literal `client-session` to state that the value is not globally unique.
- `nativeIdObservedAt`: timestamp plus explicit clock provenance, only if a reliable observation timestamp exists.
- `nativeIdSource`: literal `AZS_ZONE.run`.

Never replace `id`, never backfill old runs, never merge by native ID alone, and never copy a candidate from a neighboring run. Missing or malformed values remain absent/null. Unknown fields and existing WoW Logs direct-reader fields remain untouched.

For a correlation key scoped to one uploader execution, a proposed tuple is:

`(uploadId, clientSessionNamespace, nativeRunId, localRunContext)`

The uploader owns `uploadId`; Azeroth Stats does not invent it. The session namespace may be derived from the opaque prefix only if Rakesh confirms its semantics. `localRunContext` (zone, difficulty, start-time window) is a consistency check, not a substitute identity and not a reason to merge ambiguous runs.

## Safe behavior before acceptance

1. Current probe remains read-only.
2. AZST1 continues to emit `nativeRunId:null`.
3. Desktop SavedVariables layout remains unchanged.
4. No native ID is persisted or attached retrospectively.
5. No network, uploader, or WoW Logs dependency is introduced.
6. If one candidate is seen against two local IDs in one live process, emit a diagnostic warning and refuse automatic correlation.

## Acceptance gates before optional persistence

- Normal run: candidate sampled before/after final summary and attached to correct local run.
- Five-reload continuity: same local ID and same native candidate throughout.
- New same-map run: distinct candidate and distinct local ID.
- Full client restart: new candidate namespace; prove no stale previous candidate leaks into first new run.
- Endless: determine whether the same native candidate spans the base run and Endless continuation or whether the game exposes a new logical run.
- Escape → Quit game: determine whether the interrupted run is finalized, retained, or resumed; no fabricated end timestamp.
- Desktop and browser: verify identical field type and lifecycle.
- WoW Logs AS: Rakesh confirms whether the session prefix is meaningful and whether same-upload scoping prevents cross-session collisions.

Until all gates are accepted, the correct implementation is **no persistence**. This is intentional safety, not an unfinished accidental omission.

# LOT 2 — Combat Intelligence (work in progress)

## Scope
The first implementation introduces a volatile, opt-in observer in `V2CombatObserve.lua`, called from the existing 1 Hz V2 sampler. It is **off by default**. No combat reader is called while disabled, outside an active run or when the client API is missing.

## Native stream
- Subscribe using a nil cursor at the current tail, never replay earlier hits.
- Independent cursor; process up to 8 pages of 256 events per tick.
- Count `droppedCount`, reset after `STREAM_CHANGED`, and flag incomplete data.
- Keep separate bounded groups for meter source key and school mask. Observed damage is not the official native meter total.
- `playerDistance` is **not** on combat event records; it is projection-only and is intentionally not inferred.
- No native rendering/frame handlers and no impact projection.

## Not yet complete
- A bounded summary is now checkpointed to the existing schema-1 V2 extension and displayed alongside the authoritative native meter in the Combat report.
- The 1 Hz polling budget and high event-rate scenarios need benchmarking and tests.
- The Optional analyses menu now exposes a Combat Intelligence opt-in toggle, off by default.
- Co-op and encounter intelligence are separate lots.

**Do not publish or merge until CI, overload tests and in-game validation are complete.**

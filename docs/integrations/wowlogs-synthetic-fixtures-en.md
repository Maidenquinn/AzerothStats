# Azeroth Stats ↔ WoW Logs AS — synthetic fixture catalog

**All examples here are synthetic. None was captured from a player or native client.** These are test inputs for contract review, not proof of native behavior. Field names reflect Azeroth Stats retained-run records and the proposed AZST1 projection. The desktop uploader may consume additional fields; do not treat these fixtures as a complete saved database.

## Retained-run examples (Lua)

```lua
local fixtures = {
  standard = {
    id = "azstats-test-1", status = "ended", result = "victory",
    zone = "naxx", heroic = 1, startedAt = 1700000000, endedAt = 1700000120,
    values = { kills = 80, duration = 120, damage = 10000 },
    summary = { result = "victory", t = 120 },
    stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  missing_metrics = {
    id = "azstats-test-2", status = "interrupted", zone = "naxx",
    values = {}, summary = nil, stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  legitimate_zero = {
    id = "azstats-test-3", status = "ended", result = "defeat",
    values = { kills = 0, gold = 0, healing = 0, duration = 10 },
    summary = { result = "defeat", t = 10 }, stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  reload_continuation = {
    id = "azstats-test-4", status = "active", zone = "naxx",
    values = { kills = 15, duration = 60 }, resumeHeuristic = true,
    summary = nil, stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  interrupted = {
    id = "azstats-test-5", status = "interrupted", partial = true,
    values = { kills = 3, duration = 15 }, summary = nil,
    stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  native_id_candidate = {
    id = "azstats-test-6", status = "ended", values = { kills = 45, duration = 90 },
    nativeRunId = "synthetic-native-7", -- illustrative only; NOT persisted by v2.0.3 yet
    summary = { result = "victory", t = 90 }, stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
  no_native_id = {
    id = "azstats-test-7", status = "ended", values = { kills = 45, duration = 90 },
    summary = { result = "victory", t = 90 }, stats = {}, equipment = {}, timeline = {}, deaths = {},
  },
}
```

**Important:** The current `ExportRunV1` intentionally emits `nativeRunId = nil` even if an input fixture contains the illustrative `nativeRunId` field. The native identity is not yet accepted or persisted. JSON serialization emits `"nativeRunId":null` for these examples.

## Valid synthetic AZST1 example

This minimal demonstration shows the envelope, not the complete 13-metric production payload:

```text
AZST1:{"v":1,"addon":"AzerothStats","schema":"1.0.0","run":{"localId":"azstats-test-3","nativeRunId":null,"zone":null,"class":null,"heroic":null,"status":"ended","outcome":"defeat","partial":null,"startedAt":null,"endedAt":null},"metrics":{"kills":{"availability":"available","value":0,"provenance":"retained-run"},"gold":{"availability":"available","value":0,"provenance":"retained-run"},"damage":{"availability":"unavailable"}}}
```

## Field contract and privacy

- `v`: integer `1`; `addon`: literal `AzerothStats`; `schema`: `1.0.0`.
- `run.localId`: non-empty string (max 80 bytes), local only; `nativeRunId`: null pending native acceptance.
- `zone`: optional string max 80 bytes; `class`: optional string max 40 bytes; `heroic`: optional integer 0–5.
- `status`: `active`, `ended`, `interrupted`, `terminal` or null; `outcome`: `victory`, `defeat`, `left` or null.
- `partial`: true, false or null. `startedAt` and `endedAt`: finite numeric timestamps or null; current exporter does not assert a universal clock source.
- Metric keys: `duration`, `level`, `kills`, `gold`, `damage`, `taken`, `healing`, `peakDps`, `bosses`, `elites`, `guardians`, `chests`, `magnets`. Each is `{availability:"unavailable"}` or `{availability:"available",value:number,provenance:"retained-run"}`.
- No backup roots, coop partner names, character names, raw events, or equipment tooltips. Run IDs, timestamps and zone may still be correlating identifiers.
- Current production limit is **8192 bytes**. Oversized outputs fail, never truncate.
- The partner's uploader currently reads SavedVariables directly on desktop; AZST1 ingestion for browser users remains a proposed future importer, not a working website feature.

## Questions pending native/partner validation

- Native ID lifecycle, reuse and uniqueness across sessions; browser vs desktop differences.
- Whether the WoW Logs importer accepts `AZST1` null semantics, metric provenance and missing fields exactly as proposed.
- Real export size distributions and copy-window limits on the game client.
- Whether the site reads the same paths for older and restored saves.

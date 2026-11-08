# WoW Logs AS v0.2.2 — source-based integration audit

Source: user-supplied `WowLogsAS-v0.2.2(1).zip` (seven files; `WowLogsAS/WowLogsAS.toc` reports 0.2.2). This document describes the supplied source, not an independently verified native runtime contract.

## Verified in supplied source

- `Recorder.lua` `currentRunId()` (lines 737-743) reads `AZS_ZONE.run`, converts a nonempty value to a string, and returns nil otherwise.
- `Recorder.lua` `NewRun()` (lines 233-255) stores the game run ID as `gameRunId` and creates a separate local `wlas-<sequence>` ID.
- `Recorder.lua` `resumable()` (lines 745-755) resumes the last active record on reload if `gameRunId` and schema match; this is not evidence of globally unique run IDs.
- `Recorder.lua` `Update()` (lines 757-801) observes phase and game run ID each second; an ID change finishes the prior run and starts a new one in a live phase.
- `Export.lua` `BuildCode()` returns a `WLAS<version>:` prefix followed by JSON with `runId = run.gameRunId`, character metadata, summary, ledger totals, loadout, encounters, and other fields. This format is WoW Logs' own summary code, not the Azeroth Stats v1 schema.
- `Core.lua` provides `/wlas export` for the last saved run, with a copyable window; `WowLogsASDB` is the separate SavedVariables root. Its README says saved runs are normally written on game exit or return to menu and that no addon web request is performed.
- The supplied README explicitly reserves stat history, pick history and item tooltips to Azeroth Stats. It warns that co-op recordings may contain companion names.

## Design implications for Azeroth Stats

1. Do not merge runs based on local `azstats-<sequence>` and `wlas-<sequence>` IDs; both are addon-local.
2. A native game run ID may be a useful *candidate* matching signal, but requires runtime evidence for stability across reload, lifecycle, and reuse before being used as authoritative.
3. Do not copy WoW Logs' granular combat ledgers, positions, or hit feed into Azeroth Stats. Its recorder already owns those data.
4. Keep the current read-only `ExportRunV1` projection independent of WoW Logs and private by default. No auto-upload and no dependency.
5. Coordinate a shared correlation contract and ingestion format with Rakesh rather than inserting Azeroth Stats data into the existing `WLAS` payload without his approval.
6. A user-triggered local handoff may be implemented later, but must specify the actual supported uploader format and explicit privacy choices first.

## Native acceptance still required

Observe `AZS_ZONE.run` on new runs in the same zone/class, repeated `/reload`, ready-to-live transitions, end/run exit, endless continuation, desktop and browser clients. Compare both addons' recorded IDs, clock/phase and final summary. Do not assume that a reused numeric or string ID represents the same run.

## Scope

No modification of WoW Logs AS, `WowLogsASDB`, or existing Azeroth Stats SavedVariables is authorized by this audit. The source ZIP contains no tests folder or uploader/server source, so uploader ingestion behavior and website merge rules remain unknown.

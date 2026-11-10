# Azeroth Stats v2.0.3 — Rakesh-confirmed integration requirements

Status: implementation roadmap and acceptance gates. Source: Rakesh's technical replies relayed by the project owner on 2026-11-09. These are partner statements, not independently verified runtime behavior.

## Revised architecture

**Priority 1 — direct desktop import compatibility.** WoW Logs currently reads Azeroth Stats SavedVariables directly, including `runs[].summary`, `stats`, `equipment`, `timeline`, and `deaths`. Kills and duration are matching signals for combat logs. Preserve field names, types and history across v2.0.2 saves, v2.0.3 writes, restore and malformed/missing records. An optional `nativeRunId` field must be additive and must never replace the existing local `id` or alter the reader's existing structures.

**Priority 2 — native identity observation.** WoW Logs AS reads `AZS_ZONE.run`; its own reload resume requires an unchanged native run ID. Uniqueness across separate runs is unknown. The partner uses Lua `time()` (seconds, client-local PC clock); runs are scoped to the user's WoW Logs account and matched only within the same upload, never by character name. Continue diagnostic-only `/azstats interop probe` until native evidence supports non-destructive, per-run persistence. Do not backfill historical IDs or infer global uniqueness.

**Priority 3 — browser/manual export.** Retain `AZST1:` + versioned JSON as a separate proposed importer format, distinct from `WLAS2:`. Rakesh accepts the independent-importer approach but has **not implemented an AZST1 importer**. No claim of live website compatibility. Manual selection, preview, generate, copy, actionable errors; no automatic chat paste or network sender. Current serializer limit: 8192 bytes; no silent truncation. Measure actual output before revisiting cap.

## Non-destructive compatibility contract

- Existing SavedVariables roots remain `AzerothStatsDB`, `AzerothStatsBackup`, `AzerothStatsAutoBackup`; do not introduce another root for interoperability.
- Never rename, delete, flatten or re-type `runs[].summary`, `stats`, `equipment`, `timeline`, `deaths`; do not drop unknown historical fields.
- `nativeRunId` (if approved after native acceptance) is optional, scalar, bounded and associated only with the observed run; missing means unknown, not zero. Preserve local ID and timestamp fields.
- Do not rewrite a run's identity based solely on a matching native candidate. In particular, repeated numeric IDs may collide between games.
- Desktop uploader handles the account/upload scope; Azeroth Stats does not embed player identity or account details into AZST1.
- AZST1 allowlist excludes backups, coop partner names, equipment tooltips and raw event streams; no full-history export by default.
- Treat local run ID, native candidate, timestamps, class and zone as potentially identifying/correlating metadata even without names.

## Native recipe (record observed values, not player identity)

Record phase, `type(AZS_ZONE.run)`, a redacted stable token per value, `/azstats interop probe`, local Azeroth Stats run ID, WoW Logs AS gameRunId, run count and status, and whether a new saved record appeared. Do not publish raw player identifiers. Perform:

1. Normal run from ready to terminal summary.
2. `/reload` during active run.
3. Multiple successive `/reload` during the same run.
4. New run after completed run (same map/difficulty if possible).
5. Endless continuation and final termination.
6. Escape → Quit game during a run, restart, inspect retained history.
7. Full client shutdown/restart and new run.
8. Repeat on desktop and browser where feasible.

Acceptance: one retained local run per real continuous run; no accidental merge of separate runs; no duplicate accounting; existing backups unchanged; partner identifier observed consistently where available. A changed/missing native candidate must never silently overwrite historical identity. **No native persistence before this recipe is accepted.**

## Offline test and delivery matrix

| Gate | Required proof |
|---|---|
| Contract | synthetic v2.0.2, v2.0.3, partial, missing, restored, malformed fixtures; assert direct-import field preservation |
| Export | valid deterministic AZST1 JSON, Unicode, controls, NaN/Infinity, absent vs zero, max bytes, privacy, no mutation |
| UI | explicit retained-run selection, preview, copy window, understandable errors, FR/EN |
| Performance | compare v2.0.2 vs v2.0.3 with 1/100/1000 runs; lookup, encode, allocation estimate, byte size, malformed input |
| Integration fixtures | synthetic normal, absent, zero, reload, interrupted, with/without native ID and AZST1 sample; no false claim of native origin |
| CI | formatter, offline checks, prior regressions, package SHA-256, ZIP artifact green |
| Native | owner acceptance of seven scenarios above, including desktop/browser where available |

## Scope exclusions

No WoW Logs uploader/backend/website/leaderboard/anticheat development; no mandatory WoW Logs AS dependency; no duplicate combat collector.

## Release rule

Do not merge PR #35 or publish v2.0.3 without explicit owner approval. Supply a CI-green installable test ZIP, changelog, native recipe and measured report first.

## Owner native observation — 2026-11-10 (not a controlled acceptance run)

The owner supplied screenshots/log excerpts showing two distinct local run IDs (`azstats-320` and `azstats-321`), in different zones (`naxx` and `ab`), both displaying the same redacted native candidate token. This is direct evidence that the currently observed candidate is **not sufficient by itself** to identify a unique retained run in this session. Do not persist or auto-match it. Repeat controlled scenarios N1–N7 to determine whether the field is session-scoped, stale, reused or sampled at an unexpected lifecycle point.

The same export showed an `interrupted` run with `partial:false`. The projection now forces `partial:true` for `active` and `interrupted` records without mutating historical SavedVariables; explicit coverage flags are retained for other statuses. Native export and CI still need validation after this correction.

The diagnostic command now retains only the last probe observation in session memory and warns when the same native candidate is observed against a different local run ID. This is not SavedVariables persistence and is not an automatic correlation rule. A missing candidate does not erase the last valid observation.

## Owner native recipe update — 2026-11-10 13:46

The owner performed a sequential same-zone test on Arathi Basin, without returning to the menu between runs:
- First retained run `azstats-322`: active, zone `ab`, native candidate token ending `-2`.
- Next retained run `azstats-323`: active, same zone `ab`, native candidate token ending `-3`.
- The candidate remained unchanged across repeated probes within the first run; the candidate changed for the next local run.
- Exported records correctly showed `partial:true` while active.

This is encouraging evidence that the candidate changes between these two sequential runs and remains stable during the first observed run. It does **not** prove behavior after full client restart, across endless/quit transitions, or global uniqueness. Do not enable persistent native ID yet.

The screenshots also show the selector input changed to `azstats-323` while the summary still displayed the previously generated `azstats-322` export. The dialog now clears the old generated code and invalidates the preview whenever the selected ID changes, so a stale export cannot be mistaken for the current selection.

## Owner SavedVariables inspection — 2026-11-10 13:58

The owner supplied a real `AzerothStats.lua` SavedVariables file after the same-zone sequential test. The file is 91,574,179 bytes and reports addon version `2.0.3`, schema `2`, and 239 retained runs in the root run history. The file contains no `nativeRunId` or literal `AZS_ZONE.run` field; native candidates remain diagnostic-only and are not persisted.

Two retained run records were inspected (character identity removed from this note):
- `azstats-322`, zone `ab`, class `warrior`, heroic `3`: official result `left`, duration 41.5 s, terminal timeline at 41.47 s, official summary at 41.5 s.
- `azstats-323`, same zone/class/difficulty: official result `left`, duration 81.2 s. Its event history contains two separate `checkpoint` events labelled `Sortie normale du client`, each immediately followed by `resume` labelled `Reprise probable apres rechargement ; pas d'identifiant serveur`. The run keeps the same local ID across both checkpoints and continues through level 8 before the terminal/summary boundary.

This is strong evidence that the addon resumed one retained local run across two normal client-exit/re-entry checkpoints in this test. It is **not** proof of native-ID persistence (none is present), nor does the event text alone prove whether each exit was a full client restart or another clean reload path. Record this as observed local continuity, not as proof of the server identifier's lifecycle.

Both records have `partial=false` after receiving an official `left` summary. This is not automatically a defect: the export's `partial` flag describes data coverage/completeness, while `outcome=left` describes the official run result. Keep those concepts separate; do not force all voluntarily-left runs to `partial=true` without a contract-level definition.

The fixture source contains character names, equipment links, item details, and long combat telemetry. Do not commit the raw SavedVariables file. Any future regression fixture must be minimized and anonymized, retaining only the fields needed to test the two checkpoints and the run identity.

## Direct-reader compatibility and backup-size audit — owner file

The inspected retained-run records contain the exact top-level structures Rakesh described: `summary`, `stats`, `equipment`, `timeline`, and `deaths`. The run also retains `values`, `official`, `events`, `status`, and `result`. The two tested runs therefore provide real evidence that these direct-reader fields are present in the 2.0.3 SavedVariables sample; no rename or compatibility alias is indicated by this sample.

The file has one primary `AzerothStatsDB` root (schema 2, addon version 2.0.3) and a separate `AzerothStatsBackup.entries` root. Three backup entries are present. The primary database section occupies about 21.4 MB; the backup section occupies about 70.1 MB, with individual snapshots approximately 22.8–23.9 MB. Total file size is 91,574,179 bytes. The saved settings show `autoBackupRetention=3`, `autoBackupEveryRuns=3`, and `autoBackupRunCounter=2`.

These backups are embedded as a separate SavedVariables root in the same physical Lua file, not as three independently written files. The raw file must never be committed as a fixture because it contains character identity, equipment item links/tooltips, and extensive telemetry. AZST1 continues to project only one explicitly selected retained run; it must not serialize `AzerothStatsBackup`. A regression test now inserts a private sentinel in that root and asserts it is absent from generated AZST1.

## Anonymized regression fixture added — owner SavedVariables sample

A minimized, anonymized test case now mirrors the owner's retained Arathi Basin run `azstats-322`:
- `status=ended`, official `result=left`, `partial=false`
- `zone=ab`, `class=warrior`, `heroic=3`
- observed values include 41.5 seconds, 45 kills, 16 gold, 24,888 damage, 104 taken, and 104 healing
- private `summary`, `stats`, `equipment`, `timeline`, and `deaths` fields are included as sentinels and must not enter AZST1

The regression asserts that an official `left` outcome is not automatically synonymous with incomplete metric coverage, that observed metrics remain intact, that rich private fields are excluded from the allowlisted paste export, and that the source SavedVariables-shaped table is not mutated. The fixture is synthetic/minimized and contains no character name, item link, raw telemetry, or native candidate token.

The uploaded SavedVariables file does not persist the read-only `AZS_ZONE.run` candidate or the chat output from `/azstats interop probe`. Therefore it can validate retained-run continuity and export projection, but it cannot independently prove the native candidate's behavior across reloads or process restarts. Those observations must remain separately captured from the in-game probe output.

The same sample also contains an ended retained run (`azstats-323`) with an official `left` result and `partial=false`, but no `endedAt` field. The export must preserve this as unavailable (`null` in AZST1), never synthesize a wall-clock timestamp from duration or neighboring runs. Regression coverage now includes both a left run with an observed `endedAt` and one without it.

### Timestamp anomaly retained for investigation

The two real records expose a metadata inconsistency that must not be silently repaired:
- `azstats-322`: `startedAt=1794318254`, `endedAt=1794318897`, but the retained in-run duration is only 41.5 seconds. The wall-clock interval is 643 seconds.
- `azstats-323`: `startedAt=1794318315`, status `ended`, official result `left`, duration 81.2 seconds, but no `endedAt` field is present.

The sample alone cannot establish whether this is delayed official-summary delivery, save/finalization timing, or a tracker lifecycle defect. Do not derive `endedAt` from duration or copy it from another run. AZST1 must faithfully preserve the observed timestamp or emit `null`; add a dedicated native reproduction before changing Tracker semantics.

## Full owner SavedVariables review — 2026-11-10

The owner supplied a complete Azeroth Stats SavedVariables file after the native continuity scenarios. The raw file is approximately 88 MiB in the working copy and contains the main `AzerothStatsDB` plus a separate `AzerothStatsBackup` root. It is **not** committed or redistributed; only minimized, anonymized test inputs are used.

Observed in the main database:
- 241 retained run records are present (numeric retained-run indices through 241); the database reports 82 pruned records. The local sequence has reached at least `azstats-323`.
- The two relevant same-zone records are distinct retained entries: `azstats-322` and `azstats-323`, both zone `ab`, class `warrior`, Heroic 3.
- `azstats-323` contains two `checkpoint` / `resume` event pairs, with the event text reporting normal client exit and probable resume. It remains one retained local run ID through those observed transitions; no additional fragmented local run appears between those checkpoints in this record.
- This supports continuity across two recorded exit/resume transitions for this one run. The event text alone cannot distinguish a full process restart from another normal client reload path, and it does not prove the native candidate's identity behavior across either transition.
- Both records have an official `left` summary. The first has a wall-clock `endedAt`; the second has no `endedAt`, which must remain null in AZST1. Their observed durations are separate in-run measurements and must not be used to synthesize wall-clock end timestamps.
- No `nativeRunId` or raw `AZS_ZONE.run` candidate is persisted anywhere in the supplied SavedVariables file. The file therefore cannot prove the candidate's lifecycle; only the paired in-game probe output can do that.

A minimized synthetic regression now covers the two checkpoint/resume pairs, the official `left` outcome, absent `endedAt`, exclusion of the event journal, and forced `nativeRunId:null`. Do not add the raw SavedVariables file to the repository or CI artifacts.

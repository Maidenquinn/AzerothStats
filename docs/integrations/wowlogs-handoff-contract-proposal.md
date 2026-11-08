# Azeroth Stats ↔ WoW Logs AS: proposed handoff contract (draft 2026-11-08)

**Status: proposal for Rakesh; not a format accepted by his site.** Based on user-provided `WowLogsAS-v0.2.2(1).zip`, especially `Export.lua`, `Util.lua`, and `Recorder.lua`. No WoW Logs backend/uploader code was supplied.

## Source-backed reference behavior

WoW Logs AS v0.2.2 declares `A.exportVersion = 2` and emits `WLAS2:` followed by JSON (`Export.lua` `BuildCode`). The body includes `v`, `addon`, `runId` (from `gameRunId`), hero/class/race, zone/heroic/affixes, wall times, duration, close, summary, damage/healing/taken ledgers, loadout and encounters. Its `Json` serializer uses sorted object keys, quotes control characters and recursively handles its own known plain values. The `/wlas export` UI displays the last run for manual copying. This code does **not** establish an external contract for importing a different addon's data.

## Proposed Azeroth Stats paste envelope

Use a **distinct prefix** `AZST1:` to avoid spoofing or confusing the existing `WLAS2:` parser. Keep the original `ExportRunV1` as the canonical in-memory projection; serialization should produce a small explicitly allowlisted envelope rather than serializing internal run tables.

Example only (synthetic, not uploaded):

```text
AZST1:{"v":1,"addon":"AzerothStats","schema":"1.0.0","run":{"localId":"azstats-17","nativeRunId":null,"zone":"naxx","class":"hunter","heroic":3,"partial":false},"metrics":{"kills":{"availability":"available","value":0,"provenance":"retained-run"},"gold":{"availability":"unavailable"}}}
```

**Important:** this example is abbreviated to demonstrate shape. Production output must include the complete allowlist or a documented sparse representation; never silently infer missing metrics as zero. JSON `null` means unverified/unknown identity, not an empty ID. No character name, co-op roster, private notes, event ledger, backup, or equipment tooltips.

### Compatibility policy

- **No implicit `WLAS2` compatibility.** Rakesh would need to accept `AZST1` in a separate importer, or agree on a common multi-source envelope. Azeroth Stats must not masquerade as WoW Logs AS.
- `run.localId` is only a local Azeroth Stats ID. It must not be matched to WoW Logs' local `wlas-...` ID.
- `AZS_ZONE.run` is a candidate shared native signal; do not persist/claim it as a verified `nativeRunId` until client lifecycle tests pass. Even after that, require supporting zone, heroic and bounded time evidence; ambiguity or contradictions mean **no automatic merge**.
- A match result should be `matched`, `ambiguous`, or `unmatched` with evidence, never silently merged. Existing WoW Logs combat events remain authoritative for detailed combat. Azeroth Stats aggregates are additional, provenance-labeled information; conflicts are displayed, not overwritten.
- No automatic upload or background sending. Explicit user selection, preview, privacy disclosure, then copy/paste or an approved uploader flow.
- Do not persist a second run history, modify existing SavedVariables, or require WoW Logs AS to be installed.
- Preserve available zero vs unavailable. Reject NaN/infinite JSON numbers; limit serialized size and depth; escape JSON correctly; avoid WoW Logs' permissive generic `Json` helper for untrusted input without validation.

## Questions to confirm with Rakesh

1. Can his website/uploader accept a second `AZST1:` paste code, and which API/schema should it use?
2. Does his ingestion require character identity or account scope to avoid cross-player false matches? How can privacy be maintained?
3. What is the actual lifecycle/uniqueness scope of `gameRunId` and what are the timestamp units/time-zone semantics?
4. What limits (bytes, record count, JSON schema version) and duplicate-upload semantics apply?
5. Can his importer represent metrics as observed vs derived, unavailable vs zero, and show conflicting totals without overwriting either source?

## Development gates

1. Add synthetic canonical JSON serialization tests (null/zero/escapes/order/size, no private fields).
2. Add an opt-in manual copy window after agreeing on envelope semantics. Keep feature explicitly experimental until Rakesh confirms ingestion.
3. Compare real client run IDs across reload, ready, new run and endless, with two addons installed.
4. Validate old SavedVariables, memory/performance and FR/EN; deliver CI-green ZIP; request native acceptance before release.

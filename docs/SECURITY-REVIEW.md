# Source security and reliability review

Scope: candidate **1.5.1-review.1**, twenty TOC-loaded modules, packaged assets, developer checks and build policy. Baseline: `eab9e73bddc8416b8e6c38475243932044d4c376` (1.5.0-beta.1). This is a maintainer source review, not an independent penetration test or certification. No written game-team rejection criteria were supplied.

## Assessment

Review of the loaded runtime found no outbound network/message operation, dynamic code evaluation, operating-system file/process access or gameplay automation path. The addon is a passive observer with local persistence/UI effects. That does not imply zero risk: malformed shared data or saves can affect availability and statistical integrity, and local history contains player names.

## Findings addressed

### R1 — malformed shared data could reach consumers (medium: availability/integrity)

Several API, copy and native tooltip paths accepted broader shapes than consumers expected. `Safety.lua` now validates finite counters, text, classes, item-only links, texture namespaces and frame anchors. `API.ReadMeter` rejects malformed/oversized rows **before** native total helpers. Cyclic/deep data is bounded by copy/signature budgets. Explicitly conflicting summary identity is rejected; absent legacy identity remains a documented heuristic. Evidence: `tests/security.lua`, `tests/scenarios.lua`, `tests/collection.lua`.

### R2 — saved shape validation was incomplete (medium: availability)

Whole-tree validation now precedes mutation/migration. Cycles, callbacks, metatables, non-finite numbers, excessive depth/node count and incompatible field shapes disable collection while preserving the original root. This protects against accidental malformed data **after loading**. It cannot sandbox a malicious Lua SavedVariables file: the client evaluates that file first. Evidence: corrupted settings, records, favorites, usage, cycles, functions and budget exhaustion in `tests/security.lua`; legacy persistence checks.

### R3 — new cumulative keys lacked an admission policy (medium: availability)

Source dictionaries and usage maps limit new distinct entries; existing keys keep updating and partial flags remain visible. Favorites have 300-entry/200-protected-run caps. Copies, timelines, evidence and party rows are bounded. An excessively large legacy database is rejected instead of rewritten or silently trimmed. These are resource bounds, not a fixed byte quota or protection from a hostile host altering shared globals. Evidence: full source/usage dictionaries and overflow in `tests/security.lua`.

### R4 — ambiguous accessory aliases and counter regressions (low: integrity)

A Portuguese spell alias could map to different abilities depending on table iteration order. Resolution now prefers character class, then an unambiguous match. Source regressions no longer subtract into negative cumulative values. Required chest/accessory repairs remain as explicit one-time migrations. Evidence: collection, usage, scenarios and legacy idempotence tests.

### R5 — review surface and packaging were unnecessarily broad (low: process)

Removed 705 unused game-text labels per language, an unused importer-registration hook and dead accessory-key data. Split migrations from ordinary processing; named locals/functions have explicit domain roles and comments. JSON generates readable literal-only Lua catalogs. The player archive uses one shared file allowlist and verified manifest. Tests/tools/historical reports are excluded. Evidence: generators, static policy tests, manifest/build verification and archive inspection.

## Residual boundaries

- Host native parsers/font renderer, other addons and shared Lua globals are outside this audit. One addon cannot isolate another here.
- Prefixes/stamps are not authentication. No authenticated run UUID exists; resume/boundary identity remains heuristic. Namesakes can appear as the same companion.
- Limits intentionally discard excessive detail; affected results are partial. The structural change detector is not cryptographic or a security identity.
- SavedVariables files are executable inputs to the client. Never trust someone else's save merely because the addon validates the resulting tree. Developer fixture/save tests also execute trusted Lua inputs in a local VM.
- Names, builds, timestamps and recent death messages are stored locally. Sharing a save/screenshot can disclose them. See [Privacy](PRIVACY.md).
- Offline tests do not prove in-game performance, layout, sound behavior or crash-safe persistence. Disk writes belong to the client; abrupt termination may lose observations.
- Existing OFL fonts and game-derived metadata have separate provenance. This review grants neither redistribution rights nor approval.

## Reproduction

[TESTING](TESTING.md) specifies commands and the manual recipe. `tools/security_review.py` rejects known unwanted capability tokens and nonliteral catalogs, then emits a call/widget inventory for a human. It is not a complete Lua security analyzer: aliasing or a new API name requires review. The adversarial suite stubs selected prohibited effects and asserts they are not invoked in tested flows; untested flows still require source review.

Approval and distribution decisions belong to the game developers. No approval is asserted here.

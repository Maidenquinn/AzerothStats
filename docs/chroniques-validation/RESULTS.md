# Chroniques development preview validation

Version: **1.6.0-dev.1**. Recorded 2026-10-27. These are automated maintainer checks and simulated clients, not game-team approval or an in-game playthrough.

- Complete suite: **3,524 assertions**, passing under Lua 5.1/Lupa and native Lua 5.0.3.
- Client-independent model/UI suite: **3,139 assertions** (overlaps the full suite; do not add these counts).
- Final player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,548 assertions**, including HUD settings surviving two independent process restarts.
- **13 Python unit tests** covering input-fixture loading, runtime policy and original asset generation.
- All fourteen locale key sets and UI glyph coverage checked; three CJK font derivatives rebuilt from hash-pinned original inputs with existing glyphs retained.
- Twenty-three TOC modules, five literal-only catalogs, native syntax/upvalue checks, formatting, source policy, deterministic texture generation and the forty-file player allowlist verified. Manifest makes **41 ZIP members**.
- Existing schema-1 data compatibility and accounting/persistence regressions pass in memory. Private SavedVariables contents/input identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.1.zip`

SHA-256: `5370b7b11e608590fddab1e5fef3904034fe3190e4384f54dae1e23c53b5bf88`

Machine-readable evidence: `native.json`, `acceptance.json`, `runtime-policy.json`. An explicitly selected trusted local API fixture was used; its bytes are not distributed.

Manual verification still required: native backdrop/atlas/font rendering, actual mouse/slider/drag ordering, screen edges/scales, restart behavior with the running game and all fourteen language layouts. Follow `docs/CHRONIQUES.md`. Source code inspection found no newly introduced outbound communication or gameplay action; static policy checks remain an aid to review rather than proof.

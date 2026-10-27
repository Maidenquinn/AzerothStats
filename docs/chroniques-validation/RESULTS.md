# Chroniques development preview validation

Version: **1.6.0-dev.7**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; game-team approval remains pending.

- Complete suite: **3,853 assertions**, with Lua 5.1/Lupa and native Lua 5.0.3; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,223 assertions**, overlapping the full suite.
- Exact player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,548 assertions**, including settings across independent restarts. These are simulated scenarios, not in-game playthroughs.
- **15 Python unit tests**. All packaged TGAs are RGBA, power-of-two and at most 256 pixels per edge. Original source hashes, per-zone mapping and UV framing checked.
- Twenty-three TOC modules, native syntax/upvalue limits, formatters, runtime policy and the 72-file payload allowlist checked. Manifest makes **73 ZIP members**.
- All fourteen locale key sets/glyph coverage checked. New scenarios cover native zone fallback in every catalog language, authoritative packet precedence, late metadata enrichment, compatible reload continuity and reset-clock isolation.
- Page regressions cover localized context bands/body capacity, retained-only History counts, Favorite run photos, widget reuse and UTF-8-safe text sanitization.
- Existing HUD editor tests cover independent movement targeting, saved positions, scale compensation, lock/reset, transactional Apply/Cancel and widget reuse.
- Private saved data and identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.7.zip`

SHA-256: `1fe59e4981651b71a6cbb049f96c615071a66faa0da5c6c560169e5acef61495`

Machine-readable evidence: native.json, acceptance.json, runtime-policy.json. The explicitly selected trusted API fixture is not distributed.

**Native visual evidence:** user screenshots of dev.4 confirm small Chroniques components render; screenshots of dev.6 confirm supplied zone photos render. This is not proof of universal texture limits or full concept fidelity. The native move-to-start prompt can still draw over the addon. Dev.7 shared layouts and fallback/resume behavior require the targeted real-client checks in TESTING.md. Offline widget previews were inspected with synthetic data and are explicitly labeled as such.

**Identity limit:** no server run UUID is available. Same-player/map increasing-clock reload continuity remains heuristic; reset/closed runs are not borrowed and historical duplicates/unknown ended runs are not automatically rewritten.

# Chroniques development preview validation

Version: **1.6.0-dev.8**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; game-team approval remains pending.

- Complete suite: **3,977 assertions in Lua 5.1/Lupa and 3,976 in native Lua 5.0.3**; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,344 assertions**, overlapping the full suite.
- Exact player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,629 assertions**, including settings across independent restarts. These are simulated scenarios, not in-game playthroughs.
- **15 Python unit tests**. All packaged TGAs are RGBA, power-of-two and at most 256 pixels per edge. Original source hashes, per-zone mapping and UV framing checked.
- Twenty-three TOC modules, native syntax/upvalue limits, formatters, runtime policy and the 72-file payload allowlist checked. Manifest makes **73 ZIP members**.
- All fourteen locale key sets/glyph coverage checked. New scenarios cover native zone fallback in every catalog language, authoritative packet precedence, late metadata enrichment, compatible reload continuity and reset-clock isolation.
- Page regressions cover localized context bands/body capacity, retained-only History counts, Favorite run photos, widget reuse and UTF-8-safe text sanitization.
- Existing HUD editor tests cover independent movement targeting, saved positions, scale compensation, lock/reset, transactional Apply/Cancel and widget reuse.
- Private saved data and identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.8.zip`

SHA-256: `f77ed03afe08380dd724aac84cf380be72d5106fb5de4e982700a761de968ed8`

Machine-readable evidence: native.json, acceptance.json, runtime-policy.json. This run used the newly installed client read-only, identified in the JSON evidence; no extracted client API is distributed.

**Native visual evidence:** user screenshots of dev.4 confirm small Chroniques components render; screenshots of dev.6 confirm supplied zone photos render. This is not proof of universal texture limits or full concept fidelity. The native move-to-start prompt can still draw over the addon. Dev.7 shared layouts and fallback/resume behavior require the targeted real-client checks in TESTING.md. Offline widget previews were inspected with synthetic data and are explicitly labeled as such.

**Identity limit:** no server run UUID is available. Same-player/map increasing-clock reload continuity remains heuristic; reset/closed runs are not borrowed and historical duplicates/unknown ended runs are not automatically rewritten.

**0.121 / dev.8:** verified AZS_ZONE.heroic serialization in the newly installed executable; source/native tests cover 0..5, invalid/missing fields, reload and late metadata. The exact ZIP matrix cycles all six difficulties, including persistence of the selected History filter. Long set-tooltip tests preserve 58 native-text lines, including a synthetic fractional bonus beyond line 40. New labels have fourteen-language glyph coverage. No structured marks/affix/stars API is claimed; see CLIENT-0.121.md. Actual Heroic gameplay and upgraded-piece tooltip checks remain pending. Offline synthetic History/Character layouts were visually inspected.

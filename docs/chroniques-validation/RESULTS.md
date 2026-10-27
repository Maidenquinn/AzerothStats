# Chroniques development preview validation

Version: **1.6.0-dev.4**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; no game-team approval or native visual sign-off is claimed.

- Complete suite: **3,577 assertions**, with Lua 5.1/Lupa and native Lua 5.0.3; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,192 assertions**, overlapping the full suite.
- Exact player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,548 assertions**, including settings across independent restarts.
- **14 Python unit tests**. Every packaged TGA is RGBA, power-of-two and has a maximum edge of 256 pixels; source component identity, transparency and package inclusion are checked.
- Twenty-three TOC modules, literal-only catalogs, native syntax/upvalue limits, formatters, runtime policy and the 64-file allowlist checked. Manifest makes **65 ZIP members**.
- All fourteen locale key sets/glyph coverage checked. The renamed heading face has actual bold weight, with official input commit/hash and embedded OFL notices retained.
- HUD tests exercise full-size draft preview, cancel restoring the stored layout, original hidden-state restoration across repeated opens, independent settings, geometry, locales and widget reuse.
- Private saved data and identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.4.zip`

SHA-256: `4e18bf674c07aac930c73f66a37255b9abe20c5f6680449e4a5c99bbc9d05e99`

Machine-readable evidence: native.json, acceptance.json, runtime-policy.json. The explicitly selected trusted API fixture is not distributed.

**Native limitation:** dev.3's four 1024-square images did not display after a confirmed complete client restart, despite passing format/model tests. Their exact rejection mechanism is unknown. Dev.4 replaces them with 24 small components matching prior working dimensions/depth; this is a conservative packaging change, not a verified universal size limit or a confirmed native fix. The newly packaged components, modified heading face and closer layout still need native image-loading/fidelity confirmation. The client move-to-start foreground prompt was observed over addon windows; no verified fix is claimed and no native HUD element is hidden to disguise it. Offline previews use synthetic data and approximate compositing. Follow docs/CHRONIQUES.md before public delivery.

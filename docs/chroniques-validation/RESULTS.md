# Chroniques development preview validation

Version: **1.6.0-dev.5**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; no game-team approval or native visual sign-off is claimed.

- Complete suite: **3,589 assertions**, with Lua 5.1/Lupa and native Lua 5.0.3; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,204 assertions**, overlapping the full suite.
- Exact player ZIP: **1 class/outcome smoke case**, **3 fresh Lua 5.0 processes**, **58 assertions**, including settings across independent restarts.
- **14 Python unit tests**. Every packaged TGA is RGBA, power-of-two and has a maximum edge of 256 pixels; source component identity, transparency and package inclusion are checked.
- Twenty-three TOC modules, literal-only catalogs, native syntax/upvalue limits, formatters, runtime policy and the 64-file allowlist checked. Manifest makes **65 ZIP members**.
- All fourteen locale key sets/glyph coverage checked. The renamed heading face has actual bold weight, with official input commit/hash and embedded OFL notices retained.
- HUD tests exercise full-size draft preview, cancel restoring the stored layout, original hidden-state restoration across repeated opens, independent settings, geometry, locales and widget reuse.
- Private saved data and identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.5.zip`

SHA-256: `c4e14bcd30448971a01d7cd46bb66f3ef043b9dbebe603c84416a9ec1ca1db4f`

Machine-readable evidence: native.json, acceptance.json, runtime-policy.json. The explicitly selected trusted API fixture is not distributed.

**Native visual evidence:** user screenshots of dev.4 confirm that the small glyph, material and landscape components render in the installed game. This validates that workaround on the observed client, not a universal texture-size rule or full fidelity to the concept. The native move-to-start prompt still draws over the addon.

**Dev.5 movement follow-up:** the editor now has an independent UIParent hierarchy/anchor and a header drag handle. Regression tests exercise movement targeting, global lock, separate saved position, reopen behavior, scale compensation, wide-screen restoration, resetpos and malformed saved anchors. The complete source suite passed with native Lua 5.0.3; the exact player ZIP passed a fresh-process smoke case. The earlier full 27-case package matrix belongs to dev.4, not dev.5. The newly independent panel still needs an actual mouse-drag/reload check; simulated callbacks are not proof of native interaction behavior.

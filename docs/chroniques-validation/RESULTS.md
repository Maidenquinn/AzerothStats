# Chroniques development preview validation

Version: **1.6.0-dev.3**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; no game-team approval or native visual sign-off is claimed.

- Complete suite: **3,572 assertions**, passing with Lua 5.1/Lupa and native Lua 5.0.3; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,187 assertions**, overlapping the full suite.
- Exact player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,548 assertions**, including settings across independent restarts.
- **14 Python unit tests**; all fourteen locale key sets and UI glyph coverage checked.
- Twenty-three TOC modules, literal-only catalogs, native syntax/upvalue limits, formatting, runtime policy, deterministic original artwork encoding and the 44-file allowlist checked. Manifest makes **45 ZIP members**.
- New UI contracts cover explicit nine-slice dimensions, legible card glyphs, taller proportions, recent-run/record separation and dynamic editor height. These tests do not prove native rendering fidelity.
- Private saved data and its identifiers are excluded from this dossier. Original artwork provenance is documented in CREDITS.md and CHRONIQUES.md.

Player archive: `AzerothStats-1.6.0-dev.3.zip`

SHA-256: `84228b4faf7fb5978e4aaddcb0b6db341657735a0b9666057e2448a011180d6e`

Machine-readable evidence: `native.json`, `acceptance.json`, `runtime-policy.json`. An explicitly selected trusted local API fixture was used; its bytes are not distributed.

Source-derived previews use synthetic data and approximate compositing. The first implementation failed native border tiling and visual fidelity; it is not considered visually validated. This follow-up removes custom backdrop tiling and supplies painted materials, glyphs, landscapes and corrected geometry. All dev.3 artwork, mouse/slider/drag ordering, screen edges/scales and language layouts still need native verification. The client move-to-start prompt was seen over addon windows; no verified fix is claimed and native HUD elements are not hidden to disguise it. Follow docs/CHRONIQUES.md before public delivery.

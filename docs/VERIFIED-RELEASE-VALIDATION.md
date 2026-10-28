# Verified distribution validation — 1.6.0-beta.2

Recorded 28 October 2026. Runtime behavior matches 1.6.0-beta.1; Util.lua and the TOC only change the version string. Documentation and the package manifest are updated.

- tools/checks.py: PASS, 24 modules, 3,678 offline assertions, syntax/upvalues, TOC and manifest.
- Exact player ZIP: 74 verified files; no development tools or personal saves.
- Exact ZIP acceptance: PASS, 27 class/outcome cases, 81 fresh Lua 5.0.3 processes, 1,710 assertions. The game UI is simulated; no new native playthrough is claimed.
- Client SHA-256: de7147a2a3a01b4fb84f3a7f036bc940f9e7d4fdfc42a7fdb79f3f1b2bd798be
- Player ZIP SHA-256: a616623f5774b49fade260c4554d351e53fb1ae5026023f91223d36495e04c25

The maintainer reports game-team distribution approval; see APPROVAL-STATUS.md. Draft PR #5 is excluded. Historical reports remain evidence of their original revisions.

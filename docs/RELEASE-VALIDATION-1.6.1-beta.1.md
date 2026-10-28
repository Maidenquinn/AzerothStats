# Release validation — 1.6.1-beta.1

Recorded 28 October 2026. This beta consolidates journal/co-op/UX PRs #5, #7 and #8 after the maintainer's explicit in-game acceptance of dev.3 and release authorization. The release metadata/docs do not change that candidate's runtime behavior.

- Independent source/UI suite: PASS, 25 production modules, 4,270 assertions; TOC, syntax/upvalue limits and manifest checks.
- Full suite against the currently installed client: PASS, 4,900 Lua 5.1 assertions; native Lua 5.0.3 syntax/behavior/persistence passed with exit code 0. UI objects in those tests are simulated.
- Exact player ZIP: PASS, 75 files; 27 class/outcome cases, 81 fresh Lua 5.0.3 processes, 1,764 assertions. The archive contains no developer tools, tests, personal save or client executable.
- Client SHA-256: 08f8c58d6967b94598c56b822a1e6b323a52924a299a6df70ef6055ca839b8cd
- Audited helper extraction SHA-256 for this compatibility run: d5754185093894890f91c82bb71618548cdcbf1614b38af0912f75cd642423fd
- Player ZIP SHA-256: 1f4f208f962f120f7575b742ba5fe5c3ac0acbae70e5ac155267a60a3762e175
- Prior preview validation includes fifteen Python tests, fourteen-language glyph coverage, formatting/policy checks and inspected synthetic French/Japanese/max-text previews. CI repeats the source/catalog/font/package checks for this release PR and main.

The maintainer's acceptance is the native gameplay evidence; no exhaustive native playthrough matrix or independent security certification is asserted. Earlier validation dossiers remain dated evidence for their original revisions. See APPROVAL-STATUS.md and RELEASE-NOTES-1.6.1-beta.1.md for scope and API limitations.

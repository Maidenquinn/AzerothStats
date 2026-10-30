# Validation — 1.7.1-beta.1

Publication authorized by the maintainer on 30 October 2026. Scope: explain
summary-only HUD counts, retain the official values of the just-finished tracked
run, and provide matching navigation. No schema, collector, kill inference or
accounting changes. No V2 or unreleased theme implementation is included.

- Lua 5.1 offline suite: 5,094 assertions, 27 production modules; syntax/upvalues,
  TOC, localization and release manifest passed.
- Native Lua 5.0.3 behavior suite: 5,093 assertions passed (one runtime-dependent
  Heroic check differs from Lua 5.1). UI and persistence are simulated.
- New cases: missing live count, explicit availability explanation, final count,
  official zero, tracked-run navigation and no previous-count leakage.
- Fourteen-language catalogs are reproducible. Player ZIP uses the existing
  allowlist and excludes developer tools/tests and all player data.

This hotfix has not been validated in an actual game session. It does not claim
that bosses slain can be counted exactly during a run with the currently verified
sources. The official final summary supplies that count; missing units or boss
damage meters are not kill evidence.

Native smoke test: set Bosses slain / Current run in `/azstats hud`; during the
run expect At run end with the explanatory tooltip. Finish a run and check its
official boss count while that run remains attached, then start another run and
confirm that the old number does not appear. Check global totals remain unchanged.
Repeat with an official zero and with a missing final summary. Keep SavedVariables
when updating; no reset is required.

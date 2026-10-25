# Development and validation

Please keep changes scoped to Azeroth Stats. Never commit game executables, MPQ extracts, personal SavedVariables, `.sav` files, access tokens or local audit material. Do not invent production APIs; verify their behavior against the client.

## Offline checks (same entry point as CI)

Use Python 3.12+:

```sh
python -m pip install -r requirements-dev.txt
python tools/checks.py
```

This verifies Lua 5.1 syntax, the Lua 5.0 upvalue ceiling and avoided modern constructs, TOC references, release manifest, localized model/UI smoke behavior, default initialization and idempotent accounting. It does not emulate the actual game's packet parser or render the native client.

## Full validation with your own client

```sh
python AzerothStats/tests/validate.py --client "/path/to/AzerothSurvivors.exe" --lua50 "/path/to/lua50"
python AzerothStats/tests/release_acceptance.py --addon AzerothStats --client "/path/to/AzerothSurvivors.exe" --lua50 "/path/to/lua50" --report AzerothStats/tests/release-results.json
```

`--lua50` is optional for the first command. The second command requires native Lua 5.0.3 and launches a fresh process for each acceptance stage. Both extract the real Lua API from your own executable in read-only mode; extracted code is temporary/local and must never be committed. The executable format is specific to the audited client; extraction may fail after a client update.

An optional `--legacy-saved "/path/to/a/copy/of/AzerothStats.lua"` tests migration and preservation in an isolated runtime. Inspect any generated reports before sharing them.

## Manual beta checks

Install the release ZIP, check all nine pages, play a run, inspect observed ranks/jewelry and item tooltips, compare final counters to the official result, quit normally and reload. Repeat with another class, an abandonment and victory/continuation if possible. Check descriptions, preferences and totals survive without duplicate runs.

For changes, describe the issue, the resulting behavior and the validation performed. Preserve native Lua 5.0/interface 11200 conventions and all font/resource notices. Source archives from GitHub are developer checkouts; players should use the installable release asset.

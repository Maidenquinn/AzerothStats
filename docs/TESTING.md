# Reproducible validation

## Offline checks (no game files)

From the repository root, with Python 3.12+:

```sh
python -m pip install -r requirements-dev.txt
python tools/build_catalogs.py --check
python tools/build_insights_strings.py --check
python -m unittest discover -s tools -p "test_*.py"
python tools/security_review.py --report release-assets/runtime-policy.json
python tools/checks.py
python tools/build_release.py --output release-assets
```

The Lupa dependency is developer-only and pinned. Offline tests validate all twenty TOC modules, syntax/upvalue constraints, catalogs, assets, manifest, model/UI logic, favorites, persistence and hostile input boundaries. Policy tests exercise the static scanner itself. No runtime evaluation/OS library used by these tools is part of the player addon.

StyLua 2.6.0: `stylua --check AzerothStats`. CI downloads its official Linux archive and verifies a pinned SHA-256 before execution. Its Lua51 formatter syntax is not proof of Lua 5.0 compatibility.

After intentional player-file changes, run `python tools/update_manifest.py` before checks. Do not regenerate a manifest merely to hide unexpected byte drift. `build_release.py` uses the shared allowlist, verifies every manifest digest, writes a deterministic ZIP and rereads every member. Test files are excluded from that ZIP.

## Native contracts and Lua 5.0

Use only a trusted API fixture, preferably supplied by the game developers. These developer tools execute fixture Lua in a test VM; this is not a sandbox for untrusted downloads.

```sh
python AzerothStats/tests/validate.py --api /trusted/client-api.lua --lua50 /tools/lua50
python AzerothStats/tests/release_acceptance.py --api /trusted/client-api.lua --lua50 /tools/lua50 --addon /unpacked/AzerothStats --report release-assets/acceptance.json
```

Alternatively replace `--api` with `--client /path/to/AzerothSurvivors.exe`. That compatibility path reads the installed executable to locate the known embedded helper block; it never patches it. A changed marker fails and requires a new trusted fixture. Do not commit or distribute the extracted block.

`validate.py` can additionally read `--legacy-saved /private/AzerothStats.lua` to verify existing schema-1 data after supported migrations. Use a private backup/trusted local file; never publish its contents. The test records a digest and integrity result, not names or save contents. It does not overwrite the input.

The full native suite runs Lua 5.0.3, round-trips own SavedVariables and simulates all eleven pages/fourteen locales. The acceptance matrix runs nine classes × three outcomes × three stages, each in a fresh native process (81 processes / 27 cases). These are simulated clients, not in-game playthroughs. Point `--addon` at the **unpacked final ZIP** to check delivered files, while using harness files from the source repository.

## Real-client recipe (still required for this candidate)

Perform in a test profile/copy approved for review, with own SavedVariables backed up:

1. Install the exact reviewed ZIP and verify `1.5.1-review.1`; confirm no Lua error at startup and all pages open. Test default settings and an existing schema-1 backup separately.
2. Start a solo run; choose/upgrade spells and accessories; pause/resume; inspect totals, ranks, item hover and partial indicators. Opening one chest must not increase a supposed live opened count: wait for the official final summary.
3. Complete and lose separate runs; verify exactly one history entry per run, authoritative final counters and no stale previous-run data on reset. Test victory-to-endless handling where supported.
4. Restart normally midway/in a menu and after a terminal summary; check history/aggregates/favorites survive without duplication. A hard crash is not guaranteed to persist recent data.
5. In co-op, compare names and same-sample damage/DPS/share with the native display. Disconnect/rejoin and inspect retained/partial rows. Do not infer shared achievements.
6. Test a death with native explicit slain-by evidence and one without it. Confirm probable/confirmed remain distinct and no unsupported fatal source is fabricated.
7. Toggle hearts in all categories, reopen favorites, change class and lower retention. Protected run details must remain; removing protection allows ordinary pruning.
8. Test minimap/bar drag/lock/reset; scale/text sliders; opacity; sound toggle/test. Check screen edges and restart positions. Cycle fourteen languages and inspect fonts, truncation and tooltips visually.
9. Verify the player's other addons and game save files are unchanged. Review diagnostics before sharing, as names may appear in screenshots.

Record client version/hash, candidate source/archive hashes, steps and actual outcomes. A passing offline suite is not a substitute for this recipe or game-team approval.

## Source-review bundle

After committing the reviewed source and confirming a clean working tree:

```sh
python tools/build_review_bundle.py --output release-assets/approval-review
```

This archives the exact Git revision, without Git history, private inputs or ignored build outputs. It checks prohibited artifact types and writes the archive hash/revision alongside it. It does not publish or install anything.

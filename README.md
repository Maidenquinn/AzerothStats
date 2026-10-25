# Azeroth Stats

[![Checks](https://github.com/Maidenquinn/AzerothStats/actions/workflows/checks.yml/badge.svg)](https://github.com/Maidenquinn/AzerothStats/actions/workflows/checks.yml)

**Persistent run history and build statistics for Azeroth Survivors on Windows.**

Track your progress, revisit previous builds and inspect combat performance in a dark, gold-trimmed interface inspired by WoW.

**[Download the latest beta](https://github.com/Maidenquinn/AzerothStats/releases)** · [Report a bug](https://github.com/Maidenquinn/AzerothStats/issues/new/choose) · [Known limitations](docs/KNOWN-ISSUES.md)

## Public beta: 1.5.0-beta.1

This release adds **peak observed run-average DPS** (server damage / server time, sampled after 10 seconds), persistent class/global records and an optional native sound once per run when beating a previous class record. The first record seeds silently. Use `/azstats sound` to toggle and `/azstats sound test` to preview.

**Usage → Co-op** stores names/classes actually observed in fresh `AZSPARTY` samples and counts observed runs globally/per class. A victory count means your run was won and that name was seen during it; it does **not** prove shared completion or a shared achievement. Names are not stable account IDs. `/azstats coop` opens a per-run scoreboard with you and your teammates: damage, DPS, damage share and top spell where available. The run selector opens earlier games; All runs lists companions, whose rows open their retained game history. Rankings and team totals require one common group sample. Older independent records remain explicitly partial.

**Favorites** bookmark runs, spell views, collection equipment, run accessories and companions. Favorite runs survive history pruning; item descriptions remain available from captured data. **Nemesis** records observed deaths and recent combat-log evidence. A last attacker within two seconds is labeled probable; an explicit native slain-by message, if emitted, is labeled confirmed. No enemy-specific victory count is invented. See [the implementation and audit notes](docs/INSIGHTS.md). Favorites have separate History, Combat, Spells, Equipment, Jewelry and Co-op categories, with outlined/filled heart controls.

## Features

- Global and per-class dashboards, personal records and detailed run history.
- Damage, effective healing and damage-taken breakdowns, spell rankings and available rates.
- Current and historical runs, cumulative views where supported, and the last available boss fight.
- Recorded spell ranks, collection equipment, run jewelry and native item descriptions.
- Observed spell/accessory popularity, maximum ranks and rank gains; accessory variants grouped together.
- Compact top bar, minimap button, adjustable opacity, scale and font size, persistent preferences.
- **14 languages:** English, Polish, Czech, German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and Korean.

Standalone addon. No extra addon dependencies or external account. Data stays local.

## Install

1. Exit the game normally.
2. Download **[AzerothStats-1.5.0-beta.1.zip](https://github.com/Maidenquinn/AzerothStats/releases/download/v1.5.0-beta.1/AzerothStats-1.5.0-beta.1.zip)**. Use the attached addon ZIP rather than GitHub's automatically generated source archives.
3. Extract it into the `AddOns` directory used by your client.
4. Check that the final path is `AddOns/AzerothStats/AzerothStats.toc`, without a duplicate nested addon folder.
5. Restart the client, enable the addon if required and type **`/azstats`**. Verify version **1.5.0-beta.1** in the window.

If it does not appear in the addon list, check the directory used by the running client. A common portable layout is `<game folder>/benilla-config/AddOns/AzerothStats/AzerothStats.toc`. Avoid nesting the addon inside another `AzerothStats` or release/source folder.

**Updating:** back up the addon's SavedVariables, replace its addon files and keep the existing SavedVariables. Do not overwrite or import the game's `.sav` files.

If installing from a Git clone, copy the **inner `AzerothStats` directory** into `AddOns`. The test files inside it are not loaded by the TOC.

## Commands

- `/azstats`, `/azstats show`, `/azstats hide` — toggle/open/close the main window.
- `/azstats favorites` — open bookmarks; `/azstats favorite` toggles the selected/current run.
- `/azstats nemesis` — inspect observed deaths and attacker evidence.
- `/azstats coop` — compare your latest/current party; choose an earlier run from the selector.
- `/azstats history` — open run history.
- `/azstats diagnose` — open diagnostics and print diagnostic details in local chat.
- `/azstats bar`, `/azstats minimap`, `/azstats lock`, `/azstats resetpos` — control visibility and placement.
- `/azstats scale 0.9` — scale from `0.65` to `1.5`, subject to available screen space.
- `/azstats opacity 1` — background opacity from `0.45` to `1`.
- `/azstats lang auto` or `/azstats lang en` — language; codes: `en pl cs de pt es fr ro tr ru uk zh ja ko`.
- `/azstats class all` or `/azstats class rogue` — class filter.
- `/azstats retention 200` — retain 10–1,000 detailed runs; reducing this removes the oldest details.
- `/azstats help` — command summary.

Left-click the minimap button to open the window, right-click for Settings. Item and stat details are available on hover. Window scale and text-size sliders apply on release.

## What the numbers mean

Opened-chest counts come from the **final official summary**, not the price of the next chest. Usage tracks **observed builds, rank gains and accessory changes**, not exact card clicks or spell casts. The first observed rank is a baseline. Missing data stays unavailable rather than becoming a false zero.

Tracking depends on the packets the addon actually receives. Runs first observed in progress are partial. Save normally before exiting; crash recovery is not guaranteed. See [known limitations](docs/KNOWN-ISSUES.md).

## Beta status and validation

The current beta is **1.4.0-beta.1**, interface **11200**, Lua **5.0-compatible**. The first Discord attachment was renamed `AzerothStats-1.0.0-beta.zip`; its internal addon version and runtime code are the same as this beta.

The pre-publication suite passed **2,383 assertions** under native Lua 5.0.3 and Lua 5.1. Additional simulated acceptance covered **27 scenarios across nine classes**, with **1,359 assertions in 81 fresh Lua processes**, repeated from a clean extraction of the release ZIP. These are automated simulations using the real client Lua parser, not manually played games.

GitHub CI checks syntax, packaging, translations and offline model/UI behavior without requiring or distributing game files. Full packet-driven tests require your own client executable; see [development and validation](CONTRIBUTING.md).

## Repository layout

- `AzerothStats/` — installable addon, 16 production Lua modules, fonts and notices.
- `AzerothStats/tests/` — synthetic fixtures and local-client validation tools.
- `tools/checks.py` — offline CI checks.
- `docs/` — limitations, credits and testing notes.

No executable, MPQ assets, extracted client API, personal SavedVariables, `.sav` files or internal audit captures are included.

## Feedback and credits

For bugs, include the addon/client version, your class, reproduction steps, expected/actual result and relevant `/azstats diagnose` output. Check personal data before attaching logs or saves.

Developed by Kevin / Codex for Azeroth Survivors. See [credits and third-party notices](docs/CREDITS.md); bundled fonts retain their SIL Open Font License notices.

# Azeroth Stats - 1.6.0-dev.1

Development preview of the Chroniques native UI and configurable HUD for Azeroth Survivors Windows, interface 11200 / Lua 5.0. Manual game-team approval is pending. Automated tests do not authorize distribution or guarantee safety.

## Install an approved build

Close the client and back up the addon's SavedVariables. Extract to the AddOns directory actually used by the game: `AddOns/AzerothStats/AzerothStats.toc`, with no extra nested folder. Restart, type `/azstats` and check the version. Preserve `AzerothStatsDB` on update. Never edit the executable/game `.sav` files.

## Features and controls

Overview, classes, history, combat, character/builds, records, diagnostics, settings, usage/co-op, categorized heart favorites and Nemesis. Minimap left-click toggles the window; right-click opens Settings. Adjustable opacity/scale/text/retention, fourteen languages.

Open the configurable HUD editor with `/azstats hud` or `/azstats bar config`. Choose per-block scope and metrics, order, width/height, icons/labels, opacity and locking. Apply saves; Cancel discards. No run clock is shown by default. All existing totals remain accessible through All statistics.

Commands (after `/azstats`): `show`, `hide`, `history`, `coop`, `favorites`, `favorite`, `nemesis`, `diagnose`, `bar`, `minimap`, `lock`, `resetpos`, `scale 0.9`, `opacity 1`, `retention 200`, `lang auto`, `sound`, `sound test`, `help`.

Missing data stays unavailable. Chests require the official final summary; live chest value is a price. Usage counts builds/rank gains, not clicks/casts. DPS records are observed run averages after ten server seconds. Co-op rankings need a common native sample. Last attacker is probable unless explicitly confirmed. RSE1 import is excluded.

## Local data

The client persists the addon's schema-1 SavedVariables, normally at logout. Data can include names, timestamps, builds and death evidence. No automatic upload/outbound message or gameplay automation is implemented. History pruning does not erase cumulative data/protected favorites. Invalid saved trees disable collection and preserve input; close the game/back up that addon file before investigation. Never import untrusted Lua saves.

Full source, privacy/reviewer notes, tests and limits: https://github.com/Maidenquinn/AzerothStats (docs/REVIEWER-GUIDE.md). SHA256SUMS identifies bytes, not approval. See CREDITS.md for provenance.

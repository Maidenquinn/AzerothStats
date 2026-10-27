# Azeroth Stats 1.6.0-beta.1 — Chroniques, Heroic & Run Comparison

A new interface, a configurable stats bar, and a better way to revisit your runs.

**Beta prerelease — awaiting manual game-team approval.** This GitHub release does not claim approval under the game's addon policy. Follow the game's current rules when installing or testing.

## What's new

- **Chroniques interface:** illustrated Overview, grouped navigation, consistent layouts across all eleven destinations, readable combat columns, heart Favorites and fourteen languages.
- **Your stats bar:** choose up to eight metrics with independent global/class/current-run scopes, order, dimensions, opacity, text size, icons and labels. The independent editor previews changes; Apply saves and Cancel restores. No duplicate run timer by default.
- **Run reports:** open a recorded run to inspect totals, damage sources, spells/equipment, available co-op snapshots and class records identified at the official summary. A dismissible 30-second notice offers the report without forcing the window open.
- **Compare two runs:** select A and B, inspect signed/percentage differences, compare sources/ranks/equipment and swap the sides. Matching class/zone/known difficulty is suggested first; different context, identical runs and missing values are explicit. Each equipment column keeps its own historical tooltip.
- **Game 0.121 compatibility:** retain observed Normal/Heroic I-V and filter History by difficulty. Older runs without the field remain unknown. Lifetime aggregates still combine difficulties and are labeled accordingly.
- **Better native gear descriptions:** longer set/star tooltips and decimal bonuses are preserved. Ended runs no longer borrow current upgraded inventory through an identical item link. Reference fallbacks warn about upgrade/set differences; obsolete fixed drop percentages are no longer shown.
- **Zone identity and artwork:** twelve supplied zone photos use reviewed native framing. Recognized native labels and compatible observed continuity can recover missing live zone metadata; unknown zones remain neutral and are not guessed.

## Download and install

Download **AzerothStats-1.6.0-beta.1.zip** from this release's assets. The separate source-review archive is for reviewers, not player installation.

1. Close the game normally and back up the addon's own SavedVariables.
2. Extract the ZIP into the AddOns folder actually used by your client. Portable installations commonly use `<game>/benilla-config/AddOns`.
3. Confirm `AddOns/AzerothStats/AzerothStats.toc` exists, without an extra nested folder.
4. Preserve `AzerothStatsDB`, fully restart (font/assets changed), then open `/azstats` and verify **1.6.0-beta.1**.

## Quick commands

```text
/azstats          — Open or close the main window
/azstats history  — Browse retained runs
/azstats report   — Open the selected/current/latest run report
/azstats compare  — Compare two retained runs
/azstats hud      — Configure your stats bar
/azstats diagnose — Show diagnostics
/azstats help     — List commands
```

## Data definitions and beta limits

- Missing data is unavailable, not zero. Comparisons describe observed snapshots, not causal build effectiveness or an overall winner. A zero baseline has no percentage increase.
- Class milestones require a record baseline captured before a new run; older reports do not reconstruct broken records. Class/lifetime records span difficulties.
- Co-op statistics require exposed native samples; independent/incomplete samples stay partial. Resume remains heuristic without a server run UUID.
- Marks, weekly affixes and structured star/set progression were not found in the verified public API. Native tooltip text is preserved where available; no values are guessed from boss counts or calendar dates.
- The game's move-to-start foreground prompt can still draw over addon windows. New report/comparison interaction checks remain part of beta testing; automated tests are not native playthroughs.
- Local history/settings use the addon's own SavedVariables. The runtime does not send messages, download/evaluate code, automate gameplay, modify the executable/game saves, or import RSE1.

## Validation and review

The exact player ZIP is manifest-verified and tested in native Lua 5.0.3 with 27 class/outcome cases over 81 fresh processes. Source checks cover Lua syntax/upvalues, all locales, input boundaries, persistence, reports/comparisons, widget reuse, fonts and deterministic assets. The player archive excludes tests/development tools and personal data. SHA-256 files identify bytes, not safety or approval.

[Full changelog](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.0-beta.1/AzerothStats/CHANGELOG.md) · [Reviewer guide](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.0-beta.1/docs/REVIEWER-GUIDE.md) · [Validation evidence](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.0-beta.1/docs/chroniques-validation/RESULTS.md) · [Report an issue](https://github.com/Maidenquinn/AzerothStats/issues/new/choose)

For reports, include addon/client versions, class, reproduction steps, expected/actual behavior, a screenshot and `/azstats diagnose` output where relevant. Please do not post personal save files publicly.

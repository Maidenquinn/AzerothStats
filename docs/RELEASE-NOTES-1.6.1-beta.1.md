# Azeroth Stats 1.6.1-beta.1 — Co-op, Build Journal & UX

A clearer way to find your runs, review group performance and follow your build's progression.

## What's changed

- **Co-op context:** observed multiplayer runs are marked in History, recent-run context, selectors and reports. The displayed player count belongs to the last shared snapshot, not every player ever present.
- **Group reports:** available player damage/DPS, group totals, sample size, supported rankings/contributions and top-spell/source tooltips. `/azstats coop` opens the selected/current/latest run report. Independently captured or incomplete samples remain partial and do not produce invented team totals/ranks.
- **Observed Build journal:** timestamped rank/equipment changes and global-stat checkpoints, before/after values and category filters. Logging avoids ordinary stat fluctuations. Initial states are baselines, and partial/limited observations remain explicit. `/azstats journal` opens it.
- **Searchable History:** literal text search plus result, observed co-op and favorite filters alongside class/difficulty. Summary cards describe the filtered retained list. Reset clears filters; missing party evidence never labels a run solo.
- **Clearer navigation:** Usage becomes Trends; companion-history links lead to run reports. Run menus share identity/context. Combat/Character drilldowns keep the selected run.
- **More accurate labels:** official provenance is assigned per matching summary field; partial co-op headings stay neutral. Large DPS is compact on revised widgets with exact values on hover.
- **Safer history retention:** reductions that would remove details ask for confirmation showing the current removal count. Cancel keeps history/settings; changed impact requires confirmation again. Protected favorites, live run and cumulative ledgers stay protected.
- **Accessibility/localization:** improved body-text fitting, new labels in all fourteen languages and updated CJK glyph coverage.

## Download and update

Download **AzerothStats-1.6.1-beta.1.zip** from this release. The separate source-review archive is for reviewers, not installation.

1. Close the game normally and back up the addon's own SavedVariables.
2. Extract into the AddOns directory actually used by your client. The final path must be `AddOns/AzerothStats/AzerothStats.toc`, without an extra nested folder.
3. Keep your existing `AzerothStatsDB` history/settings. No reset is required.
4. Fully restart, open `/azstats` and verify **1.6.1-beta.1**.

## Useful commands

```text
/azstats          — Open or close the addon
/azstats history  — Find retained runs
/azstats report   — Inspect the selected/current/latest run
/azstats coop     — Open its co-op report
/azstats journal  — Open its observed build journal
/azstats compare  — Compare two retained runs
/azstats hud      — Customize your stats bar
/azstats diagnose — Show diagnostics
/azstats help     — Display command help
```

## Limits and review status

The journal is **not an exact card-pick log**: the audited public API does not expose accepted card identity, rarity or causal rolled bonuses. Global percentage-point changes are observations, not a card's exact effect. Old runs cannot be reconstructed. Co-op healing, kills, complete builds and full spell-by-spell breakdowns of other players remain unavailable. Shared snapshots do not establish equal participation time or an overall winner.

Search/result/kind/journal filters last for the session. Existing class/difficulty preferences remain persistent. Lua case folding is not accent-insensitive Unicode search. Very long labels may still clip at large text settings; native wording/layout feedback is welcome.

The project has permission to be posted as a verified addon. The maintainer validated dev.3 and authorized this update; no separate game-team re-review or exhaustive native test matrix is claimed. The runtime does not send chat/addon messages, download/evaluate code, automate gameplay, modify executable/game saves or import RSE1.

[Full changelog](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.1-beta.1/AzerothStats/CHANGELOG.md) · [Validation](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.1-beta.1/docs/RELEASE-VALIDATION-1.6.1-beta.1.md) · [Source and issues](https://github.com/Maidenquinn/AzerothStats)

For bugs, include addon/client versions, class, reproduction steps, expected/actual behavior and a screenshot or `/azstats diagnose` output. Please do not publish personal save files.

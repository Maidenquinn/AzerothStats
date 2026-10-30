# Azeroth Stats

Persistent run history and build statistics for **Azeroth Survivors on Windows**, using the client's Lua addon interface (11200 / Lua 5.0).

## Review status

**Approved for posting as a verified addon, as reported by the maintainer on 28 October 2026. The current release is 1.7.1-beta.1.** This is game-team distribution approval, not independent security certification or a promise that future updates are approved. It includes the Chroniques interface, configurable HUD, run reports/comparisons and verified 0.121 Heroic metadata. The earlier 1.5.1-review.1 audit is historical evidence, not certification or approval of this build.

[Download and release notes](https://github.com/Maidenquinn/AzerothStats/releases/tag/v1.7.1-beta.1) · [Reviewer guide](docs/REVIEWER-GUIDE.md) · [Validation evidence](docs/RELEASE-VALIDATION-1.7.1-beta.1.md)

The new native slate/bronze theme includes original generated artwork, a curated overview, grouped navigation and a configurable HUD. Use **`/azstats hud`** (also `/azstats bar config`) to choose up to eight metrics, per-block scope, order, dimensions, labels, icons, opacity and locking. Apply commits the draft; Cancel discards it. The native game timer is not repeated by default. Full totals remain available through **All statistics**.

Read [the UI implementation and test guide](docs/CHRONIQUES.md), [architecture](docs/ARCHITECTURE.md) and the earlier [security review](docs/SECURITY-REVIEW.md).

## Features

Azeroth Stats observes native counters during play and keeps local history after the next run starts. Its eleven pages provide:

- **Overview / Classes:** observed runs, time, kills, gold and available totals, globally or per class.
- **History:** retained runs with class/difficulty filters, run reports and side-by-side comparisons.
- **Combat:** damage, effective healing, damage taken, source rankings, contributions and available rates; selected runs, cumulative data and the last available boss meter.
- **Character:** recorded spells/ranks, collection equipment, temporary accessories, attributes and progression snapshots. Hover for captured native descriptions or clearly labeled collection references.
- **Records:** personal maxima, including peak observed run-average DPS.
- **Diagnostics / Settings:** availability and provenance, retention, language, scale, text size, opacity, positions and visibility.
- **Trends:** observed spell builds/rank gains, accessory families and cooperative companions. Per-run co-op details open in the run report.
- **Favorites:** History, Combat, Spells, Equipment, Jewelry and Co-op categories with heart controls. Bookmarked runs survive ordinary history pruning.
- **Nemesis:** observed deaths and available attacker evidence, with probable and confirmed attribution kept separate.

The compact top bar and minimap button open the same interface. No additional addon, external account or launcher service is required.

## Meaning and limits of the numbers

Missing values stay unavailable. They are not silently converted into zero. Totals describe available samples, not a guaranteed complete lifetime record.

**Chests:** opened-chest counts use the official terminal summary. The live `Chest` display is a price and is never treated as the number opened. Old incorrect chest data is corrected by a one-time migration where supporting data exists.

**Trends:** counts observed builds, rank increases and accessory changes. It does not measure exact card clicks or spell casts. The first observed rank establishes a baseline. Accessory tiers II/III/IV are grouped into a family, with class-aware spell aliases where possible.

**DPS records:** maximum observed `AZS_RUN.dealt / AZS_RUN.t` after ten server seconds in valid playing/endless samples. This is run-average DPS, not instantaneous burst DPS. The first class record seeds silently; an optional native sound can announce a later record once per run.

**Co-op:** names/classes and damage/DPS/share/top spell come from fresh native party samples when exposed. A leaderboard/team total requires a common group sample; independently captured rows remain partial. A victory associated with a companion means that name was observed during a run you won. It does not establish shared completion or shared achievements. Names are not stable account identities.

**Nemesis:** an explicit native slain-by message can confirm a source. A recent last attacker alone is probable, not proof of the fatal hit. There is no invented enemy-specific victory count.

See [known limitations](docs/KNOWN-ISSUES.md) and [insight definitions](docs/INSIGHTS.md).

## Installation and updates

Use a build approved under the game's current rules. For a reviewed player ZIP:

1. Close the client normally and back up the addon's own SavedVariables.
2. Extract the ZIP into the **AddOns directory actually used by that client**.
3. Verify the final path is `AddOns/AzerothStats/AzerothStats.toc`, without an extra nested directory.
4. Restart, enable the addon if required and type `/azstats`. Verify the displayed version matches the chosen build.

A portable layout may use `<game>/benilla-config/AddOns`. Installation does not require editing the executable or the game's `.sav` files. Replace addon source files on update while preserving `AzerothStatsDB`. The player ZIP excludes developer tests and tools. GitHub's automatic source archive is intended for source review; the inner `AzerothStats` folder contains the runtime.

If a saved tree is malformed or from an unsupported schema, collection is disabled and the original root is preserved. Close the game, copy the addon's SavedVariables for recovery, then investigate. Details are in [Privacy](docs/PRIVACY.md).

## Commands and controls

- `/azstats`, `/azstats show`, `/azstats hide`: toggle, open or close the window.
- `/azstats history`, `/azstats coop`, `/azstats favorites`, `/azstats nemesis`: open the relevant page.
- `/azstats favorite`: toggle the selected/current run bookmark.
- `/azstats diagnose`: open Diagnostics and print availability information to **your local chat display**.
- `/azstats hud` or `/azstats bar config`: open the HUD editor.
- `/azstats bar`, `/azstats minimap`, `/azstats lock`, `/azstats resetpos`: visibility and positioning.
- `/azstats scale 0.9`: window scale, clamped to 0.65–1.5 and available screen space.
- `/azstats opacity 1`: background opacity, 0.45–1. Text size is adjustable in Settings.
- `/azstats retention 200`: retain 10–1,000 ordinary detailed runs, plus protected favorites. Reducing retention removes old details; cumulative statistics remain.
- `/azstats class all` or `/azstats class rogue`: class filter.
- `/azstats sound`, `/azstats sound test`: toggle or preview the record sound.
- `/azstats lang auto` or `/azstats lang en`: automatic or manual language.
- `/azstats journal`: open the selected/current/latest run’s observed build journal.
- `/azstats help`: command summary.

Minimap left-click toggles the window; right-click opens Settings. Scale/text sliders apply on release. The window/bar can be moved when unlocked. Hover rows for details and use the heart to bookmark supported entries.

Languages: English, Polish, Czech, German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and Korean. Codes: `en pl cs de pt es fr ro tr ru uk zh ja ko`. Translation coverage is tested; native-speaker wording review is still welcome.

## Data and capabilities

Only `AzerothStatsDB` is declared as SavedVariables (schema 1). The client handles disk serialization, normally at logout. The addon reads fixed native `AZS_*` tables/helpers, inventory tooltips and relevant combat/lifecycle events. It creates its own frames, local chat output and optional sound. It does not send chat/addon messages, download code, evaluate packet strings, change game settings/bindings, cast abilities, equip items or implement gameplay automation. These statements describe the reviewed runtime source; they are not a security guarantee about the host client or other addons.

Names, timestamps, builds and death evidence can be personal data even when stored locally. No automatic export/upload exists. Read [Privacy](docs/PRIVACY.md) before sharing diagnostics, screenshots or saved data.

The game API lacks an authenticated run UUID and stable companion account IDs. Freshness and resume detection therefore use conservative local heuristics. Bounds and partial markers limit new data growth; favorites and cumulative data have their own limits. See [Architecture](docs/ARCHITECTURE.md).

**RSE1 save import is excluded.** There is no dormant executable importer. A future import would require a separate, reviewed parser and explicit user action.

## Build, test and audit

Python tools run on a developer machine, never inside the player addon:

```sh
python -m pip install -r requirements-dev.txt
python tools/build_catalogs.py --check
python tools/build_theme_assets.py --check
python tools/check_fonts.py
python tools/build_insights_strings.py --check
python -m unittest discover -s tools -p "test_*.py"
python tools/security_review.py --report release-assets/runtime-policy.json
python tools/checks.py
python tools/build_release.py --output release-assets
```

The build checks an explicit player-file allowlist and SHA-256 manifest. Formatting uses StyLua 2.6.0 with the committed configuration; actual Lua 5.0 tests remain necessary because Lua51 formatter mode does not prove 5.0 compatibility. [Testing](docs/TESTING.md) explains native fixtures, fresh-process acceptance, existing-save checks and the remaining in-game recipe.

## Contributing and ownership

Read [CONTRIBUTING](CONTRIBUTING.md), [data provenance](docs/DATA-PROVENANCE.md), [credits](AzerothStats/CREDITS.md) and [security reporting](SECURITY.md). Reference metadata may become stale and must not override observed native values. This audit does not establish permission to redistribute game-derived catalogs; that remains a question for the game team. Bundled fonts retain their OFL notices. No new blanket license grant is made by this review.

Maintained by Kevin / Maidenhead. Existing Kevin / Codex development credit is retained. [Source repository](https://github.com/Maidenquinn/AzerothStats). See [approval status](docs/APPROVAL-STATUS.md) for the scope and provenance of approval.

## Game update 0.121

Observed Normal/Heroic I-V is retained per run and filterable in History. Older/missing difficulty remains unknown; lifetime records combine difficulties. Native item tooltips preserve long set/star descriptions and decimal bonuses; reference fallbacks may differ from the historical upgrade level. Fixed legacy drop percentages are no longer shown. Marks, affixes and structured stars are unavailable unless a verified native API exposes them; no save import or gameplay action was added.

## Run reports and comparisons

History now contains History, Run report and Compare runs. Click a retained run, recent run or run Favorite to inspect its report. Use `/azstats report` for the selected/current/latest run and `/azstats compare` to select two retained runs. The comparison initially prefers the same class, zone and known difficulty; either selector can choose a different retained run, and Swap runs reverses B minus A. Missing data stays unavailable, and no percentage is inferred from a zero baseline.

Reports include native/observed totals, damage sources, recorded build/equipment, available group snapshots and class records identified at the native summary. Those class records combine difficulties and require a baseline captured before that run; older reports do not reconstruct milestones. A dismissible notice appears once for 30 seconds after an accepted native summary. It never forces the window open.

## Build journal and clearer run navigation

`/azstats journal` opens timestamped observed ranks, equipment and global-stat checkpoints. Filter by category and hover for before/after values. Initial state is a baseline; the journal does not identify exact chosen cards, rarity or causal card bonuses. Global statistics are sampled at build/choice checkpoints rather than every fluctuation. Existing runs are not reconstructed. See [BUILD-JOURNAL.md](docs/BUILD-JOURNAL.md).

History offers bounded literal search plus result, observed co-op and favorite filters alongside class/difficulty. Its cards describe the filtered retained list. Reset clears these filters. Missing party evidence does not mean solo. Run selectors share identity/context; `/azstats coop` and companion-history links open the selected/current/latest run report.

Official/sample provenance is assigned per metric. Retention reductions that would remove detailed runs require explicit confirmation showing the current removal count. Cancel preserves data/settings; cumulative statistics, protected favorites and the live run remain protected. Search/result/kind/journal filters are session-only. See [UX behavior and test recipe](docs/UX-COHERENCE.md).

## HUD editor hotfix

1.6.2-beta.1 fixes My bar becoming hidden behind the main window after dropdown interaction. Editor menus now belong to the editor, ordering is refreshed and refocusing preserves an open draft. The maintainer confirmed the fix locally; feedback from the original reporter is still requested. See [hotfix details](docs/HUD-EDITOR-LAYERING.md).

## Edit pages and manage local data

Use **Edit page** on a data page, then the **...** menu on a row or card. Hide/Show is reversible and does not change totals. Restore hidden rows restores the current page/context.

Records (including featured survival/DPS/kills cards), Nemesis and Trends offer targeted entry resets with explicit confirmation. These apply to the selected entry across **all classes**, between runs. Other entries, lifetime sums and historical combat/build snapshots remain. Favorites and retained history offer individual removal under the existing protection rules. Combat, character and calculated rows offer hiding instead of silently rewriting their inputs.

Settings > Manage local data or `/azstats data` opens the bulk manager: one run, class/global retained history, individual categories or full reset. Its illustrated run recap and separate deleted/kept summary explain the scope before confirmation. Full reset retains settings and requires the exact RESET token plus an explicit ready phase. No data is deleted by installation or simply opening a page.

See [exact cleanup scopes and acceptance recipe](docs/DATA-MANAGEMENT.md). The maintainer reported the development candidate working in game and authorized this beta; broader testing is welcome.

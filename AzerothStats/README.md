# Azeroth Stats - 2.0.0-dev.11

V2 development candidate, not a stable release. Six main routes preserve the V1
features: Overview, My runs, Analyze run, My progress, Favorites and Nemesis.
Settings and Diagnostics remain available. Five themes and all existing HUD,
editing, hiding, restoration and guarded deletion controls are retained.

V2 adds 29 build attributes with separate native equipment contributions,
measured progression points/comparisons, raw Heroic affix IDs, observed boss
encounters/shared meter snapshots, support attempts, optional summons/effects,
local run notes and personal objectives. Optional presence collection is off by
default; enable it through Optional analyses. Notes are under Analyze run →
Details → Your note. Objectives are under My progress → Personal objectives.
The goal editor accepts your own name and target, with metric/class/zone/difficulty
scopes (including all classes/zones/difficulties). Goals use completed retained
history, not native unlocks; levels use a best rather than a sum. Native Nemesis
portraits use an exact static appearance catalog; missing/ambiguous names keep a
neutral icon. Preparation context does not create an accounted run.

The common database stays schema 1, with V2 data in a separate versioned
namespace. One normal installation can be replaced by V1 or V2 between game
sessions; never enable both copies. Offline roundtrips pass with V1 1.6.2,
1.7.0 and 1.7.1, including new common runs and serialized extension data.
Native client persistence still requires acceptance testing.

Advanced observations retain up to 32 enriched runs. When full, the oldest
unprotected completed observations expire; the common run, totals and local note
remain. Favorite run references protect advanced observations too. If all slots
are protected, collection reports a limit instead of silently removing them.
Each run has at most 32 attribute samples, 120 combat progression points,
16 observed encounters, 12 shared boss samples, 40 support events and 24 types
per presence category. Local notes (500 UTF-8 bytes) remain with retained runs;
up to 12 personal objectives count matching victories in retained history only.
Truncation, expiry and unavailable data are labelled explicitly.

A disappearing boss is not a confirmed kill. Shared boss meters are not
attributed to a single enemy. Return to combat does not prove a successful
revive. Presence maxima are samples, not casts or exact uptime. Raw affix IDs
are not assigned guessed meanings. Marks and structured star progression remain
unavailable. The public V1 release remains 1.7.1-beta.1.


Chroniques native UI, run reports/comparisons, co-op reports, observed build journal and configurable HUD for Azeroth Survivors Windows, interface 11200 / Lua 5.0. The HUD-layering fix was validated locally by the maintainer; behavior on the originally affected player’s client still needs confirmation. The project has game-team permission to be posted as a verified addon; no separate game-team review of this update is claimed. Automated tests are not a safety guarantee.

## Install an approved build

Close the client and back up the addon's SavedVariables. Extract to the AddOns directory actually used by the game: `AddOns/AzerothStats/AzerothStats.toc`, with no extra nested folder. Restart, type `/azstats` and check the version. Preserve `AzerothStatsDB` on update. Never edit the executable/game `.sav` files.

## Features and controls

Overview, classes, history, combat, character/builds, records, diagnostics, settings, Trends/co-op, categorized heart favorites and Nemesis. Minimap left-click toggles the window; right-click opens Settings. Adjustable opacity/scale/text/retention, fourteen languages.

Open the configurable HUD editor with `/azstats hud` or `/azstats bar config`. Choose per-block scope and metrics, order, width/height, icons/labels, opacity and locking. Apply saves; Cancel discards. No run clock is shown by default. All existing totals remain accessible through All statistics.

Commands (after `/azstats`): `show`, `hide`, `history`, `report`, `compare`, `journal`, `coop`, `favorites`, `favorite`, `nemesis`, `diagnose`, `bar`, `minimap`, `lock`, `resetpos`, `scale 0.9`, `opacity 1`, `retention 200`, `lang auto`, `sound`, `sound test`, `help`.

Missing data stays unavailable. Chests require the official final summary; live chest value is a price. Trends counts builds/rank gains, not clicks/casts. DPS records are observed run averages after ten server seconds. Co-op rankings need a common native sample. Last attacker is probable unless explicitly confirmed. RSE1 import is excluded.

## Local data

The client persists the addon's schema-1 SavedVariables, normally at logout. Data can include names, timestamps, builds and death evidence. No automatic upload/outbound message or gameplay automation is implemented. History pruning does not erase cumulative data/protected favorites. Invalid saved trees disable collection and preserve input; close the game/back up that addon file before investigation. Never import untrusted Lua saves.

Full source, privacy/reviewer notes, tests and limits: https://github.com/Maidenquinn/AzerothStats (docs/REVIEWER-GUIDE.md). SHA256SUMS identifies bytes, not approval. See CREDITS.md for provenance.

## Game update 0.121

Observed Normal/Heroic I-V is retained per run and filterable in History. Older/missing difficulty remains unknown; lifetime records combine difficulties. Native item tooltips preserve long set/star descriptions and decimal bonuses; reference fallbacks may differ from the historical upgrade level. Fixed legacy drop percentages are no longer shown. Marks and structured stars are unavailable unless a verified native API exposes them; native affix strings are retained as raw IDs; no save import or gameplay action was added.

## Run reports and comparisons

History now contains History, Run report and Compare runs. Click a retained run, recent run or run Favorite to inspect its report. Use `/azstats report` for the selected/current/latest run and `/azstats compare` to select two retained runs. The comparison initially prefers the same class, zone and known difficulty; either selector can choose a different retained run, and Swap runs reverses B minus A. Missing data stays unavailable, and no percentage is inferred from a zero baseline.

Reports include native/observed totals, damage sources, recorded build/equipment, available group snapshots and class records identified at the native summary. Those class records combine difficulties and require a baseline captured before that run; older reports do not reconstruct milestones. A dismissible notice appears once for 30 seconds after an accepted native summary. It never forces the window open.

## Sampled build journal

Open a run report's Build journal section or type `/azstats journal`. The new journal keeps observed rank changes, global stat before/after values and periodic inventory changes. Hover for the complete observation. It does not identify the exact selected card, rarity or rolled bonus; global percentage-point changes are not causal card effects. Missing/batched/late/limited data remains explicit, and older runs are not reconstructed. Journals survive normal own-SavedVariables restarts and ordinary retained-run/favorite rules.

## History and navigation

This release adds per-metric source labels, confirmed history pruning, literal History search and result/co-op/favorite filters, a central co-op report route, Trends, and filtered build checkpoints. `/azstats coop` opens the selected/current/latest run report. Global journal changes remain observations rather than exact card choices. Search and journal-category filters last for this session. Reducing retention asks for confirmation before removing detailed runs; cancel keeps the previous settings and history.

## Manage local data

Open Settings > Manage local data or `/azstats data`. Deleting one run or clearing retained history (all classes or one class) keeps lifetime statistics/records unchanged and protects active/bookmarked sources. A separate full reset deletes all statistics, history and favorites while preserving settings; it requires the native ready phase and typing RESET. Cancel keeps data. There is no undo: back up the addon's own SavedVariables first if you intend to erase data. The `reset` slash alias only opens the dialog and never performs an immediate reset.

The preview also offers independent Nemesis, Records, Trends and Favorites cleanup
for all classes, between runs. Its right-hand recap identifies the run being inspected.
Category cleanup keeps numeric combat results, build snapshots and co-op comparisons,
but clears the selected category and its historical death/milestone/usage details.
Cleared categories collect again from new runs; older retained runs cannot restore them.
Favorites cleanup unpins retained sources without deleting those runs.

## Edit individual entries

Use Edit page on a data page, then the small menu on the row/card. Hide/Show is
reversible and preserves totals; Restore hidden rows reveals the current page again.
Records (including the top cards), Nemesis and Trends also offer a targeted reset
with explicit confirmation. These resets affect that entry across all classes, between
runs, preserving other entries and raw historical results. Favorites can be removed
individually; retained runs can be deleted under the existing protection rules.
Combat/character/calculated rows offer hiding rather than silently rewriting statistics.

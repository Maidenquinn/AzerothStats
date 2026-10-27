# Chroniques native UI preview — 1.6.0-dev.1

This implements the approved visual direction using native Lua 5.0/11200 frames. It is a development preview, not a public release or game-team approval. The AI concept board is a design reference, not a screenshot or a runtime texture.

## Implemented

- Shared slate/bronze palette, original geometric compass seal, glyph atlas, grain and native backdrop edge; coherent selected/hover states and grouped navigation.
- Overview prioritizes four totals, three recent retained runs with hearts and three records. **All statistics** restores the full original totals/coverage view; no metric or accounting ledger is removed.
- All eleven existing destinations remain accessible. Historical selection, combat breakdowns, co-op, favorites and Nemesis keep their previous data semantics.
- A HUD of up to eight blocks: metric, global/current-class/fixed-class/current-run scope, order, width (240–1600), height (28–96), font size, icons, labels, opacity and independent position lock.
- Per-block scopes and exact/partial provenance are available in tooltips. Missing values remain unavailable; levels/DPS records are maxima rather than sums. The game timer is not repeated by any default preset; current-run duration is an explicit optional block.
- One/two-row screen-bounded layout with explicit overflow and full-value tooltips; repeated sampling reuses widgets.
- An isolated editor draft with live preview, Apply/Cancel, add/remove/up/down controls and Discreet / My class / My journey presets. No statistics are changed by editing or resetting a preset.
- Twenty-two new labels in fourteen languages. CJK derivatives retain their existing glyphs and add required UI characters, with derivative font naming and OFL notices preserved.

## Open and use

`/azstats hud` or `/azstats bar config` opens the editor. It is also available through Settings → Customize bar and the HUD gear/right-click. `/azstats bar` still toggles visibility. `/azstats resetpos` restores owned positions without resetting counters. Left-click a HUD segment to open its matching local view/class scope.

Apply saves normalized preferences to `AzerothStatsDB.settings.hud`, version 1. Cancel/close/Escape discards the draft. Existing database schema 1, totals, migration markers, visibility and anchors remain compatible. A global position lock also prevents HUD dragging. The HUD has no independent network or filesystem behavior.

## Source boundaries

`Theme.lua` contains shared visual tokens/atlas selection. `Bar.lua` owns normalization, metric/scope/value/layout models and local navigation. `BarUI.lua` owns HUD/editor widgets and trusted callbacks, using constructors exposed by `UI.lua`. No modern WoW API, external helper, CVar, binding change or gameplay action is introduced.

`tools/build_theme_assets.py` reproduces four original TGA textures without image inputs. `tools/check_fonts.py` checks all localized UI glyphs and can rebuild CJK derivatives from explicitly supplied hash-pinned original fonts described by `data/font-sources.json`. Developer Pillow/fontTools dependencies are not included in the player archive.

The exact player package has **41 files including SHA256SUMS.txt**: 23 Lua modules, TOC, three user documents and thirteen media/license files. Design files, Python, tests and JSON recipe/catalog sources are excluded.

## Validation and manual test recipe

Run the documented offline/native suites, plus `python tools/build_theme_assets.py --check` and `python tools/check_fonts.py`. `tests/bar.lua` covers defaults, corrupt settings, scope/value separation, source availability, maxima, overflow, navigation, draft cancellation/application, actual editor callbacks, locales and widget reuse. Previous accounting, migration and persistence suites remain required.

Before considering a public release, verify in the actual client:

1. Restart normally after installing the exact development ZIP and check version **1.6.0-dev.1**. Preserve/back up own SavedVariables first.
2. Open all pages and All statistics; inspect selected/hover states, row spacing, hearts and item tooltips. Verify both fresh and existing databases.
3. In the HUD editor, add global runs, class wins, fixed-class kills, observed lifetime duration and current-run damage. Check each tooltip and navigation target. No current-run duration appears unless explicitly chosen.
4. Change dimensions through minimum/maximum values; test narrow-screen overflow, tall/two-row layout, label/icon toggles, fonts and opacity. Check both live HUD and preview.
5. Reorder/remove, Cancel and reopen: stored settings must be unchanged. Apply, restart and verify persistence. Presets must not clear history.
6. Test global/individual locks, drag and reset positions. Test editing while the main window is scaled. Existing game timer must remain untouched.
7. Inspect all fourteen languages, especially long labels, Cyrillic/CJK glyphs and native scroll-arrow controls.

Offline widget renders use synthetic data and approximate native rendering; they do not prove in-game texture, event ordering, sound or font behavior. Older approval/audit records remain historical evidence, not certification of these changes.

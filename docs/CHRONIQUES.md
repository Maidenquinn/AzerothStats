# Chroniques native UI preview — 1.6.0-dev.5

This implements the approved visual direction using native Lua 5.0/11200 frames. It is a development preview, not a public release or game-team approval. The AI concept board is a design reference, not a screenshot or a runtime texture.

## Implemented

- Shared slate/bronze palette, original painted compass/glyphs, illustrated zone thumbnails and sculpted material plates; coherent selected/hover states and grouped navigation.
- Overview uses a taller 960 × 780 layout, a player profile, four contiguous metric cards with centered illustrated icons/ivory values, three recent retained runs with decorative landscapes/hearts and three records. **All statistics** restores the full original totals/coverage view; no metric or accounting ledger is removed.
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

`tools/build_theme_assets.py` reproduces four geometric textures. `tools/encode_painted_assets.py` slices the original source PNGs into sixteen separate glyphs, four decorative landscape strips and four material plates; every runtime TGA has a maximum edge of 256 pixels. The four 1024-square dev.3 atlases failed to display after a confirmed full game restart. Their exact rejection mechanism is not established; this conservative component packaging follows the dimensions/depth of prior textures that rendered. It is not a claim that the client universally rejects 1024-pixel files.

Materials use nine explicit slices and dimensions, with small separate plates on large windows as well as controls. No custom native backdrop tiling or full-window stretched ornament is used. Large windows retain the quiet slate background. The compact 520-unit HUD editor collapses unused rows; controls remain transactional. While it is open, the actual HUD previews the draft at readable native size. Cancel/close restores its stored layout and prior visibility; presets do not write settings until Apply. The miniature keeps the requested proportions. Decorative landscape strips are illustrations, not captured gameplay or evidence; unmapped zones use a generic forest.

The existing `AzerothSerif.ttf` filename now contains a renamed Noto Serif Bold derivative. `data/title-font-source.json` pins the original official source commit and hash; `tools/build_title_font.py` verifies a maintainer-supplied original, preserves notices and deterministically renames it. `tools/check_fonts.py` verifies localized coverage and the bold face. CJK derivatives remain separate with their existing glyphs/notices. Developer tools are excluded from the player archive.

The exact player package has **65 files including SHA256SUMS.txt**: 23 Lua modules, TOC, three user documents and thirty-seven media/license files. Development tools, source PNGs, tests, recipe/catalog JSON and retired atlases are excluded.

## Validation and manual test recipe

Run the documented offline/native suites, plus `python tools/build_theme_assets.py --check`, `python tools/encode_painted_assets.py --check` and `python tools/check_fonts.py`. `tests/bar.lua` covers defaults, corrupt settings, scope/value separation, source availability, maxima, overflow, navigation, draft cancellation/application, actual editor callbacks, locales and widget reuse. Previous accounting, migration and persistence suites remain required.

Before considering a public release, verify in the actual client:

1. Restart normally after installing the exact development ZIP and check version **1.6.0-dev.5**. Preserve/back up own SavedVariables first.
2. Open all pages and All statistics; inspect selected/hover states, row spacing, hearts and item tooltips. Verify both fresh and existing databases.
3. In the HUD editor, add global runs, class wins, fixed-class kills, observed lifetime duration and current-run damage. Check each tooltip and navigation target. No current-run duration appears unless explicitly chosen.
4. Change dimensions through minimum/maximum values; test narrow-screen overflow, tall/two-row layout, label/icon toggles, fonts and opacity. Check both live HUD and preview.
5. Reorder/remove, Cancel and reopen: stored settings must be unchanged. Apply, restart and verify persistence. Presets must not clear history.
6. Test global/individual locks, drag and reset positions. Test editing while the main window is scaled. Existing game timer must remain untouched.
7. Inspect all fourteen languages, especially long labels, Cyrillic/CJK glyphs and native scroll-arrow controls.

Offline widget renders use synthetic data and approximate native rendering; they do not prove in-game texture, event ordering, sound or font behavior. Older approval/audit records remain historical evidence, not certification of these changes.

## Fidelity and native verification

Dev.1 did not reproduce the approved visual direction faithfully. The custom backdrop strip also repeated gold strokes in the client. Dev.2 removed native tiling; dev.3 adds actual painted materials and more faithful proportions/composition. Source-derived previews are explicitly labeled offline and use synthetic data. They approximate frame/font compositing and do not validate the native renderer. The game’s move-to-start foreground prompt was observed over addon windows; higher frame levels are not evidence of a fix. No native UI is hidden or changed to disguise that issue. Dev.3 also failed native image loading despite a full restart. Dev.4 replaces those images with small components and adjusts typography/geometry; user screenshots now confirm its image loading. Full visual fidelity and the dev.5 independent editor interactions still need review before public delivery.

## Editor positioning

Dev.5 gives My bar an independent UIParent anchor and scale. Drag only its title/header to move it; the close button and content controls are excluded. Its validated saved position is settings.barEditorPos, separate from windowPos/barPos. The global position lock applies; the HUD-specific lock still concerns the HUD. The editor keeps the current UI scale while preserving physical offsets, and resetpos recenters it. Moving the main window no longer moves this editor; closing the main window still closes/cancels the editor. The dev.4 user screenshots confirm the small images render; full visual fidelity and native foreground hints are not thereby certified.

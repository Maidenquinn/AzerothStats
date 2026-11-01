## Azeroth Stats V2 preview — 2.0.0-dev.13

Local data editing follow-up on the 2.0.0-dev.12 performance preview. Schema 1 history and settings stay intact.

### Highlights
- **Reset this total** on Overview lifetime counters, including cumulative kills (player request)
- Clears global and class sums without deleting retained runs; `sumResets` blocks late re-accounting
- Overview edit mode keeps the dashboard cards instead of stripping the layout
- Edit chrome spacing: Restore / Done and `…` menus are no longer flush against each other or frame edges

### Install
Close the game. Extract **AzerothStats-2.0.0-dev.13.zip** into your active AddOns folder so it contains `AddOns/AzerothStats/AzerothStats.toc`. Keep `AzerothStatsDB` and fully restart. Use the player ZIP below, not GitHub's Source code ZIP.

### Validation
7,481 Lua offline assertions, TOC/manifest/package policy checks. Maintainer validated Overview total reset and edit-button spacing in-game after `/reload`. Not every live edge case is claimed as acceptance.

### Limits
Unavailable native fields stay unavailable. Summary-only current-run HUD values may still say At run end until the official summary. The native move-to-begin overlay is outside this addon.

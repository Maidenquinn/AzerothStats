## Azeroth Stats V2 preview — 2.0.0-dev.11

First public V2 candidate. Schema 1 history and settings are preserved; V2 observations live in a bounded extension with V1 roundtrip compatibility.

### Highlights
- Six main routes: Overview, My runs, Analyze, Progression, Favorites, Nemesis
- Measured progression charts, illustrated run chooser, custom goals and local notes
- Advanced attributes with equipment contributions; 201 Nemesis portraits
- Co-op support observations and encounter samples without inventing kills/revives
- Five visual themes; session `/azstats overlay` controls; optional AZS_SetOnTopOfScreens
- Per-page edit/hide and Manage local data retained from 1.7.x

### Install
Close the game. Extract **AzerothStats-2.0.0-dev.11.zip** into your active AddOns folder so it contains `AddOns/AzerothStats/AzerothStats.toc`. Keep `AzerothStatsDB` and fully restart. Use the player ZIP below, not GitHub's Source code ZIP.

### Validation
7,418 Lua offline assertions (including V2 suites), TOC/manifest/package policy checks. Native acceptance for every live edge case is not claimed; this remains a development preview.

### Limits
Unavailable native fields stay unavailable. Summary-only current-run HUD values may still say At run end until the official summary. The native move-to-begin overlay is outside this addon.

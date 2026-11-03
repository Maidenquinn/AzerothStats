## Azeroth Stats V2 preview — 2.0.0-dev.12

Performance hotfix for the live 1 Hz sampler while keeping V2 preview features and schema 1 history.

### Highlights
- Removes severe in-combat freezes reported with Stats alone and with FieldKit + Hub
- Keeps kills/gold/damage, meters, build journal, jewelry, equipment tooltips, V2 observations and official summaries
- Staggered equipment tooltip capture with end-of-run flush; stamp-aware meter and spell freshness
- Safer V2 writes on large SavedVariables (~10 MB histories)

### Install
Close the game. Extract **AzerothStats-2.0.0-dev.12.zip** into your active AddOns folder so it contains `AddOns/AzerothStats/AzerothStats.toc`. Keep `AzerothStatsDB` and fully restart. Use the player ZIP below, not GitHub's Source code ZIP.

### Validation
7,432 Lua offline assertions (including PERF DATA INTEGRITY), TOC/manifest/package policy checks. Native freeze recovery confirmed by the maintainer with the three-addon stack. Not every live edge case is claimed as acceptance.

### Limits
Unavailable native fields stay unavailable. Summary-only current-run HUD values may still say At run end until the official summary. The native move-to-begin overlay is outside this addon.

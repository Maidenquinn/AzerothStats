# Azeroth Stats 2.0.0 — First full V2 release

Azeroth Stats 2.0.0 consolidates changes delivered since **2.0.0-dev.12** into one installable release. Existing local statistics, saved data and V1 accounting are preserved while V2 history, navigation, personal tracking and data safety are expanded.

## Home screen, history and navigation
- Clear **Overview** and **All statistics** tabs with active-view highlighting and consistent navigation.
- Revised dashboard, recent runs and personal objectives; Edit page and Restore hidden rows controls repositioned at the lower right.
- **My runs** history: direct Back navigation from Compare runs, retained pagination, and combined local filtering by map, date, level, kills, gold and survival duration.
- Collapsible advanced filters, min/max numerical input and paired sliders, map filter alongside difficulty, date calendar buttons, input validation and reset.
- More readable Settings, backup manager, and other crowded screens.

## Data editing and protection
- **Reset this total** on lifetime Overview counters without deleting retained runs. Accounting fences prevent late run events from automatically repopulating intentionally reset values.
- Ledger-aware run deletion adjusts attributable totals and invalidates affected records. Retention-pruned history cannot be recreated by resync.
- A validated independent safety backup precedes destructive local operations; failed backups block deletion.
- **Backup now**, append-only manual backup history and a rotating record of up to 15 automatic safety snapshots.
- Paginated manager for selecting, inspecting, restoring or deleting an individual snapshot with confirmations. Previously stored single-slot backups migrate into the history.
- Backup/restore/resync chat commands; UI reload after completed backup/restore operations.

## Combat Intelligence and newer client support
- Passive detection of supported native capabilities with graceful fallbacks.
- Optional **Combat Intelligence**, disabled by default: bounded collection of observed outgoing hit/miss combat-text events, crits, periodic hits, sources, quality and loss diagnostics.
- Current-run diagnostics, partial per-run checkpoints and a dedicated Combat Intelligence report.
- Native meters and V1 accounting remain authoritative; these combat observations are partial and are **not** an exhaustive damage/healing meter.
- No automatic external upload or gameplay automation.

## Reliability
- No intentional database migration: common schema-1 saved history and V2 extension are retained.
- Fixed date-picker callback errors and adapted the Lua UI to optional methods in test mocks.
- Automated Lua regressions, data-integrity tests, packaging and SHA-256 verification.

## Install or update
1. Fully close the game and back up your existing AzerothStats SavedVariables.
2. Download **AzerothStats-2.0.0.zip** from the release assets — not GitHub's automatically generated Source code ZIP.
3. Extract into your active `Interface/AddOns/` folder, resulting in `Interface/AddOns/AzerothStats/AzerothStats.toc`.
4. Restart the game. Do not delete `AzerothStatsDB` if you want to keep your statistics.

## Known limits
- Native **“Move to begin” / “BOUGEZ POUR COMMENCER”** text may still draw over the addon. This issue is not claimed as resolved.
- Optional Combat Intelligence is experimental, opt-in and partial. Native API availability varies.
- Some co-op, encounter and combat values are unavailable from the game; Azeroth Stats will not invent them.
- Retained history cannot recover runs removed before backup or pruning.

**Previous milestone:** [v2.0.0-dev.12](https://github.com/Maidenquinn/AzerothStats/releases/tag/v2.0.0-dev.12).
# Reviewer guide — 1.7.0-beta.1

The player package has **27 runtime Lua modules and 77 files including its manifest**. The maintainer reported successful in-game testing of 1.7.0-dev.5 and authorized this release. See [approval status](APPROVAL-STATUS.md) for the recorded distribution permission; no separate game-team review of every update or independent certification is claimed.

## Suggested review order

1. `AzerothStats.toc` lists the complete executable surface. `tools/security_review.py` inventories that surface and verifies literal-only generated data modules.
2. `Core.lua` owns event registration, bounded periodic sampling, slash commands and local initialization. Notifications indicate freshness; packet strings are never evaluated.
3. `Safety.lua` and `API.lua` define native/saved-data contracts, finite numeric checks, tree/map budgets and read-only helper boundaries.
4. `Tracker.lua`, `Database.lua`, `Migrations.lua` implement lifecycle, idempotent deltas, retention and compatibility repairs. Historical snapshots are incomplete and are not subtracted to guess lifetime totals.
5. `Insights.lua`, `Usage.lua`, `Favorites.lua`, `Nemesis.lua`, `BuildJournal.lua` define observed rates, comparable party samples, canonical build keys, bookmarks, confidence attribution and sampled checkpoints. The journal does not identify exact native card clicks.
6. `DataManagement.lua` defines bulk plans and guarded confirmation. `Editing.lua` defines reversible visibility preferences and key-level reset plans. Read [exact scopes and reset barriers](DATA-MANAGEMENT.md), `tests/data_management.lua` and `tests/editing.lua` together.
7. `Reports.lua`, `Items.lua`, `Views.lua`, `UI.lua`, `Theme.lua`, `Bar.lua`, `BarUI.lua` implement local presentation, tooltip reading and UI configuration. `SetInventoryItem` reads a tooltip; it does not equip gear.
8. Inspect catalog/font/media provenance and `SHA256SUMS.txt`, then reproduce [tests](TESTING.md) and the disposable-profile native recipe.

## Data-removal contracts

Hiding a line only writes bounded presentation preferences. Combat/character/calculated rows are not rewritten to make a line disappear. Targeted record/Nemesis/Trends resets explicitly affect that entry across all classes, between runs; unrelated entries and historical numeric combat/build/co-op snapshots remain. Validated per-run masks prevent older observations from restoring cleared entries. New runs collect normally.

History deletion preserves cumulative ledgers and active/bookmarked run sources. Removing favorites releases retention protection without deleting the run immediately. Full reset preserves settings/migration markers/monotonic IDs and requires the exact RESET token plus an explicit native ready phase. Every destructive path has local review; changed impact requires fresh confirmation. There is no runtime undo or save import.

## Runtime effects and artifact separation

The addon owns its namespace, SavedVariables, slash commands and frames. It reads native data/inventory tooltips, updates its own database/UI, writes local chat output and optionally plays a fixed built-in sound. It does not transmit chat/addon messages, download/evaluate code, automate gameplay or modify the executable/game saves.

The player ZIP excludes Python tools, test Lua, JSON source catalogs, client extracts, executables, personal saves, screenshots and audit inputs. The source-review archive contains reproducible development tools/tests/docs. Dependencies are development-only. SHA-256 proves byte identity, not approval or safety.

## Evidence and limits

[Release validation](RELEASE-VALIDATION-1.7.0-beta.1.md) separates maintainer-reported native acceptance from automated tests. Offline widgets and fresh Lua 5.0.3 processes verify logic/language/persistence, not every native compositor or focus behavior. Development erasure tests use synthetic in-memory databases only.

[Security findings](SECURITY-REVIEW.md) and [the original review dossier](review/RESULTS.md) remain historical evidence for their stated revisions. Their hashes do not certify this release. Native API/catalog/asset permission and later review requirements remain subject to the game team's rules; a trusted team-supplied API fixture is preferable to local executable extraction.

# Current release — 1.6.1-beta.1

25 runtime modules and a 75-file player ZIP including its manifest. New sampled BuildJournal.lua and co-op/UX changes are documented in BUILD-JOURNAL.md, COOP-RUNS.md and UX-COHERENCE.md. The maintainer validated dev.3 in game and authorized this release; separate game-team re-review is not asserted. See APPROVAL-STATUS.md and RELEASE-VALIDATION-1.6.1-beta.1.md. Older dossiers below describe their original revisions.

> Current public distribution status: see APPROVAL-STATUS.md. This branch contains development changes awaiting native validation.

# Development addendum — 1.6.1-dev.1

BuildJournal.lua is a twenty-fifth module for sampled build observations. See BUILD-JOURNAL.md for read-only client evidence and the explicit distinction from exact native card selection. Review fixed-field validation/caps, Tracker ordering/freshness, the bounded AZS notification, optional SavedVariables validation and tests/journal.lua. No new native call/event, UI interception or outgoing command is introduced. The published 1.6.0-beta.1 dossier below is historical evidence for this development branch, not certification of the new module.

# Current UI preview addendum - 1.6.0-beta.1

The guide below records the earlier 1.5.1 review candidate. Current code additionally loads Theme.lua, Bar.lua and BarUI.lua (24 modules total), with twenty-four original Chroniques textures and twelve maintainer-supplied zone photos and updated CJK derivatives. The player ZIP has 74 files including its manifest. Read CHRONIQUES.md and the new draft-editor tests; prior audit/source hashes do not certify the new source. Game-team approval remains pending.

Dev.7 adds read-only, exact-catalog native zone fallbacks and live metadata continuity; inspect the new API-CONTRACTS.md section, Tracker.lua and multilingual scenarios. The remaining changes are presentation geometry and explicit UTF-8-safe control filtering.

Dev.8 adds the verified AZS_ZONE.heroic reader, optional bounded saved run metadata, History-only filtering and 64-line tooltip capture. CLIENT-0.121.md records installed-client evidence and unsupported progression data. No additional native write or event registration is introduced.

Dev.9 adds Reports.lua: read-only presentation over own retained runs, optional pre-run record baselines/summary milestones and a local dismissible report notice. Review it with the Items.lua active-versus-ended tooltip guard, UI.lua selectors, Safety.lua optional metadata validation and tests/reports.lua. No new native API or registered event is introduced.

# Reviewer guide: 1.5.1-review.1

## Purpose and status

This candidate is prepared for manual review following a change in addon approval policy. There are no written rejection criteria available to the maintainer. This dossier does not claim the previous removal was caused by a demonstrated exploit, or that the fixes guarantee approval.

## Suggested review order

1. Read `AzerothStats.toc`: the complete executable surface is twenty Lua modules. `tools/security_review.py` inventories this exact surface and checks five data modules are literal-only.
2. Read `Core.lua`: eleven events, one sampler (at most once per rendered update after one elapsed second), slash commands and local widget initialization.
3. Read `Safety.lua` and `API.lua`: external data contracts, saved-tree validation and native helper boundaries. Inputs may be stale or malformed.
4. Read `Tracker.lua`, `Database.lua`, `Migrations.lua`: lifecycle, ledger deltas, retention and compatibility repairs.
5. Read `Insights.lua`, `Usage.lua`, `Favorites.lua`, `Nemesis.lua`: definitions, bounded maps, group-sample comparability and confidence attribution.
6. Read `Items.lua`, `Views.lua`, `UI.lua`: native tooltip use, page models and display effects. `SetInventoryItem` here reads a tooltip; it does not equip an item.
7. Inspect catalogs, fonts/notices and the exact package manifest. Reproduce [tests](TESTING.md) and the in-game recipe.

Named logic functions have purpose/contract comments. Module headers explain their roles. Comments aid reading; they are not evidence in place of code/tests.

## Runtime effects

The addon owns the `AzerothStats` namespace, `AzerothStatsDB`, slash-command registration and named frames. It subscribes to events without replacing the game's handlers. It reads native data and inventory tooltips; writes its database, own UI and local chat output; optionally plays a fixed built-in sound. No outbound chat/addon message or gameplay command is used. Event notifications mark freshness rather than evaluating executable strings.

## Artifact separation

The player ZIP contains twenty runtime Lua files, TOC, three user documents, nine fixed media/license files and `SHA256SUMS.txt`: 34 files including the manifest. It excludes Python tools, test Lua, JSON source catalogs, client extracts, executables, personal saves, screenshots and audit inputs. The source-review bundle includes the tools/tests/docs needed to reproduce it. Development dependencies are not runtime dependencies.

SHA-256 establishes byte identity only. It does not certify safety or authorize distribution.

## Evidence and unresolved decisions

Read [SECURITY-REVIEW](SECURITY-REVIEW.md) for findings and [TESTING](TESTING.md) for commands. Automated widgets simulate the client; their assertions do not constitute a real game playthrough. Native Lua 5.0 verifies language compatibility, not the host widget implementation.

The candidate's recorded results and machine-readable evidence are in [review/RESULTS.md](review/RESULTS.md).

The game team should confirm: permitted event/counter/tooltip use; approval rules for local co-op/death history; whether game-derived names/catalogs may be bundled; whether the package/font assets are acceptable; and the approval process for later changes. A trusted fixture supplied by the team is preferable to the optional read-only local executable compatibility check.

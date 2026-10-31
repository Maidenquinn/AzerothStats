# Architecture and junior developer walkthrough

## V2 branch additions

The common schema-1 ledger and all V1 modules remain authoritative. `V2Data`
validates a separate plain-data namespace and owns transactional writes, bounded
retention and per-observation removal. `V2Observe` consumes verified native
packet notifications; `V2Views` builds read-only models and centralizes units;
`V2Personal` owns local notes/goals; `V2UI` reuses 11200 widgets for navigation,
point plots and independent dialogs. They load before Core initializes the addon.
See [V2 status](../design/v2/RUNTIME-STATUS.md) for limits and remaining gates.

## Load order and responsibilities

The TOC is executable load order. Modules extend one `AzerothStats` table; no loader/download mechanism is used.

1. `Util` provides finite numbers, bounded copy/signatures and formatting. `Theme` defines reusable visual tokens and original atlas references. `Safety` defines contracts and saved-tree checks.
2. `Strings`, `GameText`, `Icons`, `Locale` provide static labels, icon references and language selection.
3. `Database` owns schema-1 storage and ledger deltas; `API` translates native values into validated snapshots.
4. `Collection`, `Items`, `Usage`, `Migrations` provide reference data, captured descriptions, build observations and old-data repairs. Functions may be declared before dependencies because initialization happens in `Core`, after all modules load.
5. `InsightsStrings`, `Insights`, `Favorites`, `Nemesis` add labels, DPS/co-op observations, bookmarks and death evidence.
6. `BuildJournal` keeps bounded, non-causal sampled rank/global-stat/inventory observations. `Reports` creates bounded pre-run record baselines, summary milestones and comparison/report models without changing ledgers. `Tracker` turns snapshots into run state. `Bar` normalizes per-block HUD preferences and reads counters without changing accounting. `Views` builds page models. `UI` renders them; `BarUI` owns the separate draft HUD editor and renderer. `Core` registers events/commands and drives the sampler.

Read a function's contract comment, then its callers with `rg 'FunctionName' AzerothStats`. `A` means the addon namespace. A *run* is one local observation record; a *ledger* is the portion already added to lifetime totals. A *gate* remembers old signatures/update stamps at a boundary.

## Data flow and trust

Native globals/events → bounded adapters → run snapshots/ledger → own SavedVariables → view models → own widgets. Packet bodies are never executed. Game data is not authenticated identity or trusted markup. Fixed native function names come from source tables, never a payload-selected method name.

The client loads SavedVariables before initialization. `InitDB` validates the plain-data tree first, then applies repairs/defaults. Invalid trees preserve the original global and prevent collection. This does not prevent the client's initial execution of a malicious save file.

## Run lifecycle

`Core` samples about once per second and at logout. `Tracker` recognizes ready, playing, choosing, paused, levelup, dead, victory and endless. A ready/reset boundary establishes gates; stale counters cannot simply become a new game's first sample. Character/map, counter progress, signatures and stamps decide whether to resume or create a local sequence ID. Joining late marks the run partial.

A terminal official summary outranks an older live packet. A late fresh summary may enrich a retained run. Deltas use a per-run ledger so repeated samples/reloads do not add the same contribution again. Regressions, missing summaries and ambiguous boundaries are handled conservatively; local IDs are not authenticated server IDs.

`A.Sign` is a bounded structural change detector, not a cryptographic identity or freshness proof. `A.Copy` strips unsupported objects and caps depth/children/nodes. Input/admission limits must remain visible as partial data.

## Persistence and growth

Schema remains 1. `version` identifies the addon that last initialized the database. Ordinary detailed retention is 10–1,000 (default 200). Favorites protect up to 200 runs; up to 300 entries are permitted. Lifetime/class aggregates survive ordinary detail pruning.

New source maps admit up to 1,024 keys, usage maps 512, meter samples 256 rows, party samples 32 rows and copies 8,192 nodes. Saved-tree validation allows depth 32 / four million nodes: a defensive ceiling, not a target size. Build snapshots/timelines have additional bounds in their modules. Keep old migration markers: removing a repair because current data is clean breaks upgrades from older betas.

Favorites protect records through a temporary run-ID set. View indexes are temporary, not another persistent database copy.

## Presentation

`Views` describes cards/rows/actions; `UI` binds models to frames. Lua 5.0/11200 callbacks use legacy `event`, `arg1` and `this`. Do not replace these mechanically with modern WoW signatures.

`Items` reads live inventory tooltips or replays saved descriptions. Known collection references may supplement a match, clearly labeled; rounded bonuses do not replace exact native stats. Tooltip reads do not equip gear. Only reviewed item links enter native parsers.

## Future changes

Keep collection, definitions, persistence and rendering separate. New counters need availability/provenance and bounds before a UI number. RSE1 import stays excluded: a future parser should produce a versioned plain-data DTO, validate schema, require explicit action and use idempotent import tracking. No unused importer hook remains in this runtime.

The V2 summary composition is separated from collection: `V2Summary.lua` builds
read-only home/report models and reversible section identities. `V2SummaryUI.lua`
positions reusable owned panels; the shared bounded graph pool is reused rather
than allocating frames per refresh. Ready identity is transient, with no run ID,
ledger write or synthetic chart. Notes are edited in an independent input dialog
and saved only through the bounded `V2SetNote` transaction.

## Native screen overlay registration (V2 dev.9)

`UI.lua:RegisterScreenOverlay` calls optional `AZS_SetOnTopOfScreens(name, true)`
for eleven fixed, named Stats roots while effectively visible. Visibility of
ancestors is checked too; closing a root unregisters it. UI actions and the
existing one-second sampler reconcile registrations with no repeated writes
when visibility stays unchanged. The client
owns the separate level-up/treasure rendering and routes clicks to registered
roots and descendants. Normal frame strata still order our windows/menus.
The registration is session-only and does not alter saved statistics. Missing or
throwing APIs fall back to normal strata. UIParent, shared GameTooltip, minimap
buttons, preview roots and third-party frames are excluded.

Evidence: local Azerloot/core/Azerloot.lua BuildTracker uses this API for the
Souhaits/Wishlist panel; extracted client API contract in
fieldkit-audit/client-20261031/embedded-api.lua, lines 412–446, confirms global
names and descendant rendering. AZSSpellMeter itself uses conventional HIGH
strata and is not the panel identified in the supplied screenshot.

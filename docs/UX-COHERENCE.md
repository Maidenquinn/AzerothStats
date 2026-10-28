> Release update, 28 October 2026: the maintainer validated dev.3 and authorized 1.6.1-beta.1. The development-state wording below records the original implementation/testing stage. See RELEASE-NOTES-1.6.1-beta.1.md for current behavior and limits.

# UX coherence review branch — 1.6.1-dev.3

Branch: codex/ux-coherence-review. Based on the unmerged co-op/journal previews. No merge or public release is authorized by creating this candidate. Public verified 1.6.0-beta.2 remains unchanged.

## Changes and contracts

- A report metric is official only when its corresponding finite summary field equals the displayed value. Absent values stay unavailable; non-summary counters remain sampled. This changes presentation, not accounting.
- Reducing retention asks for confirmation only if details would actually be removed. The removal count mirrors Trim, excluding protected favorites and the live run. Opening/cancelling does not change retention or delete data; changed impact requires another confirmation. Pending confirmation is memory-only. Escape or closing cancels. Lifetime totals are untouched.
- History search is bounded to 80 UTF-8 bytes and uses literal Lua string matching, not patterns or code. It searches translated run identity/context and hero names. Case folding is limited to Lua's string.lower; accent-insensitive Unicode search is not claimed. Class/difficulty, result and co-op/favorite filters compose. No evidence is never classified as solo. Search/result/kind/journal filters are session-only; existing class/difficulty persistence is preserved. Reset clears the History filters and shared class/difficulty filter explicitly.
- Menus share zone/result/duration labels and date/class/difficulty/co-op detail. Run IDs remain the navigation authority. Co-op commands and companion histories lead to the central report; Trends retains cumulative build/accessory/companion discovery. Detailed Combat/Character drilldowns preserve selected run IDs. Existing lower-level views remain compatible.
- Build journal ranks and equipment remain direct observations. Global stats are sampled at baseline, rank/gear changes or an observed exit from choosing/levelup. A two-second window accepts late fresh stats packets at the same checkpoint. This is batching, not causal attribution to a card; temporary buffs can still appear at a checkpoint, and late packets outside that window are not reconstructed. Entry/field caps and partial/truncated indicators remain. Category filtering does not modify observations.
- Body row labels respect user text size when fitting. Fixed chrome and decorative titles still have separate sizing. Long unwrapped labels can be clipped at large settings; exact/source values remain available in tooltips. This is not a guarantee of perfect native layout.
- Large DPS values use compact presentation in the revised report/co-op widgets, with exact values on hover. Independent party samples use a neutral heading; unsupported peer metrics stay unavailable.

## Native acceptance recipe

1. Close/restart with the candidate ZIP and verify 1.6.1-dev.3. Keep the existing own SavedVariables.
2. History: search a zone or hero, combine result/co-op/favorites with class/difficulty, then reset. Confirm summary cards describe the filtered retained list and no unknown-mode run is called solo.
3. Open a run report, inspect metric provenance, use Combat/Character drilldowns, and check the selected run stays the same. `/azstats coop` must open that run's Co-op report. Companion trends must lead to a report when selecting a retained run.
4. Journal: filter ranks/stats/equipment. During gameplay, ordinary stat fluctuations should not fill the log continuously. Rank changes/choice exits/gear observations remain checkpoints, not claimed card choices.
5. Retention: with enough ordinary runs, choose a lower value. Inspect the removal count, cancel and confirm nothing changes. Only apply a reduction on a disposable backed-up own database if you intend to delete those details. A normal test need not confirm deletion.
6. Test French plus one long/CJK language, text sizes 11 and 16, and a smaller game window. Check menus, search focus/Escape, modal blocking, font glyphs, footer spacing and long tooltips. Opening the candidate is not a release approval.

No new game-data API, external messaging, game-save import or gameplay action is added. The runtime uses existing read-only counters and addon-owned widgets/data. Python developer tools remain excluded from the player ZIP.

## Validation recorded 28 October 2026

- 4,270 assertions in the independent offline suite, including 199 targeted UX checks.
- Full behavioral/syntax suite also passed in native Lua 5.0.3; UI objects remain simulated.
- Exact player ZIP: 75 files, 27 class/outcome cases, 81 fresh processes, 1,764 assertions.
- Fifteen Python tests; all fourteen locale glyph sets; formatting and package/runtime policy checks passed.
- Synthetic French/Japanese History, French confirmation/report and maximum body-text previews inspected. These are offline widget renders, not game screenshots.
- Player ZIP SHA-256: 1ec306ce2a79c3b15513d789febddb6dd3e7f111b9c535245575c98189520b06

Native edit-box focus/typing, the confirmation overlay and the revised navigation still require the user's in-game recipe above before approval. No native gameplay result is asserted.

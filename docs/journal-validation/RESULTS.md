# Sampled journal validation — 1.6.1-dev.1

Recorded 2026-10-28. This is a development preview, not a public release or game-team approval.

- Full fixture suite: 4,457 Lua 5.1 assertions; 4,456 native Lua 5.0.3 assertions. Own SavedVariables persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: 3,827 overlapping assertions. Fifteen Python unit tests; source policy, formatters, catalogs and fourteen-language glyph coverage pass.
- Exact player ZIP: 27 class/outcome cases, 81 fresh native processes, 1,764 assertions. Includes native-parser rank observations and journal/last-state persistence.
- Twenty-five runtime modules. Seventy-five ZIP members including the manifest; no developer tools, private data or client extracts.
- Journal tests cover baselines versus changes, global before/after values and percentage-point semantics, cooldown noise, missing data, combined rank gains, existing periodic equipment, reload deduplication, late join/freshness gates, malformed/metatable/non-sequence data, caps, locales and unchanged accounting.
- A synthetic French widget preview was inspected. Native gameplay/tooltip/click behavior still needs the recipe in TESTING.md; this is not proof of an exact card history.

Player ZIP: `AzerothStats-1.6.1-dev.1.zip`

SHA-256: `84fb0858c830addaa82ad09ccf3da3e1aff52ac4ce9efe8f913a00b3e17d83ae`

Client/API provenance and native prototype results are in native.json. User data/counts/input hashes are excluded. BUILD-JOURNAL.md records the inspected surface and why card IDs, rarity, rolled bonuses, rerolls and causal attribution are not inferred.

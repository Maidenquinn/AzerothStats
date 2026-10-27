# Chroniques development preview validation

Version: **1.6.0-dev.9**. Recorded 2026-10-27. Automated maintainer checks and simulated clients; game-team approval remains pending.

- Complete suite: **4,308 assertions in Lua 5.1/Lupa and 4,307 in native Lua 5.0.3**; persistence and existing schema-1 compatibility checked in memory.
- Client-independent suite: **3,678 assertions**, overlapping the full suite.
- Exact player ZIP: **27 class/outcome cases**, **81 fresh Lua 5.0 processes**, **1,710 assertions**, including summary baseline/notice deduplication, Heroic/filter fields and settings across independent restarts. These are simulated scenarios, not in-game playthroughs.
- **15 Python unit tests**. All packaged TGAs are RGBA, power-of-two and at most 256 pixels per edge. Source hashes, zone mapping and UV framing checked.
- Twenty-four TOC modules, native syntax/upvalue limits, formatters, runtime policy and the 73-file payload allowlist checked. Manifest makes **74 ZIP members**.
- All fourteen locale key sets/glyph coverage checked. Report/comparison tests cover every new subsection in every language, independent equipment tooltip cells, signed deltas/zero baselines, missing sources, compatible/mismatched/identical/pruned selections, class baselines, summary milestones/serialization, notice expiration and unchanged ledgers/widget counts.
- Existing zone/UTF-8, Heroic continuity, adversarial data, co-op, favorites and independent HUD editor suites remain included.
- Private saved data and identifiers are excluded from this dossier.

Player archive: `AzerothStats-1.6.0-dev.9.zip`

SHA-256: `35f6bdb05ed0074805e58350746fda995513fc68677c529e24194fa18baf37be`

Machine-readable evidence: native.json, acceptance.json, runtime-policy.json. Tests used the newly installed client read-only; no extracted client API is distributed.

**Native visual evidence:** user screenshots confirmed small Chroniques components and supplied zone photos in earlier previews; the user confirmed dev.8 works. This does not certify the new report/comparison hit areas or typography. Synthetic French/Japanese report/comparison previews were visually inspected and are labeled offline. Dev.9 native interaction and upgraded-gear historical tooltip checks remain pending; follow TESTING.md. The native move-to-start prompt can still draw over addon windows.

**Limits:** no server UUID; run resume/freshness is heuristic. Comparison matches class, zone and known difficulty only, not equivalent co-op/build conditions. No overall winner or causal effectiveness score is computed. Missing baselines on older runs do not reconstruct historical records. The report notice requires an accepted official summary. Structured marks/affix/star data is not invented; see CLIENT-0.121.md.

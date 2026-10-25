# Known limitations

- This is a Windows Azeroth Survivors beta for interface 11200, not a claim of compatibility with arbitrary WoW clients.
- There is no universal server run UUID. Resuming after reload is explicitly heuristic.
- Persistence depends on normal client saves. A crash or forced shutdown can lose recent observations.
- Exact opened-chest counts are available with the official final summary. The next-chest price is not a count.
- No exact card-click/cast/hit/crit/miss/overheal counters are invented from damage, cooldowns or observed rank changes.
- Boss data covers the last available boss fight; it is not an exhaustive cumulative boss history.
- Tracking cannot reconstruct packets missed before the addon loaded. Usage tracking begins with 1.3.
- Accessory variants are deduplicated per retained run. Already-pruned historical details cannot be reliably deduplicated during migration; previous aggregates are preserved for audit.
- Recorded item descriptions retain their capture language. A fallback from a newer static collection-item description is labeled as a current reference, not an exact historical snapshot.
- Loot chances are base catalog references, not a promise of a character-modified effective chance or proof that the character owns an item.
- The game's native Move to begin overlay can appear above addon windows.
- Full in-client rendering across all languages, resolutions and long multiclasse playthroughs has not been exhaustively validated by the agent. Automated acceptance remains simulated.
- No RSE1 import is included.

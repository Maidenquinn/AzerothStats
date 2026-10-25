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

## Features introduced in 1.5

Peak DPS is the highest **observed run-average sample** after 10 server seconds, not instantaneous burst DPS or a reconstructed historical maximum. Peak rates are never added over time or across runs. A group DPS total uses only rates from one common native group sample. Counter regressions are ignored for peaks. Record sounds use the client's own level-up sound and respect its audio settings; audio playback still requires a client check.

Co-op history begins when these features are loaded. It is keyed by observed name/class, not stable IDs; renames and homonyms cannot be resolved. A name is counted once per observed run, even if it leaves/rejoins. Victory counts describe your own run outcomes for runs in which that name was seen, not proof that the peer stayed until the finish. Old runs are not retroactively populated. Up to 64 names per run and 1,024 per aggregate group are retained; hitting these bounds is marked partial.

Nemesis keeps confirmed, probable and unknown evidence separate. A last attacker within two seconds is only probable; confirmation requires an explicit native slain-by message, if the client emits it. Reloading on a dead screen does not backfill a death. No per-enemy victory count or shared achievements are invented.

Co-op peer healing/kills are not exposed. Legacy independent samples do not receive a group rank, total or share. A retained group snapshot is not a guaranteed official final scoreboard.

Favorites are limited to 300 bookmarks and 200 distinct protected runs, including historical combat references. Old combat shortcuts without a recorded run ID retain their global scope; the original run cannot be reconstructed. Item-only bookmarks retain captured tooltip data but do not independently pin an entire source run.

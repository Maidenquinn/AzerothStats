# Observed DPS records and co-op history (1.5 development)

## API audit

The currently installed client exposes `AZS_PARTY`, `AZS_PARTY_UPDATED`, the `AZSPARTY` packet and `AZS_GetPartyMeter()`. The embedded parser's row fields are `name,class,dmg,dps,share,top,topdps`; its comment specifies that the table is empty outside a party. The addon consumes the raw parsed rows and does not infer group membership from nearby units or chat messages.

The verified final summary contains result, time, level, kills, damage, damage taken, gold, chests, magnets, class/race/zone metadata and aggregate boss/elite/guardian counters. No verified fatal attacker or shared-achievement field was found. Existing local Death Recap code likewise labels the last received damage as insufficient proof of the killing blow. Nemesis remains diagnosed as unavailable.

`PlaySoundFile` is a native binding in the local client UI source. The native asset `Sound/interface/LevelUp.wav` is present in the local MPQ extraction. It is referenced, not copied into the addon. The client controls sound availability/volume.

## DPS definition and notification policy

For a valid playing/endless sample with `AZS_RUN.t >= 10`, use `AZS_RUN.dealt / AZS_RUN.t`. These two values come from the same server sample, so the result does not mix an interpolated local helper clock with an older damage counter. Pause, choice, terminal states and counter regressions do not create peaks. Keep the exact source pair that established the maximum.

Store a per-run maximum under `values.peakDps`, with class/global records through the existing accounting ledger. `peakDps` has coverage and a maximum, never an additive sum. It is the peak of sampled run averages, not an instantaneous DPS peak or a historical maximum reconstructed from old snapshots. Tracking starts with this development version.

A run freezes the previous class record as its baseline. The first-ever observation seeds silently. Beating an existing baseline can emit one local chat notice and one native sound **at most once per run**, while higher subsequent samples still improve the record. The notification flag is persisted before playing sound, preventing replay on reload. Muting sound does not disable tracking. Settings and `/azstats sound [test]` control playback.

## Co-op definition and persistence

On run start/resume, snapshot the party-table signature, update stamp and local packet generation. Wait for a fresh sample before observing peers. Exclude the player's own name, retain received names/classes, and keep the latest party damage/DPS as a separate snapshot, never adding it to the player's meter.

A peer is counted once per observed run, globally and for the player's class, using a saved per-run ledger. Empty rosters clear the latest snapshot while retaining historical presence. Rejoins, reloads, duplicate summaries and endless continuation cannot increment the same presence twice. A victory is associated with a run containing that observation; it is not an assertion of shared achievement or final roster membership.

Names are local data; no account ID or rename resolution is available. Storage is bounded (32 rows per sample, 64 observed peers per run, 1,024 per aggregate group) and truncation is flagged. No old run receives invented companions or DPS peaks.

## Validation

`tests/insights.lua` executes actual client-parser packets for initial spikes, repeated samples, record sounds/muting, pause/reset protection, source-pair evidence, stale rosters, self-exclusion, empty/rejoining parties, repeated victory/endless summaries, reload flags, a second run and missing optional party data. The full suite passes under Lua 5.0.3 and Lua 5.1; the nine-class fresh-process matrix is retained. `tools/checks.py` includes independent offline model checks without distributing the game's extracted parser.

The new 12 UI labels are supplied in all 14 languages by `locales-insights.txt`, generated with `tools/build_insights_strings.py`. Chinese/Japanese font subsets retain all existing codepoints and add the new required glyphs. In-client sound, real multiplayer and final layout still require gameplay validation; these automated tests do not claim to have played the game.

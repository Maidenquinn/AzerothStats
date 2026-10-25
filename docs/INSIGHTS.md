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

On run start/resume, snapshot the party-table signature, update stamp and local packet generation. Wait for a fresh sample before observing peers. Exclude the player from the companion-frequency ledger, but retain all valid rows including self in a common comparison snapshot. Store damage, DPS, top spell and top-spell DPS as received; never add a peer to the player's personal meter.

A peer is counted once per observed run, globally and for the player's class, using a saved per-run ledger. Empty/self-only rosters clear the transient peer roster while retaining the last meaningful multiplayer comparison and historical presence. Rejoins, reloads, duplicate summaries and endless continuation cannot increment the same presence twice. A victory is associated with a run containing that observation; it is not an assertion of shared achievement or final roster membership.

Names are local data; no account ID or rename resolution is available. Storage is bounded (32 rows per sample, 64 observed peers per run, 1,024 per aggregate group) and truncation is flagged. No old run receives invented companions or DPS peaks.

## Validation

`tests/insights.lua` executes actual client-parser packets for initial spikes, repeated samples, record sounds/muting, pause/reset protection, source-pair evidence, stale rosters, self-exclusion, empty/rejoining parties, repeated victory/endless summaries, reload flags, a second run and missing optional party data. The full suite passes under Lua 5.0.3 and Lua 5.1; the nine-class fresh-process matrix is retained. `tools/checks.py` includes independent offline model checks without distributing the game's extracted parser.

The 24 additive UI labels are supplied in all 14 languages by `locales-insights.txt`, generated with `tools/build_insights_strings.py`. Chinese/Japanese font subsets retain all existing codepoints and add the new required glyphs. In-client sound, real multiplayer and final layout still require gameplay validation; these automated tests do not claim to have played the game.

## Per-run comparison (1.5.0-dev.1)

`/azstats coop` and Usage → Co-op open the current/latest comparison. The run dropdown selects historical games. All runs shows companion frequency; clicking a companion opens their retained run history, and clicking a run opens its scoreboard. Class filtering follows the player's class, never the peer's class.

A common `AZSPARTY` snapshot containing self supports a damage ranking and shares calculated against the sum of that same snapshot's complete damage rows. Group DPS sums the rates of that one snapshot only, as the native party helper does; rates are never added over time or across runs. Missing numbers stay unknown, duplicate/capped rows mark the snapshot partial, and no shares are computed for zero total damage. Late group packets while terminal/ended can update the snapshot until the preparation boundary.

Old 1.5-dev saves discarded the self party row and retained independent peer samples. The comparison adds the actual personal summary/progress as a separately identified row, with source/time labels. It deliberately omits group totals, ranks and percentages for these independent samples. No user save is rewritten externally. Peer healing, kills, final-result attribution and stable identities are not exposed by this audited party API.

Gameplay check: restart normally, check version 1.5.0-dev.1, run `/azstats coop`, inspect a recorded coop run, then play a new coop game and compare both players' rows during/after play. Check the last meaningful snapshot remains after leaving the party. The UI identifies its sample rather than claiming it is an official final scoreboard.

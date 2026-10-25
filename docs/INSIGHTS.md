# Observed DPS records and co-op history (1.5 development)

## API audit

The currently installed client exposes `AZS_PARTY`, `AZS_PARTY_UPDATED`, the `AZSPARTY` packet and `AZS_GetPartyMeter()`. The embedded parser's row fields are `name,class,dmg,dps,share,top,topdps`; its comment specifies that the table is empty outside a party. The addon consumes the raw parsed rows and does not infer group membership from nearby units or chat messages.

The verified final summary contains result, time, level, kills, damage, damage taken, gold, chests, magnets, class/race/zone metadata and aggregate boss/elite/guardian counters. No verified fatal attacker or shared-achievement field was found. Existing local Death Recap code likewise labels the last received damage as insufficient proof of the killing blow. No exact fatal source can be obtained from aggregate damage counters alone. The new evidence module instead listens for the audited legacy combat-chat events and recognizes the native slain-by template when available.

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

The 39 additive UI labels are supplied in all 14 languages by `locales-insights.txt`, generated with `tools/build_insights_strings.py`. Chinese/Japanese font subsets retain all existing codepoints and add the new required glyphs. In-client sound, real multiplayer and final layout still require gameplay validation; these automated tests do not claim to have played the game.

## Per-run comparison (1.5.0-dev.1)

`/azstats coop` and Usage → Co-op open the current/latest comparison. The run dropdown selects historical games. All runs shows companion frequency; clicking a companion opens their retained run history, and clicking a run opens its scoreboard. Class filtering follows the player's class, never the peer's class.

A common `AZSPARTY` snapshot containing self supports a damage ranking and shares calculated against the sum of that same snapshot's complete damage rows. Group DPS sums the rates of that one snapshot only, as the native party helper does; rates are never added over time or across runs. Missing numbers stay unknown, duplicate/capped rows mark the snapshot partial, and no shares are computed for zero total damage. Late group packets while terminal/ended can update the snapshot until the preparation boundary.

Old 1.5-dev saves discarded the self party row and retained independent peer samples. The comparison adds the actual personal summary/progress as a separately identified row, with source/time labels. It deliberately omits group totals, ranks and percentages for these independent samples. No user save is rewritten externally. Peer healing, kills, final-result attribution and stable identities are not exposed by this audited party API.

Gameplay check: restart normally, check version 1.5.0-dev.1, run `/azstats coop`, inspect a recorded coop run, then play a new coop game and compare both players' rows during/after play. Check the last meaningful snapshot remains after leaving the party. The UI identifies its sample rather than claiming it is an official final scoreboard.

## Favorites and death evidence (1.5.0-dev.2)

Favorites use an additive version-1 index in schema-1 SavedVariables. Stable run IDs pin complete run details beyond the ordinary retention quota. Up to 300 bookmarks/200 pinned runs are allowed. Other bookmarks retain bounded display/tooltip metadata plus a navigation context. Removing a run favorite makes it eligible for normal pruning again. Item variants use existing canonical accessory keys; an absent source run never silently opens an unrelated game. Favorites open the page containing the bookmarked row and highlight it where available.

Read-only re-audit: legacy `CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS`, `CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE`, `CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE`, `PLAYER_DEAD`, `UI_ERROR_MESSAGE` and friendly-death events are available. The extracted FrameXML GlobalStrings defines COMBATHITOTHERSELF (line 778), COMBATHITCRITOTHERSELF (772), SPELLLOGOTHERSELF (3879), SPELLLOGCRITOTHERSELF (3871), PERIODICAURADAMAGEOTHERSELF (3002) and ERR_KILLED_BY_S (1666). These sources were read, not redistributed. Existing Death Recap implementations collect legacy hit messages; labeling the last hit Deathblow does not by itself prove fatal attribution.

The module parses native format strings, including positional placeholders; English fallback hit templates are limited to those verified in that source. A death must follow an observed playing/endless state. Fresh PLAYER_DEAD or a dead run phase closes one segment. Reloading on a dead screen cannot create an old death. A recent (2-second) parsed hit gives a **probable** attacker; a matching explicit slain-by message gives **confirmed** evidence, including a 2-second late-upgrade window. Old/missing/unrecognized hits leave the source unknown. Upgrades replace evidence counts without increasing deaths. Recent parsed hits and unparsed lines are retained for inspection. No modern combat-log API, guessed summary field or per-enemy win count is used. Actual emission of an explicit slain-by message remains a gameplay check, not an automated-test claim.

Records are capped at 20 death reports per retained run, 8 recent hits, 8 unparsed lines and 512 aggregate source names per group. Bounds and missing data are visible. Confirmed and probable counts remain separate. These are deaths observed after this version starts, not backfilled lifetime totals or guarantees about every resurrection.

Gameplay check: normally restart into 1.5.0-dev.2; star an old run, open Favorites and revisit it; adjust retention and confirm it remains. Bookmark a spell/item/companion and inspect its shortcut/tooltip. During a new run, receive damage and die; inspect Nemesis and hover the report for evidence. Check probable/confirmed labels, unknown deaths without a fresh hit and no duplicate count while staying on the death screen. Save by exiting normally and verify bookmarks/reports survive another launch.

## Categorized favorites (1.5.0-dev.3)

Favorites now have six exclusive category tabs with per-class counts and a persisted selection. Existing entries are classified at display time using kind and source tab: spell-kind entries from Combat belong to Combat, while build/usage spell entries belong to Spells. Keys and stored metadata are preserved. New historical combat bookmarks store run ID, meter mode and scope; their run remains protected until its last protecting bookmark is removed. The combined pin limit remains 200 distinct run IDs. Legacy bookmarks with no recorded run ID keep their all-runs scope, since the missing provenance cannot be recovered honestly.

Two original 32×32 uncompressed RGBA TGA textures provide empty/filled hearts independent of font glyph support. Offline checks validate their native texture headers. UI regression tests cover category isolation, combined class filters, counts, actual button callbacks, retained legacy IDs, outlined/filled hearts, historical combat context and source-run protection.

# Azeroth Survivors 0.121 integration

Audited 2026-10-27 after the maintainer installed the update. Development build 1.6.0-dev.8; game-team approval and native gameplay validation remain pending.

## Evidence and implemented surface

The installed executable was read without modification. SHA-256: `22f7938eb4f99f2857dc091b1c57c147bd848eaabfeaa81e444c0a3393ca8150`. Its server AZSZONE serialization format explicitly contains `heroic`; the bundled Lua parser places flat packet fields in AZS_ZONE. The embedded API remains generic and its fixed-facts comments do not list every server field. The local addon-author documentation predates this update and still describes old `mods`; that field is not used to infer Heroic. No extracted client code is shipped.

`API.lua` accepts only integral heroic values 0..5: 0 is explicit Normal, 1..5 are Heroic I..V. `diff` remains a separate zone multiplier, never a Heroic level. Missing fields and old saved runs remain unknown. `Tracker.lua` keeps `heroic` and `heroicSource` per run, enriches late metadata, retains observed difficulty when a reload lacks the packet, and refuses a known incompatible difficulty for heuristic resume. As with all packet identity, freshness is not authentication and no server UUID exists.

Run headers, recent-run metadata, History, Character context and run Favorites expose difficulty. History's separate dropdown filters only retained matching runs; its summary cards use that same cohort. Lifetime Overview, Classes and Records still aggregate all difficulties and are labeled accordingly. They are not falsely presented as Heroic-only records. Filtering changes no accounting ledger. No legacy run is silently classified as Normal.

The existing read-only SetInventoryItem scanner now retains up to 64 bounded native lines (previously 40), including native set/stars/decimal bonus text when exposed. Captured historical text is preserved; a fallback reference from another observation explicitly warns that stars and worn-set context may differ. Item IDs alone are insufficient to reconstruct those bonuses. No tooltip formula or set-effect activation is synthesized.

Catalog boss/zone/time references remain visible. Old catalog drop percentages are suppressed in favor of a translated variability notice: they cannot represent Heroic rewards or a player's bad-luck protection. The addon does not calculate a personal drop chance from the changelog.

## Not exposed through the verified structured addon surface

No verified structured fields were found for per-class marks/wallet, marks earned/spent, star upgrade transactions, individual item star levels, 4/8-piece activation/empowerment, unlock progression, bad-luck counters, weapon-glow selection or weekly affix IDs. Their presence in the game's armory/save implementation does not make them public addon APIs. This build does not read RSE1/game saves, scrape private launcher state, send commands, set difficulty, purchase upgrades or change equipment.

The changelog describes these mechanics, but cannot establish runtime field names or historical values. Weekly affixes are not guessed from the date; marks are not calculated from boss count; old builds are not upgraded retroactively. Native text can contain some of this information, but remains text rather than an exact structured counter.

For a future native API extension, useful read-only fields would be: run difficulty/affix IDs with server run identity, personal marks earned by run and current wallet, item ID plus star rank and effective bonuses, active set IDs/piece thresholds/empowerment, and class-zone Heroic clears. The addon can add optional bounded fields without replacing schema-1 run IDs or existing ledgers once those contracts are verified.

## Validation and real-client checks

Synthetic tests cover Normal/each Heroic level, old-client absence, malformed values, late metadata, reload continuity, incompatible-level separation, retained-history filtering, empty categories and native tooltip content beyond line 40. ZIP acceptance cycles the six levels across all nine classes/outcomes in fresh native Lua 5.0 processes. These use simulated packets and are not proof of a completed in-game Heroic run.

Fully close/relaunch after installing because localized font bytes changed. Start a Normal run, then an unlocked Heroic run: check the History badge/filter and Diagnostics AZS_ZONE.heroic. Reload mid-run and verify one retained entry. Inspect an upgraded armor piece's native tooltip, especially decimal bonuses, piece list and 4/8-piece text; finish/restart and verify the historical text remains the original observation. A pre-update run should remain Difficulty unknown. Compare current read-only native tooltips; the addon must not offer an upgrade/equip action.

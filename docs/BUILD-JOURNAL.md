> Release update, 28 October 2026: the maintainer validated dev.3 and authorized 1.6.1-beta.1. The development-state wording below records the original implementation/testing stage. See RELEASE-NOTES-1.6.1-beta.1.md for current behavior and limits.

# Sampled build journal — 1.6.1-dev.1

## Scope and audited evidence

The installed client was read-only audited on 2026-10-28 (SHA-256 `de7147a2a3a01b4fb84f3a7f036bc940f9e7d4fdfc42a7fdb79f3f1b2bd798be`). Its embedded public Lua adapter exposes AZS_SPELLS rows as key/spell/rank/cd/cdmax; the AZS prefix updates AZS_STATS through the native AZS_Parse adapter. Neither the helper block nor the local addon-author documentation exposes a confirmed card-choice event carrying an option ID, rarity and exact bonus list. No client source extract is included here.

This is an observation journal, not a complete card history. It records spell-rank maps, a fixed whitelist of global numeric stats and links from the existing periodic equipment snapshot. It does not scrape the launcher/HTML, inspect private saves, intercept clicks, wrap native UI functions or send commands.

## Semantics

BuildJournal.lua initializes on new observed runs; enabling it on an already tracked run is partial. Each dimension establishes its first available baseline. Missing native values do not become zero; cooldown movement is excluded. Freshness gates reject unchanged globals held over from a previous boundary. The existing one-second sampler may combine several choices into one observed rank jump, and delayed rank/stat packets remain separate observations. Server run seconds label when the state was observed, not necessarily when a card was clicked; several entries can share a stopped run clock.

Global area/gold/damage bonuses show before/after values plus differences in percentage points. For example, area multiplier 1.00 → 1.32 displays 0% → 32%, +32 pp. This is a derived change of sampled totals, not the card's rolled percentage or a causal attribution. Buffs, class mechanics, talents, gear, set effects and multiple choices can contribute. Temporary buff changes may therefore appear too.

Inventory changes come from the existing fifteen-server-second snapshot and may lag or combine changes. Identical links with different star/set effects are not reconstructed as a gear upgrade; captured native item descriptions remain available in the Equipment views. No exact card identity/rarity, offered options, rejected/skipped choices, rerolls or pick count is inferred.

The report's Build journal section lists observations newest first; hover exposes all changed fields. /azstats journal opens the selected/current/latest run's journal. Diagnostics includes its observation count/partial/limit flags. Older runs without a journal display an explicit empty state.

## Bounds, persistence and review

One optional buildJournal version-1 tree belongs to each retained run. It contains entries, last-state dictionaries, gear snapshot time and partial/truncated flags. At most 32 spell keys, fifteen fixed stat keys, nineteen inventory slots, 128 entries and 256 total changed fields are retained. At a limit the journal stops accepting entries, retains the last-state baseline for deduplication, and visibly marks truncation. Normal run retention/favorite protection applies. ValidateJournal rejects malformed saved shapes before formatting/arithmetic. Journal operations never call Account or adjust lifetime/usage ledgers.

Tracker samples after its existing snapshot and before Usage clears spell freshness. The verified AZS prefix is added to the bounded notification allowlist only to mark fresh stats; payload text is never evaluated by this addon. No new native API reader or registered event is introduced. Existing schema-1 histories remain compatible, with no retrospective reconstruction.

Tests cover initial state versus gains, exact global before/after numbers, percentage-point formatting, cooldown noise, missing fields, batches, periodic gear, reload deduplication, stale gates/fresh notifications, late join, caps, malformed/metatable data, fourteen languages and unchanged ledgers. Native interaction remains a development-preview check.

## Exact card-history API request

For a true card-by-card feature, a game-provided read-only event/feed should include a stable run/event sequence ID, server time, choice kind (level/chest/etc.), option/ability/accessory key, rank before/after, rarity and the exact accepted bonus list with units/semantics. Offered/rerolled/skipped cards require separate explicit events if those are to be tracked. A bounded replay cursor would allow recovery on reload without duplicating picks. This describes a requested contract, not API fields assumed to exist.

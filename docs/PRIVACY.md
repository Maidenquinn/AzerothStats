# Local data and privacy

The client persists `AzerothStatsDB` through SavedVariables. The addon does not open/write files itself, upload history, send chat/addon messages or require an external account.

Stored observations may include your character name/class, companion names/classes, zone, timestamps, results, counters, ranks/builds, equipment links/descriptions, progression, favorites and recent combat/death evidence. No password or authentication token is requested. Companion names are labels, not verified account identities.

Ordinary detailed retention defaults to 200 (configurable 10–1,000). Bookmarks protect up to 200 runs; at most 300 bookmark entries. Lifetime/class totals, usage, companion/death aggregates and bookmark metadata may outlive detail pruning. Reducing retention is not a complete privacy deletion.

To remove all history, close the game normally, identify/back up the addon's own SavedVariables file, then remove only its `AzerothStatsDB` data/file through the client's supported process. Portable clients may use `benilla-config/saved/AzerothStats.lua`; layouts differ. Do not alter the game's `.sav` files. Removing addon source does not necessarily delete saved history. Keep backups private.

The client normally flushes at logout. A crash can lose observations. An invalid database disables collection and preserves its original root; it is not automatically erased.

Diagnostics are local, but screenshots and manually shared saves may disclose names/timestamps. Review/redact them before reporting. Developer tests execute explicitly selected trusted Lua fixtures/saves; do not use untrusted downloaded saves. Validation cannot prevent the client executing a malicious SavedVariables file before initialization.

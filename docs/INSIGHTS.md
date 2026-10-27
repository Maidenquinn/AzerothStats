# Insight definitions

See `ARCHITECTURE.md` and `API-CONTRACTS.md` for implementation boundaries.

## DPS

For valid playing/endless samples after ten server seconds: `AZS_RUN.dealt / AZS_RUN.t`. Store the observed maximum and source pair. Choice/pause/terminal/regressing samples do not establish peaks. First class record seeds silently; optional source-defined native sound can announce a later record once per run.

## Co-op

Fresh `AZS_PARTY` samples (at most 32 rows) expose names/classes, damage, DPS, share and top spell. Team rankings/totals require a common snapshot; independent records remain partial. Companion frequency counts distinct observed runs. Victory means that name was seen during a run you won, not proof of shared completion/achievements. Names are not stable account IDs.

## Usage/favorites

Usage counts observed builds, rank gains/maxima and accessory families. First samples establish baselines. No exact clicks/casts are claimed. Favorites have History, Combat, Spells, Equipment, Jewelry and Co-op categories. Up to 300 entries/200 protected runs; hearts remove them. Ordinary retention preserves protected runs.

## Nemesis

Observed deaths retain recent native log evidence. Last attacker within two seconds is probable; an explicit native slain-by message, when emitted, can confirm. Confidence buckets stay separate. Not every fatal hit is exposed; no per-enemy victory statistic is invented.

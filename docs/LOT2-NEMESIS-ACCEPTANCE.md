# V2.0.1 Lot 2 — Nemesis and provenance acceptance

Status: **audit in progress; not an in-game recipe authorization**.

## Verified by source inspection

- `Nemesis.lua` arms a death watch only after observed play; the dead screen alone must not create a death.
- `MarkDeath` closes the watch before recording, limiting duplicate events in one life segment.
- Native explicit slain-by text is **confirmed**; a recent observed hit is **probable**; otherwise the source is **unknown**.
- `UpgradeDeath` reassigns the attribution bucket without incrementing the observed death total.
- Evidence retention is bounded (20 death rows, 8 hits, 8 unparsed messages); source aggregation is capped at 512 names.
- `Views.lua` treats absent co-op evidence as unknown, not as proof of solo play, and marks partial observations.

These are code observations, not runtime test results.

## Mandatory automated regression scenarios

1. Loading while already dead does not record a death.
2. Two consecutive dead polls produce one recorded death.
3. A last hit within two seconds is probable, never confirmed.
4. An explicit slain-by event within the grace window upgrades probable to confirmed without changing total deaths.
5. A repeated explicit message does not increment counts or create another death.
6. A late explicit message outside the grace window cannot rewrite an earlier death.
7. A new life re-arms only after positive HP and the grace interval.
8. Unknown death retains no invented attacker.
9. A class-filtered Nemesis report agrees with global and per-class counters.
10. Legacy runs without group evidence remain unknown; partial runs remain visibly partial.
11. A comparison of independent co-op samples is not labeled synchronized.
12. Reloading a saved database does not duplicate or silently reclassify historical deaths.

## Potential edge cases requiring focused investigation

- Source-cap saturation while upgrading a probable death to an explicit confirmed source: totals must remain truthful even if source attribution cannot be retained.
- Explicit death messages arriving near a re-arm boundary must be associated with the correct life segment.
- An evidence source hidden by a per-source Nemesis reset must not create a misleading global/class mismatch.
- Locale-specific native combat templates must not be treated as confirmed unless the explicit native template matches.

## Exit criteria

All mandatory regression scenarios have executable tests and green CI, provenance displays are reviewed, the final ZIP is produced from the exact tested commit, and the owner performs a single in-game recipe. No merge or public release before owner approval.

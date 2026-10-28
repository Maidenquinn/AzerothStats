> Release update, 28 October 2026: the maintainer validated dev.3 and authorized 1.6.1-beta.1. The development-state wording below records the original implementation/testing stage. See RELEASE-NOTES-1.6.1-beta.1.md for current behavior and limits.

# Co-op run visibility — 1.6.1-dev.2

The preview builds on the existing native AZSPARTY snapshots. No API, event, outbound message or saved field was added for this UI change.

History, recent-run details, run selectors, the window breadcrumb and report banners identify runs with observed multiplayer evidence. The count describes the last shared snapshot, not the total number of distinct players across the run. Older independent companion observations are labeled partial. Absence of evidence never classifies a run as solo.

The report Co-op section shows group damage, summed native DPS and sample size. Ranking and damage contribution require the existing common-snapshot completeness checks. Missing values remain unavailable. Hover a player for exact damage, available DPS, top spell/top-spell DPS and sample provenance/time. This is a snapshot comparison, not proof of equal participation time or an overall performance score.

The audited public party rows expose name, class, dmg, dps, top and topdps. Other-player healing, kills, gold, full build and full spell-by-spell damage are unavailable. The preview does not request data from other addons or inspect other players’ saves.

## In-game recipe

Fully restart after installing 1.6.1-dev.2. Start a new co-op run and wait for native party data. Check History and Overview labels, open its report and select Co-op. Verify names/classes against the native party and hover rows for sample details. Finish the run, then start another one: the older report must retain its own snapshot. Restart normally and recheck. Old runs without saved party evidence must remain unclassified. Missing/partial data must not produce a fabricated ranking.

The experimental build journal is included in this local development preview. Public verified 1.6.0-beta.2 is unchanged. No native playthrough is claimed by offline tests.

## Offline validation

3,930 offline assertions passed, including multilingual co-op presentation, unknown mode, partial/no-self sample and immutable saved observations. Native Lua 5.0.3 syntax and behavioral suite passed. The exact 75-file player ZIP passed 27 acceptance cases in 81 fresh processes (1,764 assertions). A synthetic French widget render was inspected; this is not a native screenshot.

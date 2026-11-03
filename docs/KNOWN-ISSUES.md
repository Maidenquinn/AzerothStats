# Known limitations

V2 development candidate: native rendering and actual client save/reload/rollback
remain unverified. Raw `AZS_ZONE.affixes` is now retained from fresh packets;
the older V1 conclusion below does not apply to this field in V2. Dedicated
totem APIs and causal card effects remain unconfirmed. Advanced observations
use explicit bounded retention; see [V2 acceptance](V2-ACCEPTANCE.md).

1.6.2-beta.1 is a beta prerelease. The HUD editor hotfix was confirmed locally; retesting by the originally affected player is pending. The maintainer validated dev.3 and authorized this update; no exhaustive native test matrix is claimed. Game-team permission to post as a verified addon was reported by the maintainer on 28 October 2026; native report/comparison interaction checks remain part of beta testing. See CHRONIQUES.md for the new HUD recipe. Earlier 1.5.1 audit records describe their original candidate.

- No authenticated run UUID/account ID: resume/freshness is heuristic; same-name companions can merge.
- Missing/late native data stays unavailable/partial. Starting mid-run cannot reconstruct earlier builds. Oversized meters are rejected, not silently shown as exact partial totals.
- Opened chests require the official terminal summary. Live chest price is not a count. Unsupported legacy values cannot be recovered exactly.
- Trends measures builds/rank gains/accessory changes, not clicks or casts. First rank is a baseline; tiers group by known family.
- Co-op comparisons require exposed native group data. Independent samples stay partial; no shared achievement or guaranteed shared completion is inferred.
- DPS record is peak observed run-average DPS after ten server seconds, not instantaneous DPS.
- Last attacker is probable unless explicit native fatal-source evidence confirms it. Other deaths may remain unknown.
- Historical descriptions depend on capture/reference matching. Rounded reference bonuses are not exact native stats. Captured text may remain in its original language.
- Bounds can exclude detail. Very large/malformed saved trees disable collection and preserve input rather than silently rewriting it.
- Native client/other addons share Lua and are outside this audit. The client normally persists at logout; crashes can lose data.
- The dev.3 1024-square images did not load after a full restart. User screenshots confirm that dev.4 small components render. The exact prior rejection mechanism remains unconfirmed. Dev.5 independent editor dragging, scale and persistence still need native interaction verification. The client move-to-start foreground prompt can draw over addon frames; a higher frame level has not been verified to solve it.
- Fourteen-language structure is tested; wording, fonts and layout still need human in-game review.
- RSE1 imports, external sync, automated uploads and executable patching are excluded.

- 0.121: missing historical difficulty stays unknown. Lifetime aggregates combine difficulties; the History filter covers retained rows only. No verified public structured marks/stars/affix fields were found. See CLIENT-0.121.md.

- Reports compare observed snapshots, not identical conditions or causal build effectiveness. Older runs lack pre-run record baselines. Unknown difficulty, missing sources and pruned details remain explicit; the comparison does not rank overall performance. The 30-second notice depends on receiving an accepted native summary.

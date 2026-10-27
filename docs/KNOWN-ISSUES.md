# Known limitations

1.6.0-dev.5 is a development preview pending real-client UI validation and game-team approval. See CHRONIQUES.md for the new HUD recipe. Earlier 1.5.1 audit records describe their original candidate.

- No authenticated run UUID/account ID: resume/freshness is heuristic; same-name companions can merge.
- Missing/late native data stays unavailable/partial. Starting mid-run cannot reconstruct earlier builds. Oversized meters are rejected, not silently shown as exact partial totals.
- Opened chests require the official terminal summary. Live chest price is not a count. Unsupported legacy values cannot be recovered exactly.
- Usage measures builds/rank gains/accessory changes, not clicks or casts. First rank is a baseline; tiers group by known family.
- Co-op comparisons require exposed native group data. Independent samples stay partial; no shared achievement or guaranteed shared completion is inferred.
- DPS record is peak observed run-average DPS after ten server seconds, not instantaneous DPS.
- Last attacker is probable unless explicit native fatal-source evidence confirms it. Other deaths may remain unknown.
- Historical descriptions depend on capture/reference matching. Rounded reference bonuses are not exact native stats. Captured text may remain in its original language.
- Bounds can exclude detail. Very large/malformed saved trees disable collection and preserve input rather than silently rewriting it.
- Native client/other addons share Lua and are outside this audit. The client normally persists at logout; crashes can lose data.
- The dev.3 1024-square images did not load after a full restart. User screenshots confirm that dev.4 small components render. The exact prior rejection mechanism remains unconfirmed. Dev.5 independent editor dragging, scale and persistence still need native interaction verification. The client move-to-start foreground prompt can draw over addon frames; a higher frame level has not been verified to solve it.
- Fourteen-language structure is tested; wording, fonts and layout still need human in-game review.
- RSE1 imports, external sync, automated uploads and executable patching are excluded.

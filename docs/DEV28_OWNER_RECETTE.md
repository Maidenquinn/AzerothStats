# AzerothStats dev.28 — owner-only in-game acceptance checklist

Status: **owner approved publication on 3 November 2026**, following in-game acceptance of the date-picker and history-filter corrections, and passing the regression CI. This is an archive of the owner acceptance checklist. The native move-to-begin overlay is still a known limitation.

## Before opening
- Back up `WTF/Account/.../SavedVariables/AzerothStats.lua` and confirm the prior stable addon loads.
- Install the test ZIP under `Interface/AddOns/AzerothStats`, with exactly one addon folder.
- Confirm addon version and that previous runs and favorites are preserved.

## My runs and filters
- Open My runs > Filters. Check the panel is readable, within the window, and its controls do not overlap the run list.
- Map menu lists only zones from stored runs; selecting All maps removes the restriction.
- For each metric (level, kills, gold, survival seconds), verify both Min and Max sliders and their numeric inputs. Max should equal the highest recorded per-run value, not a game-wide theoretical cap.
- Check Min > Max gives a visible error, and impossible dates or reversed date ranges are rejected without losing prior filters.
- Confirm a full untouched metric range does not exclude old runs missing that metric; a narrower range must exclude runs with unknown values.
- Check a run with a legacy top-level value can influence the slider bounds.
- Open both date pickers, change months across year boundaries, select February 29 in a leap year, and confirm the chosen date appears in YYYY-MM-DD.
- Apply combined map + dates + metrics, reset, then reopen the panel. Check values and labels persist correctly.
- Verify pagination, search, Run Report > Compare runs > Back to My runs and the previous history page.

## Other screens
- Overview vs All statistics tabs, Edit page footer, Restore hidden rows.
- Run reports, compare values, sorting, navigation, and empty history state.
- Localization FR/EN, focus/escape handling, panel close, game overlay, narrow resolutions and UI scale.

## Publication gate
- GitHub Actions must be green for the exact review commit.
- Owner accepted the calendar and main filters in-game; the native move-to-begin overlay remains an explicitly documented limitation.
- The owner explicitly authorized the v2.0.0 stable release and removal of superseded dev.14–dev.28.1 release pages. Never publish subsequent builds without renewed authorization.
- Artifacts on a public repository are not confidential. Use a private repository or restricted channel if the ZIP itself must remain secret.

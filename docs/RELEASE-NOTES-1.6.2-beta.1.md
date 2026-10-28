# Azeroth Stats 1.6.2-beta.1 — HUD Editor Hotfix

Addresses **My bar** disappearing behind the main window when changing a statistic or scope, and the gear seeming unable to reopen it.

## Changes

- Dropdowns now belong to the window that owns their control. Editor dropdowns no longer promote the main window above My bar.
- Editor/menu frame levels are recalculated when opening/refreshing. Automatic main-window promotion is disabled only while editing and restored on close.
- Clicking the gear or `/azstats hud` to refocus an already open editor preserves its unsaved draft.
- Independent editor position/scale, Apply/Cancel and existing history/settings are preserved.

The maintainer confirmed the dev.1 fix in game. This beta is published for broader testing, including the original reporter; no claim is made that unrelated client/UI errors are resolved.

## Download and update

Download **AzerothStats-1.6.2-beta.1.zip**. The separate source-review archive is for reviewers.

Close the game completely, replace the addon files in your active AddOns directory, preserve your existing `AzerothStatsDB`, then restart. Verify `/azstats` displays **1.6.2-beta.1**. No settings/history reset is required.

## Please retest

1. Open the HUD gear or `/azstats hud`.
2. Change several metrics and scopes, including a paginated menu.
3. Click/move the main window, then use the gear again. My bar should remain accessible and keep uncommitted changes while already open.
4. Check Cancel/Apply and ordinary class/history menus afterwards.

If it still disappears, share the version, exact sequence, screenshot/video and any Lua error. Please hide private information.

[Full changelog](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.2-beta.1/AzerothStats/CHANGELOG.md) · [Validation](https://github.com/Maidenquinn/AzerothStats/blob/v1.6.2-beta.1/docs/RELEASE-VALIDATION-1.6.2-beta.1.md) · [Report an issue](https://github.com/Maidenquinn/AzerothStats/issues)

No new game-data API, outgoing message, gameplay automation or save import is added. The project’s permission to be posted as a verified addon is recorded separately; no new independent certification or game-team re-review is claimed.

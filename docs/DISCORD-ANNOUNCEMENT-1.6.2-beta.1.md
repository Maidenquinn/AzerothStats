# 🛠️ AZEROTH STATS — HOTFIX 1.6.2-beta.1

A fix is available for **My bar disappearing behind the main window** when changing a statistic or scope, with the gear appearing unable to reopen it.

**Changelog**
• Fixed editor dropdown ownership and window ordering.
• The gear and `/azstats hud` can refocus an open editor without discarding unsaved changes.
• Existing editor positioning, Apply/Cancel, settings and run history are preserved.

**⬇️ Download**
https://github.com/Maidenquinn/AzerothStats/releases/download/v1.6.2-beta.1/AzerothStats-1.6.2-beta.1.zip

**Release notes**
https://github.com/Maidenquinn/AzerothStats/releases/tag/v1.6.2-beta.1

Close the game completely, replace the addon files and restart. **No settings/history reset needed.**

ZA5TEESH, thanks for the video! I could reproduce the editor going behind the main window, and this fix works on my setup. Could you try this build, change a few metrics/scopes and let me know whether it also fixes the disappearance on yours? If not, please include any Lua error. 🙏

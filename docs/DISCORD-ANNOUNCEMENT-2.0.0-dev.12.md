# Discord — copy only, do not post automatically

⚔️ AZEROTH STATS — V2 PREVIEW 2.0.0-dev.12
Same V2 preview. Much smoother in combat.

This hotfix keeps the 2.0.0-dev.11 Chroniques-style V2 experience and focuses on live sampler performance. Schema 1 history and settings stay intact — no reset needed.

⚡ PERFORMANCE
Cuts the freezes caused by the 1 Hz tracker: staggered equipment tooltip scans, stamp-aware meter/spell/journal updates, jewelry baseline caching, lighter V2 writes on large local histories, and cached combat-log patterns for Nemesis.

🧪 DATA KEPT
Kills, gold, damage, meters, build journal, jewelry, equipment descriptions, co-op/party samples, V2 observations and official end summaries remain collected. Equipment tooltips may finish a few seconds after a gear change, then flush completely when the run ends.

🧭 STILL THE V2 PREVIEW
Overview, My runs, Analyze, Progression, Favorites, Nemesis — themes, goals, notes, overlay controls and Manage local data unchanged in intent from 2.0.0-dev.11.

⬇️ Download the player ZIP
https://github.com/Maidenquinn/AzerothStats/releases/download/v2.0.0-dev.12/AzerothStats-2.0.0-dev.12.zip

📋 Full changelog
https://github.com/Maidenquinn/AzerothStats/releases/tag/v2.0.0-dev.12

Updating
Close the game completely, replace the addon files with the player ZIP (not GitHub’s Source code ZIP), keep your existing AzerothStatsDB, then fully restart.

Useful commands
/azstats — Open the addon
/azstats history — Browse runs
/azstats hud — Customize your stats bar
/azstats data — Manage local data
/azstats overlay — Session overlay diagnosis
/azstats diagnose — Diagnostics
/azstats help — Command help

Still a preview
Live multiplayer revive/encounter edge cases and final visual polish still need player feedback. Summary-only counters can still say At run end until the official summary arrives.

Found an issue? Include addon/client versions, class, steps and a screenshot or `/azstats diagnose` output. Please don’t post personal save files publicly.
https://github.com/Maidenquinn/AzerothStats/issues

Thanks for the combat FPS reports that drove this hotfix — enjoy a smoother V2 preview! ⚔️

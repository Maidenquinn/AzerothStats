# AzerothStats 2.0.1 — Lot UI / themes / navigation

Status: IN PROGRESS. Began after HUD native 9/9 PASS on 2026-11-05. Work on PR #31 branch `feat/v2.0.1-aviiva-feedback`. Do not modify accepted HUD layout unless a reproducible regression is discovered.

## Scope and order

### UI-1 — Window geometry and themes
- Audit actual frame anchors, width/height constraints and backdrop/border rendering in default, Warcraft and other themes.
- Fix stretched default-theme borders, cramped window spacing, and clipped settings headings.
- Fix text 'Saved on normal game exit' intersecting its border.
- Keep existing saved window positions and theme preferences compatible.

### UI-2 — Navigation and history
- [Implemented; native pending] Center Search runs and Overview > History actions; also align Overview/All statistics and Records.
- Normalize horizontal menu spacing and Warcraft category hover outlines.
- [Implemented; native pending] Order recognized Blackrock Mountain, Scholomance, Ahn\'Qiraj and Naxxramas maps by campaign progression in both selectors; other maps use deterministic alphabetical fallback.

### UI-3 — Language and explanatory labels
- Correct Optional analyses terminology in EN/FR.
- [Pending] Per-analysis explanations and experimental Combat Intelligence label require changes to canonical `data/catalogs/uiText.json` and regeneration of `Strings.lua`; temporary generated-file edits were rolled back after CI detected stale catalogs. Existing translated labels remain intact.
- Clarify Partial and Sync without claiming data collection or synchronization guarantees not supported by implementation.

### UI-4 — Visual resources (separate verification gate)
- Investigate missing Scholomance illustration and whether an existing compatible asset can be used.
- Review chronicle glyph cropping/texture quality and class icon redundancy.
- Evaluate round minimap icon independent of theme, including persisted setting.
- Any texture optimization must preserve native WoW 1.12 texture compatibility; do not blindly replace TGA with JPEG.

## Implementation requirements
- Inspect existing code, localization keys and tests before changing any view.
- Separate cosmetic changes from saved-variable schema changes.
- Update SHA256SUMS.txt for modified shipped files and add offline tests where practical.
- Do not declare a visual fix accepted solely from CI.

## Final recipe
- Install CI artifact on an existing profile with a backup.
- Compare all supported themes and both FR/EN locales, including long labels and resized windows.
- Verify navigation, map order, settings headings, hover states, and no Lua errors.
- `/reload` and restart: existing window positions, selected theme and preferences persist.
- Report individual PASS/FAIL and screenshots of visual issues. Only then mark this lot accepted.

## Release boundary
The remaining backup, Nemesis, Partial and Sync data-integrity investigations remain tracked in `docs/AVIIVA-FEEDBACK-2.0.1.md`; UI acceptance does not authorize the public V2.0.1 release.

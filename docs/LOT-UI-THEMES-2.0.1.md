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
- [Implemented; native pending] Optional analyses now have contextual EN/FR descriptions, and Combat Intelligence is marked experimental. All 14 locale catalogs contain the keys (English fallback where translations are not yet reviewed); `Strings.lua` is regenerated from canonical `data/catalogs/uiText.json`.
- Clarify Partial and Sync without claiming data collection or synchronization guarantees not supported by implementation.

### UI-4 — Visual resources (separate verification gate)
- [Asset received; integration pending] Maintainer supplied a 1200x750 Scholomance screenshot on 2026-11-05. Converted source JPG and 256x256 WoW-compatible TGA are prepared locally. Integration still requires committing the binary assets, adding `scholo` to `gameText.json` and the image manifest, regenerating `GameText.lua` and `Theme.lua`, and updating checksum/package checks. Do not mark complete until those assets are in the branch and CI passes.
- [Partially implemented; native pending] Remove duplicate Warcraft class emblem from the sidebar; reduce native icon silhouette cropping (1.5% inset instead of 7%) and apply a half-texel inset to the 256px flat-theme icon atlas to avoid adjacent-cell bleeding. Original Chroniques glyph textures still need native visual verification.
- [Implemented; native pending] Add persisted circular minimap icon setting independent of theme, with native tracking ring and reversible square appearance.
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

## Code audit follow-up — 2026-11-05
- PR #31 diff reviewed: 17 files, 630 additions, 188 deletions at `b982767`; latest CI PASS. Changes to persistent settings are confined to the `miniRound` boolean; existing runs are not rewritten by that option.
- Legacy run mode now remains `unknown` without observed Solo/Co-op evidence. This changes filtering, not the stored run history. Regression assertions cover both legacy cases.
- **Risk:** `sortHistoryMaps` ranks English display strings, not canonical zone IDs. Localized map names may be sorted alphabetically instead of campaign order; fix before native acceptance.
- **Risk:** repeated `A.ApplyUI()` in square minimap mode invalidates material caches (`materialTheme`, `themeBackdrop`, `nativeEdge`) even when nothing changed. Reduce unnecessary repaints and test round/square transitions in all five themes.
- **Risk:** source screenshot and TGA exist in local staging but have not been committed to GitHub; do not treat the local preview ZIP as the release artifact. Re-run source hash, generated map, package checksum, and CI after integration.
- **Unverified:** real SavedVariables restore and large-save latency, full theme screenshots, FR/EN labels, corrupted/legacy records. A green offline CI cannot certify these native behaviors.
- Preserve the accepted HUD 9/9 recipe; do not modify its layout without a new reproducible defect.

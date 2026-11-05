# AzerothStats 2.0.1 — HUD lot native acceptance

Branch: `feat/v2.0.1-aviiva-feedback`. Install the ZIP artifact from the latest successful GitHub Actions **Checks** workflow for this branch, not a previous run. Back up the existing SavedVariables before installing. No public release is authorized by this recipe.

## HUD acceptance
1. Load the game and open the HUD editor. Confirm the default height is **40 px** on a new HUD preset; existing customized height must remain unchanged.
2. Set height to **28 px**. The left emblem must remain fully within the bar, with no overlap with the scope title. Check at 240 px width and a wide width.
3. Set height to **72 px** or more, populate eight blocks, and verify two rows and access to all hidden blocks via overflow when needed.
4. Mix short and long metric names, with labels enabled, and compare **French and English**. Columns may have different widths; no text should overlap neighboring blocks or the gear/overflow buttons.
5. Test widths **240, 320, 640, 1024**, then resize the game window. Confirm the bar remains within the viewport and the overflow tooltip is accessible.
6. Toggle icons and labels independently. Test background opacity at **0%, 50%, 100%**; controls and text should remain usable.
7. Move the HUD, save settings, `/reload`, and restart the game. Confirm position, height, width, blocks, icons, labels and opacity persist.
8. Click visible blocks to open their correct statistics view. Open the overflow menu and confirm all configured blocks remain discoverable.
9. Run the same checks with the available themes; confirm no errors, cropped icons, or unexpected clipping.

## Regression
- Open `/azstats`, browse the history and switch Solo/Co-op/Unknown filters. Historical runs without native mode evidence must remain Unknown.
- Verify existing backups and restore controls are unchanged. Do not delete real history to test the HUD.
- Confirm no Lua error or `Unavailable` state.

## Result
Record PASS/FAIL for each numbered step, resolution, language, theme and screenshots of any visual failure. Native acceptance is required before marking the HUD lot complete or announcing a release. Remaining Aviiva UI/assets/data issues are tracked separately in `docs/AVIIVA-FEEDBACK-2.0.1.md`.

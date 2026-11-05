# AzerothStats 2.0.1 — UI alignment native recipe (partial lot)

**Status:** READY FOR NATIVE VISUAL RECIPE — UI alignment sub-lot only. CI run 42044145652 PASS at commit f6e66e4. This does **not** close the full UI/themes/assets lot or authorize a release.

## Install
1. Back up your current `WTF/Account/.../SavedVariables/AzerothStats.lua` before replacing the addon.
2. Download the installable ZIP artifact from [CI run 42044145652](https://github.com/Maidenquinn/AzerothStats/actions/runs/42044145652). Install it in the normal AddOns directory, preserving existing SavedVariables.
3. Confirm the addon loads without Lua errors.

## Manual checks — FR and EN, all available themes
- [ ] Open History > My runs. The **Search runs** caption is horizontally centered over the search input, with no clipping at standard and enlarged UI scale.
- [ ] Open Settings. **Appearance** is centered in its full-width top panel.
- [ ] **Behaviour** and **Storage** headings are each centered inside their own panels and clear of the top borders.
- [ ] **Saved on normal game exit** appears inside the **Storage** panel, is legible and does not intersect its borders or buttons.
- [ ] **Top bar** settings heading is centered and does not clip at its panel edge.
- [ ] Change theme and locale; all headings remain readable with no overlap.
- [ ] Change scale/font size, close and reopen Settings, then `/reload`; saved preferences and positions remain unchanged.
- [ ] History search, map filter, Settings buttons and bar customization remain clickable and functional.
- [ ] No Lua errors and no lost historical runs.

Provide PASS/FAIL for each item, with a screenshot for any FAIL.

## Explicitly not covered by this recipe
- Stretched theme borders and hover outlines.
- Campaign map ordering.
- Scholomance illustration and chronicle glyph assets.
- Round minimap icon and icon-theme independence.
- Optional analyses copy and Partial/Sync explanatory UI.
- Backup/Nemesis data-integrity investigations.

These remain open in `docs/AVIIVA-FEEDBACK-2.0.1.md`. Do not call the full lot accepted based on this sub-lot recipe.

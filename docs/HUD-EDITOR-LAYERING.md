# HUD editor layering — 1.6.2-dev.1 candidate

A maintainer screenshot shows My bar partially behind Settings. The supplied user video (about 7–8 seconds) shows a metric change taking effect on the HUD while the editor disappears visually and the dropdown remains over the main report. This is consistent with occlusion; the video cannot establish the hidden frame’s internal IsShown state or exclude a separate error on another client.

## Cause and change

The editor is an independently positioned/scaled UIParent child. The reusable dropdown was always parented to the main window, whose SetToplevel(true) allows native root promotion on clicks. The editor level was set only once at construction. Clicking an editor menu could therefore promote the wrong root; reopening an already shown editor also replaced its draft without repairing ordering.

The menu now resolves its owner from a bounded parent walk of the anchor, reparents accordingly and updates its frame level on every open. The editor remains independent of the main window’s position/scale. While editing, automatic main-window promotion is disabled and editor/menu levels are maintained relative to it; the editor restores ordinary main promotion in OnHide. Refocusing preserves an open draft. No Raise API, game counter, outgoing message or gameplay command was added.

## Reproduction and native validation

1. Restart with 1.6.2-dev.1. Open Settings, then the gear or Customize bar.
2. Change metric and scope repeatedly, including a paginated metric menu. Only the popup should close; My bar must remain visible and usable.
3. Move the main window and the independent editor, click the main window, then reopen via gear or `/azstats hud`. The editor must be accessible, stay in its own position and retain uncommitted changes when already open.
4. Check Cancel restores the stored HUD, Apply commits it, and closing/reopening starts a fresh transaction. Repeat with an initially hidden HUD and smaller window scale.
5. Open an ordinary class/history menu afterwards: the shared popup must work under the main window again. Test during a run and a level-up overlay; do not assume this fixes unrelated native game overlays.

Offline regression tests now model frame levels/toplevel state and exercise real menu callbacks, owner/root selection, level recovery, draft preservation and restoration. The native compositor itself remains a user test. The supplied video is private diagnostic input and is not committed or packaged.

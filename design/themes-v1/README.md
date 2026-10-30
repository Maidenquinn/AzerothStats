# Five-theme direction

`approved-concept.png` is the AI-generated comparison board accepted by the
maintainer. It is a design reference, not an in-game screenshot or runtime asset.

`previews/` contains offline renders of the real Lua widget tree with synthetic
data, after implementing 1.8.0-dev.1. These previews help compare materials,
typography and page hierarchy. The development renderer approximates native
backdrop edges/compositing and does not replace testing the actual client.

The picker miniatures are drawn by the addon and do not load these PNG files.
None of this directory is included in the player package.

Read [implementation and native acceptance steps](../../docs/VISUAL-THEMES.md).

## Shared design contract

- Stable navigation, data positions and actions in every theme.
- Explicit selected navigation, understandable actions and reversible preview.
- Separate background, panel, text, muted text, accent, success and danger roles.
- Independent font size, scale, opacity and HUD configuration.
- No browser blur, shaders, modern WoW-only API or decorative full-screen overlay.
- Themes customize presentation; they never modify game/accounting data.
- Grimoire's light background requires dark ink throughout controls and dialogs.
- Warcraft uses only source-defined client-native paths for its native artwork.

These rules and token definitions can guide the other addons without adding a
shared runtime dependency between independently installed addons.

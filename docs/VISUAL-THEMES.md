# Five visual themes — 1.8.0-dev.2

Development candidate on `codex/visual-themes`, based on the approved five-theme
direction. This build has not been published or accepted in the native client.
The public release remains 1.7.0-beta.1.

## Player flow

Open `/azstats`, then **Settings → Appearance → Visual theme**. A five-theme list and a large widget preview show the palette, materials and
typography. The preview reads available local counters, not dummy numbers. The
selected style also previews throughout the addon, including the HUD. **Apply** stores the choice. **Cancel**, the close button,
Escape and closing the main window discard the visual draft. Reopen the picker to
compare styles again. Theme names are stable brand names; help and controls are
translated into all fourteen supported languages.

- **Chroniques:** existing blue slate, bronze, original painted ornaments and
  serif headings. Default for new and existing installations.
- **Warcraft:** client-native gold frame/dragon ornaments, red leather buttons and
  WoW icons. Uses the installed client's textures by fixed `Interface` paths.
- **Atelier:** charcoal/stone palette, copper accents, square hairline frames,
  geometric icons, sans-serif headings and no grain.
- **Essentiel:** near-black flat surfaces, understated rules, borderless metric
  cards, smaller heading, reduced profile/metric ornaments and geometric icons.
- **Grimoire:** detailed leather/parchment plates, dark ink, bronze rules, serif
  headings and darker success/error colors appropriate to a light background.

Navigation, page geometry, information and accounting are shared. Themes do not
hide data, reset statistics, choose filters or change combat behavior. Independent
opacity, text size, scale and HUD configuration remain untouched. CJK languages
keep their bundled language fonts in every theme. At reduced opacity, contrast
also depends on the game scene behind the window.

## Implementation for reviewers

`Theme.lua` owns a fixed registry of five definitions. `ThemeId` normalizes any
unknown/malformed setting to `chroniques`. `UseTheme` updates semantic RGB arrays
in place so already-created widgets retain the correct roles. Saved settings
contain only `settings.theme`, a fixed ID; no texture path, code or callback is
read from saved data. Schema 1 and all existing data remain compatible.

`UI.lua` owns the picker and its blocker above the main window, the memory-only
`themePreview`, Apply/Cancel, and repainting of owned surfaces/fonts. Main-window
closure dismisses the picker. The HUD and its editor reuse the shared widgets.
Existing native tooltip contents keep their dark native styling and readable
colors; no global GameTooltip backdrop, CVar or third-party frame is restyled.

Materials reuse the existing nine texture slices. Flat themes use explicit solid
one-pixel rules; Grimoire uses four 256×256 RGBA plates and one quiet paper texture. Only Warcraft sends
Blizzard's native eight-tile edge file to `SetBackdrop`; the custom nine-slice
plates are never passed to that native tiler. Settings panels stay textures on
their existing parent, avoiding child-frame layers covering the labels.
Theme switching reuses registries and creates no extra frames/textures after the
picker's first allocation. Actual spell/class icons are excluded from the generic
glyph repaint registry when a recycled row changes its icon type.

## Asset provenance and native UV audit

No Blizzard file is bundled for the Warcraft theme. The following installed
resources were checked against the locally extracted client on 30 October 2026:

- `Interface\DialogFrame\UI-DialogBox-Gold-Border`
- `Interface\DialogFrame\UI-DialogBox-Gold-Dragon`
- `Interface\DialogFrame\UI-DialogBox-Background`
- `Interface\Buttons\UI-Panel-Button-Up`
- Sixteen fixed icon references listed in `nativeGlyphs` in `Theme.lua`.

`Interface/FrameXML/UIPanelTemplates.xml` defines the native button's useful UV
rectangle as **0..0.625 × 0..0.6875**, not the entire padded bitmap. Its left/right
cuts are **0.09375 / 0.53125**; these are retained in our slices. The extracted
`LootFrame.lua` demonstrates the native border format. These files are read-only
audit inputs, excluded from this repository and player package.

`tools/build_grimoire_assets.py` deterministically crops/encodes the original
ImageGen production artwork retained in `design/themes-v1/artwork`, with a source
hash and prompt. `--check` verifies exact reproduction in
CI. Existing assets retain their provenance in the player's CREDITS.md. No image generation is needed at runtime. The approved concept
board is a visual reference, not an exact native-client screenshot.

## Validation and remaining native checks

`tests/themes.lua` exercises thumbnail callbacks, preview/cancel/apply, persisted
and malformed preferences, all pages, repeated-switch allocation bounds, data
invariance, reused glyphs, opaque semantic-text contrast and fourteen-language
picker labels. It runs in both the offline suite and native Lua 5.0.3 harness;
game frames are simulated. Offline renders in `design/themes-v1/previews` use the
actual Lua widget tree and synthetic data. Native backdrop rasterization, fonts
and compositing can differ from that development renderer.

Before merging/releasing, test in the actual client:

1. Completely restart and check `1.8.0-dev.2` in the header.
2. Preview each theme from Settings. Check the window, HUD, text and selected tab.
3. Cancel, close and use Escape; confirm the stored theme returns each time.
4. Apply another theme, close/restart and verify persistence.
5. Visit Overview, Classes, History/report/comparison, Combat, Character, Records,
   Nemesis, Trends, Favorites, Diagnostics and Settings.
6. Open menus, the HUD editor and data-manager/entry-review dialogs; check readable
   colors and layering. Cancel destructive reviews without deleting player data.
7. Check French plus a longer/CJK language, large text, reduced scale/opacity and
   a narrow screen. Restore personal settings afterward.

The new beta should be published only after native visual acceptance. Automated
tests do not establish that every material matches the approved art direction.

## Historical dev.1 candidate checks — 30 October 2026

- Independent offline suite: 27 runtime modules, 5,280 assertions passed.
- Full scenarios/persistence suite: native Lua 5.0.3 exit 0, including the new theme tests.
- Exact player ZIP: 81 allowlisted files, CRC/manifest verified.
- Package acceptance: 27 class/outcome cases, 81 fresh native Lua 5.0.3 processes,
  1,764 assertions passed. This matrix uses simulated frames and game events.
- Fifteen Python tests passed; formatters, generated catalogs, deterministic
  parchment plates and fourteen-language glyph coverage passed.
- Installed player-package bytes verified and original SavedVariables hash unchanged;
  a private local backup was created. No player data or extracted helper is committed.
- Player ZIP SHA-256: `7427117eb9006336f3d539961c337ff0780797ece171f2307cfa74ee272d9462`.
- Read-only client fixture SHA-256: `8829953418a4d996cc5287f0e9fad25407ca30ceb64d105a4f57833caef78016`.

The acceptance build is local only. Native visual confirmation remains pending;
these checks do not establish pixel equivalence with the concept board.

## Dev.2 screenshot-driven refinements

The maintainer's real dev.1 screenshots showed a low-resolution enlarged shield,
a stretched title button, inherited black text shadows on light paper, overly
similar layouts and schematic miniature previews. Dev.2 removes font inheritance,
explicitly clears shadow color/offset on owned text, and uses verified native gold
border/dragon/class art at suitable dimensions. Font methods SetShadowColor and
SetShadowOffset were found in the local client binary; Fonts.xml confirms that
GameFontNormal inherits MasterFont's (1,-1) black shadow. No global font is changed.

Atelier/Essentiel use separate 168px cards with 14px gutters and left-aligned values;
secondary navigation is muted rather than accent-colored. Header/profile anchors
are reset on every switch. Grimoire's binding uses a 12% corner cut on the 256px
frame component, while controls retain quiet 7% cuts. Available selected-run zone
and duration use the existing run-object localization contract.

The large picker preview reuses owned surfaces and translated labels. It shows
actual aggregate counts/time/kills and selected-run context; missing values remain
unavailable. It changes no statistics or filter state. Screenshots in the source
preview directory are offline renders, not native compositor certification.

## Dev.2 automated package checks

- Independent suite: 6,203 assertions passed, including every owned font's shadow
  override, absence of GameFontNormal inheritance, real preview counts and class art sizing.
- Full scenario suite: native Lua 5.0.3 exit 0; persistence checks passed.
- Player archive: 82 manifest-verified files. SavedVariables unchanged during
  installation; prior dev.1 package/settings copied to a private local backup.
- Native visual acceptance still pending. Public main/release unchanged.

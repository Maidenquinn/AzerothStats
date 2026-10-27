# Reference data and asset provenance

## Catalogs

Twenty-three Lua modules load from the TOC. Five are checked as literal-only: Strings, GameText, Icons, Collection and InsightsStrings. They assign primitive table constructors to fixed addon fields, without callbacks or executable expressions.

`data/catalogs/*.json` supplies Strings/GameText/Icons/Collection. `python tools/build_catalogs.py --check` verifies committed output; omit `--check` only for intentional regeneration. `locales-insights.txt` and `tools/build_insights_strings.py` supply InsightsStrings. Generation needs no network, game executable or Lua evaluation.

The base UI has 157 English keys and the insight extension 39; game-reference text retains 236 keys per language after removing 705 unrelated labels. Fourteen locale key sets are checked. The existing collection contains 7,473 aliases, 562 source entries and 92 ability/class mappings. Mappings remain; class-aware resolution handles ambiguous translated names.

Collection metadata originated from local Azerloot/game data, as already credited. Azerloot is not loaded or required. This review establishes no new license or permission for redistribution: the game team must confirm policy for bundled reference metadata. References may become stale and must not be shown as exact native observations.

## Media

The player package contains five fonts, two OFL notices/licenses, two original geometric heart textures and twenty-eight original Chroniques textures. Derived Noto fonts retain existing names/notices and subset naming; the UI preview adds needed glyphs from hash-pinned originals, using tools/check_fonts.py and data/font-sources.json. Native game borders/icons are Interface references, not copied graphics. See `AzerothStats/CREDITS.md` and `media/OFL-*.txt`.

Four geometric Chroniques textures are reproduced by tools/build_theme_assets.py. Twenty-four small painted components are sliced/resampled from original AI-generated source PNGs by tools/encode_painted_assets.py; see the committed design sources and credits. They contain no copied game assets. The unused full-frame PNG remains a source-only historical proposal. The bold heading font is rebuilt from the official Noto input pinned in data/title-font-source.json; its original notices remain embedded. The original AI-generated concept board remains source-only and is not a runtime texture.

No executable, DLL, `.sav`, native API extract or personal SavedVariables is committed or placed in the player ZIP. Optional local compatibility checks read a selected executable; private inputs stay outside archives. SHA-256 identifies bytes, not approval or safety.

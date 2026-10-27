# Contributing

Read `docs/REVIEWER-GUIDE.md` and `docs/ARCHITECTURE.md`. Use focused changes: concrete problem, resulting behavior, evidence and remaining limits. Do not claim approval without actual game-team approval.

## Runtime conventions

Target Lua 5.0 / interface 11200. Extend the existing namespace, use legacy event conventions and fixed API names. Prefer descriptive locals, early validation and a purpose/contract comment per named logic function. Explain invariants (freshness, ledgers, confidence), rather than restating assignments.

Separate native adapters, persistence, insight definitions, page models and widgets. Missing data is not zero; partial data stays labeled. New maps need bounds/retention. Dynamic evaluation, outbound messaging, gameplay automation and OS access are outside this project's runtime scope. A new native call requires explicit review. Never modify the client, game saves or third-party addons.

## Catalogs and style

Edit `data/catalogs/*.json`, then run `python tools/build_catalogs.py`. Edit `locales-insights.txt`, then run `python tools/build_insights_strings.py`. Generated modules remain literal-only. Preserve provenance/OFL notices; do not invent licensing grants for game data.

Format with StyLua **2.6.0**, using `.stylua.toml` and `.styluaignore`:

```sh
stylua --verify AzerothStats
stylua --check AzerothStats
```

Lua51 formatter mode is not a 5.0 guarantee: run native Lua 5.0 checks for runtime changes. Do not hand-edit generated catalogs to satisfy formatting.

Developer Python tools use Black 25.1.0: `python -m black --check tools AzerothStats/tests`.

## Validation and packages

Follow `docs/TESTING.md`. Offline checks need no client or personal save. Add focused regression coverage for meaningful counter/migration/freshness/bounds/persistence changes. Never commit private inputs or API extracts. Fixture/save tests execute trusted Lua, not arbitrary downloads.

After player-file changes, run `python tools/update_manifest.py`, checks and deterministic packaging. `tools/package_policy.py` owns the exact player allowlist. Developer tools/tests/catalog sources belong only in the source-review bundle.

A future release needs current game-team approval, automated evidence, actual-client validation, archive inspection and an accurate changelog. CI alone does not authorize publishing.

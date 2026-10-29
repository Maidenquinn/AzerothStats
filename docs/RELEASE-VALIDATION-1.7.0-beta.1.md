# Validation — 1.7.0-beta.1

The maintainer reported 1.7.0-dev.5 working in game and authorized publication on 29 October 2026. Release preparation changes version/documentation, not the accepted runtime behavior. This records maintainer acceptance, not exhaustive native UI testing or separate game-team certification.

- Independent offline suite: PASS, 27 runtime modules and 5,057 assertions. Covers syntax/upvalue limits, TOC, manifest, own-data contracts and runtime policy.
- Full behavior/syntax/persistence suite passed with native Lua 5.0.3, including isolated bulk and per-entry resets, replay barriers, new collection and reversible visibility.
- Exact release player ZIP: PASS, 77 files, 27 class/outcome cases, 81 genuinely fresh native Lua 5.0.3 processes and 1,764 assertions. UI objects are simulated.
- Fifteen Python tests, formatters, generated catalogs and fourteen-language font coverage passed during candidate validation/CI; release code differs only in version metadata.
- Synthetic French/Japanese widget previews were inspected. These are not screenshots from the native client.
- Development erasure tests use synthetic in-memory databases only. Installation preserves the player's actual SavedVariables and creates a private local backup.
- Client SHA-256 for exact-package acceptance: 8fef622677e7eb510b7693fb20831d919b679cb99a2edd36c584ae55a3f8d007
- Extracted helper SHA-256: bf481c785f2f161f56e151f5fd85da986c60299efba8f07cd2508ae79532eda7
- Player ZIP SHA-256: 6e1a89587b4270ed4ce3aceb94f93283cd27b4adacd63a6dbcf60a9b12da4ca6

Read [data-management scopes](DATA-MANAGEMENT.md) before destructive native testing. Prefer a disposable backed-up profile for further reset tests. No player save, private screenshot, extracted executable/helper or personal test input is packaged or committed. Existing distribution permission is documented separately in [APPROVAL-STATUS.md](APPROVAL-STATUS.md).

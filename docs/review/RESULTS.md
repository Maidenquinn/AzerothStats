# Candidate validation record — 2026-10-27

Candidate: **1.5.1-review.1**. Baseline: `eab9e73bddc8416b8e6c38475243932044d4c376`. These are maintainer-run automated checks, not independent certification or game-team approval.

- **2,712 assertions** in the client-independent model/UI/adversarial suite.
- **3,097 assertions** in the complete suite under Lua 5.1/Lupa and again under native Lua 5.0.3; persistence round trip passed. These overlap with the offline suite and must not be added together as distinct tests.
- **27 class/outcome cases / 81 fresh Lua 5.0 processes / 1,467 assertions**, against the unpacked final player ZIP.
- **11 Python unit tests** covering the policy scanner and read-only fixture loader.
- Trusted-file fixture path smoke: three fresh processes / 55 assertions. The local fixture was generated from the inspected client; it is not a game-team-supplied endorsement and is not distributed.
- Existing schema-1 save compatibility passed in memory, including idempotent repairs. No private save contents/path/input digest are included in this dossier.
- Fourteen locales, eleven pages, twenty TOC modules; Lua syntax/upvalue, asset notices, generated-data reproducibility and formatting checks passed.
- Runtime policy inventory: five literal-only catalogs; no forbidden capability token found. This is a regression policy, not a complete security proof.
- Deterministic player ZIP: **34 files**, reread/verified against the explicit allowlist and SHA-256 manifest.

Player archive: `AzerothStats-1.5.1-review.1.zip`

SHA-256: `a2189cbd031984a9f24436680142ed3debe5ffef34168bbb9d61a1f5a7e49604`

Machine-readable evidence: `native-validation.json`, `fresh-process-acceptance.json`, `api-fixture-smoke.json`, `runtime-policy.json`. Source hashes and the client/API fixture hashes identify what was checked. The executable/API bytes are not bundled. Use Git revision/source-bundle sidecar to identify the source revision containing this report.

## Still pending

No real-client playthrough or visual validation of **this candidate** was performed. Earlier beta testing is historical evidence only. Follow `docs/TESTING.md` for the candidate recipe, then request the game team's manual review. No public release, installation into the user's running client or developer contact was performed by this audit.

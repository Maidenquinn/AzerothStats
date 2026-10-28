# Validation — 1.6.2-beta.1 HUD editor hotfix

The maintainer confirmed 1.6.2-dev.1 works locally and authorized publication for the original reporter to retest. This documents that limited native acceptance; affected-player confirmation is still pending.

- Independent offline suite: PASS, 25 runtime modules, 4,283 assertions; TOC, syntax/upvalue limits, manifest and capability checks.
- Candidate full behavior/syntax/persistence suite passed in native Lua 5.0.3. The release changes its version/docs, not the tested hotfix behavior.
- Exact release player ZIP: PASS, 75 files; 27 class/outcome cases, 81 fresh Lua 5.0.3 processes, 1,764 assertions. Test UI objects are simulated, not a native compositor.
- Improved mock now retains frame levels and top-level flags. Regressions cover actual popup callbacks, native root ancestry, menu ownership switching, promoted main recovery, draft preservation, Cancel and flag restoration.
- Client SHA-256 for exact-ZIP acceptance: 3ef9d74c30bb6b435d739b3d960c8535486836c540e0d8c20f98549a6f1dcbbb
- Helper extraction SHA-256: bf481c785f2f161f56e151f5fd85da986c60299efba8f07cd2508ae79532eda7
- Player ZIP SHA-256: 090c478b3e58898a8841bc67d5ee86e3bc464d0470c10932e638f8fb2d1476c3

The reporter's private video/screenshots are not committed or packaged. No claim of exhaustive client compatibility, independent security certification or separate game-team re-review is made. See HUD-EDITOR-LAYERING.md for the native retest recipe.

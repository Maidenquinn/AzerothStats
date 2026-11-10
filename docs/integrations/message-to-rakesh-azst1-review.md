# Message to Rakesh — Azeroth Stats v2.0.3 / AZST1

Hi Rakesh,

We have completed the owner-side in-game acceptance of the manual AZST1 export in Azeroth Stats 2.0.3. The export window can select retained local runs, invalidates stale output when the selection changes, generates and copies the full `AZST1:` JSON, and preserves the distinction between an observed zero and an unavailable metric. The payload is an explicit allowlist projection; it does not include backups, raw event journals, equipment links, tooltips, or the detailed SavedVariables structures you already read directly.

We also exercised `AZS_ZONE.run` in game:
- The same candidate remained stable across five successive `/reload` operations during one local run.
- The candidate counter advanced for the next run in the same client session and same zone.
- After a full client restart, the candidate namespace changed/reset; a lobby probe had no local Azeroth Stats run, and the candidate stayed stable when the next run began.
- The observed Endless continuation kept the same local run and candidate.
- Quit Game retained the local run as interrupted with a checkpoint, without an official terminal outcome.

There is one contradictory earlier observation: the same candidate was seen against two different local run IDs in different zones. Because of that, we are deliberately not persisting `nativeRunId`, not backfilling old runs, and not auto-linking on the raw candidate. AZST1 currently emits `nativeRunId: null`.

Our proposed interpretation is that `AZS_ZONE.run` is session-scoped rather than globally unique. Before we implement any optional persistence/correlation, could you confirm:
1. Is the opaque prefix part of the native identifier meaningful as a client-session namespace?
2. Is your matching strictly constrained to one uploader execution/upload, and can one upload ever combine logs from different client processes/sessions?
3. Is `(upload scope, session namespace, AZS_ZONE.run)` a safe candidate key for your importer, with zone/difficulty/time used only as consistency checks?
4. Do you expect Azeroth Stats to persist the native value on each retained run, or is reading it from the existing WoW Logs AS collector sufficient for your current matching flow?
5. Can you share the exact field types and lifecycle assumptions you rely on for desktop and browser clients?

The current implementation preserves the existing v2.0.2 SavedVariables layout and the fields your direct reader consumes (`runs[].summary`, `stats`, `equipment`, `timeline`, `deaths`). No uploader, backend, network transmission, or WoW Logs dependency has been added to Azeroth Stats.

The AZST1 contract and owner acceptance report are in the v2.0.3 branch under `docs/integrations/`. The CI is green for the latest addon-code commit; the PR remains open and will not be merged or released until owner approval and your contract feedback.

Thanks!
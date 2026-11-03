# Official death recap and Nemesis — 31 October 2026

The installed client contains its own death recap. Its native UI serialization
includes `killer`, `hits`, `by`, `overkill`, `absorbed` and `avoidable`. These are
native screen data, not a verified addon API contract.

A read-only extraction of the current embedded Lua API found no recap getter,
callback, global, or packet handler. `AZSEND` remains flat run-summary fields;
`AZS_Parse` used for `AZS_STATS` keeps numeric fields only. No verified transport
currently connects the official recap to Nemesis. Bounded binary string evidence
and the complete Lua export/prefix inventory are in the developer-only artifact
`release-assets/v2/client-death-recap-audit.json`. No live packet capture was done.

Runtime behavior is unchanged: an explicit native slain-by message can confirm
an observed death; a recent last attacker remains probable. Existing data must
never be reclassified merely because an official recap now exists.

For client developers, a useful read-only interface would expose one local death
identifier, run time, fatal attacker's display name and source/ability category,
with a notification or update timestamp. A documented structured fatal-hit record
would allow late evidence to upgrade an existing death without recounting it.
These are requested fields, not invented names the addon attempts to call.

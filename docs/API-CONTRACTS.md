# Native API and effect contracts

Contracts derive from locally inspected client helpers and regression fixtures. A different client may change them. Missing helpers/values remain unavailable. Tests accept a **trusted fixture supplied by the game team**; no client source extract is shipped.

## Fixed read adapters

- `AZS_GetPhase()` / `AZS_RUN.ph`: only recognized phases are accepted.
- `AZS_RUN`: server `t`, `kills`, `gold`, `lvl`, `dealt`, `taken` and health fields. Server `t` is the basis of run-duration/DPS records.
- `AZS_GetRunTime()`: interpolated client time, not a second server counter. Helper meter rates can differ from server-sample records.
- `AZS_GetMeter()` / `AZS_METER`: source damage rows; helper sums rows and divides by `max(1, AZS_GetRunTime())`.
- `AZS_GetHealing()` / `AZS_HEALING`, `AZS_GetBossMeter()` / `AZS_BOSSMETER`: native totals/rates. Boss scope is the last available boss meter, not all bosses summed.
- `AZS_TAKEN`: damage-taken rows. No invented taken helper is required.
- `AZS_GetRunSummary()` / `AZS_END`: official terminal result/counters where exposed. Opened chests come from here, not the live price.
- `AZS_ZONE`, `AZS_SPELLS`, `AZS_STATS`: identity/map, build ranks and attributes. Only bounded copies/scalars are retained.
- `AZS_PARTY`, its stamp and `AZSPARTY`: group rows `name,class,dmg,dps,share,top,topdps`. `AZS_GetPartyMeter()` exists in the inspected client, but the addon reads validated raw rows. Team comparisons require one common sample.

### Missing live zone metadata

`A.Identity()` keeps a supplied zone ID authoritative. If it is absent/unknown, it matches the packet label, then `GetMinimapZoneText`, `GetSubZoneText`, `GetRealZoneText` and `GetZoneText`, against exact names in the fourteen shipped game catalogs. These four read functions were found in the installed client's native API export strings on 2026-10-27. Missing functions/errors/unrecognized names yield no map; there is no fuzzy match or prior-map guess. `zoneSource` records which observation supplied the map and is exposed in Diagnostics.

A live unknown run is enriched when matching metadata arrives. On reload, same hero/class, compatible map, nondecreasing server time, no close reason and no ready/new-run boundary allow the existing heuristic resume to retain its already observed zone. A clock reset starts a new run. No server UUID exists, so this is continuity evidence rather than guaranteed identity; ended unknown records and historical duplicates are not silently rewritten or merged.

The text sanitizer removes explicit ASCII control bytes and UI markup, rather than locale-dependent `%c` classes that can corrupt multibyte UTF-8 labels on Windows. Zone matching folds ASCII letters only.

Stamps/signatures/notifications support freshness, not authentication. Conflicting supplied summary hero/map is rejected. Missing legacy identity remains heuristic.

## Events and notifications

`Core.lua` registers exactly: ADDON_LOADED, VARIABLES_LOADED, PLAYER_ENTERING_WORLD, PLAYER_LOGOUT, CHAT_MSG_ADDON, PLAYER_DEAD, UI_ERROR_MESSAGE, CHAT_MSG_COMBAT_FRIENDLY_DEATH, CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS, CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE, CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE.

Allowed prefixes: AZSRUN, AZSEND, AZSMETER, AZSHEAL, AZSBOSSDMG, AZSTAKEN, AZSSPELLS, AZSPARTY, AZSZONE, AZSSTATS. Bodies must be strings within 65,536 bytes. The addon marks freshness; it never executes, replies to or forwards them. The client has already parsed its own tables. Sender authentication is not provided here.

## Other effects

Reads: identity/class, time/date, locale, inventory links, spellbook metadata, screen/UI geometry and native format strings. Tooltip scanning creates an owned GameTooltip, calls item-only `SetHyperlink` or `SetInventoryItem` and reads line text/colors. `SetInventoryItem` is a **tooltip read**, not an equip operation.

Effects: own frames and visibility/position/texture/font settings; slash registration; local `DEFAULT_CHAT_FRAME:AddMessage`; own SavedVariables; optional source-defined native sound. No send-message function, CVar/binding edit, targeting/casting/equipping operation, dynamic evaluation or OS file/process API is used by the runtime. Widget `SetScript` registers source-defined callbacks; it never evaluates received code.

The static report inventories calls for human verification. Its name-based policy is a regression aid, not exhaustive proof of allowed native behavior.

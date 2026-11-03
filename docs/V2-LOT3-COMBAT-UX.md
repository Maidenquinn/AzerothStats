# LOT 3 — Combat Intelligence UX

Player-facing report: tracking status, recorded hits, critical and periodic hit rates, misses, observed damage, collection quality, and top five damage sources. Rates use observed damage events only; the native meter remains authoritative. Crits and periodic events can overlap. API reads/errors remain accessible to developers through `A.V2CombatDiagnostics()`. No schema migration or changes to other addons.

Acceptance: verify live and retained runs, 0-hit handling, status when disabled or native API missing, stable source sorting, loss warnings, /reload persistence and Lua 5.0 compatibility. Client validation pending.

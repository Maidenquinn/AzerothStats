"""Offline Lua 5.1 regression for Nemesis late evidence and duplicate death events."""

from pathlib import Path

from lupa.lua51 import LuaRuntime

addon = Path(__file__).resolve().parent.parent / "AzerothStats"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    """
NOW = 100
function GetTime() return NOW end
AzerothStats = {
    db = { totals = {}, classes = { hunter = {} } },
    Wall = function() return 12345 end,
    Copy = function(x)
        if type(x) ~= "table" then return x end
        local out = {}
        for k,v in pairs(x) do out[k] = AzerothStats.Copy(v) end
        return out
    end,
}
"""
)
lua.execute((addon / "Nemesis.lua").read_text(encoding="utf-8"))
lua.execute(
    """
local A = AzerothStats
local run = { class = "hunter", values = { duration = 40 }, deaths = {} }
A.run = run
A.BeginDeathWatch(run)
local w = A.deathWatch
assert(not w.armed)
A.MarkDeath()
assert(#run.deaths == 0, "unarmed death counted")
w.armed = true
w.hits = { {source="Enemy A", amount=20, at=NOW, raw="hit"} }
A.MarkDeath()
A.MarkDeath()
assert(#run.deaths == 1, "duplicate death")
assert(A.db.totals.deathEvidence.deaths == 1)
assert(A.db.classes.hunter.deathEvidence.deaths == 1)
assert(run.deaths[1].confidence == "probable")
assert(A.db.totals.deathEvidence.sources["Enemy A"].probable == 1)
w.explicit = {source="Enemy B", raw="killed by Enemy B", at=NOW}
A.UpgradeDeath(w)
A.UpgradeDeath(w)
assert(#run.deaths == 1 and A.db.totals.deathEvidence.deaths == 1)
assert(A.db.classes.hunter.deathEvidence.deaths == 1)
assert(run.deaths[1].confidence == "confirmed")
assert(A.db.totals.deathEvidence.sources["Enemy A"].probable == 0)
assert(A.db.totals.deathEvidence.sources["Enemy B"].confirmed == 1)
assert(A.db.classes.hunter.deathEvidence.sources["Enemy B"].confirmed == 1)
A.ObserveNemesis(run, {hp=100}, "playing")
assert(w.closed, "rearmed too early")
NOW = NOW + 3
A.ObserveNemesis(run, {hp=100}, "playing")
assert(w.armed and not w.closed)
A.MarkDeath()
assert(#run.deaths == 2)
assert(run.deaths[2].confidence == "unknown", "stale hit leaked into new life")
assert(A.db.totals.deathEvidence.deaths == 2)
print("PASS: Nemesis unarmed/duplicate/upgrade/rearm/unknown regressions")
"""
)

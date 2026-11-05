"""Offline Lua 5.1 regression for Nemesis late evidence and duplicate death events."""

from pathlib import Path

from lupa.lua51 import LuaRuntime

addon = Path(__file__).resolve().parent.parent / "AzerothStats"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    """
NOW = 100
function GetTime() return NOW end
function getglobal(name) return _G[name] end
ERR_KILLED_BY_S = "You were slain by %s."
COMBATHITOTHERSELF = "%s hits you for %d."
AzerothStats = {
    db = { totals = {}, classes = { hunter = {} } },
    Wall = function() return 12345 end,
    Number = function(x) return tonumber(x) end,
    Text = function(x, limit) return type(x) == "string" and string.sub(x, 1, limit) or nil end,
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
-- Native late explicit proof: upgrade only during the two-second window.
local run2 = { class = "hunter", values = { duration = 60 }, deaths = {} }
A.run = run2
A.BeginDeathWatch(run2)
local w2 = A.deathWatch
w2.armed = true
A.DeathEvidence("CHAT_MSG_COMBAT_SELF_HITS", "Enemy C hits you for 25.")
A.MarkDeath()
assert(run2.deaths[1].confidence == "probable")
A.DeathEvidence("UI_ERROR_MESSAGE", "You were slain by Enemy D.")
assert(run2.deaths[1].confidence == "confirmed")
assert(run2.deaths[1].source == "Enemy D")
assert(A.db.totals.deathEvidence.sources["Enemy C"].probable == 0)
assert(A.db.totals.deathEvidence.sources["Enemy D"].confirmed == 1)
A.DeathEvidence("UI_ERROR_MESSAGE", "You were slain by Enemy D.")
assert(A.db.totals.deathEvidence.deaths == 3, "repeated native message duplicated death")

local run3 = { class = "hunter", values = { duration = 80 }, deaths = {} }
A.run = run3
A.BeginDeathWatch(run3)
local w3 = A.deathWatch
w3.armed = true
A.MarkDeath()
assert(run3.deaths[1].confidence == "unknown")
NOW = NOW + 3
A.DeathEvidence("UI_ERROR_MESSAGE", "You were slain by Enemy E.")
assert(run3.deaths[1].confidence == "unknown", "stale native message changed an old death")
assert(A.db.totals.deathEvidence.deaths == 4)
print("PASS: Nemesis unarmed/duplicate/upgrade/rearm/unknown/native-late/stale regressions")
"""
)

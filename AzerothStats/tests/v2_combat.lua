-- LOT 2: passive by default; independent cursor; bounded, loss-aware summaries.
local A = AzerothStats
local original, db, run, saved = _G.AZS_GetCombatTextEvents, A.db, A.run, AzerothStatsDB
local function check(ok, why)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "LOT2 combat: " .. why)
end
local calls = 0
_G.AZS_GetCombatTextEvents = function()
    calls = calls + 1
    return { apiVersion = 1, cursor = "tail", streamId = "s1", events = {} }
end
A.V2CombatReset()
A.V2CombatTick({ id = "lot2", status = "active" })
check(calls == 0, "disabled by default, zero native reads")
A.db, A.run, AzerothStatsDB = nil, nil, nil
check(A.InitDB(), "database initializes")
local store = A.V2Store(true)
store.preferences.combatIntelligence = true
local active = { id = "lot2", status = "active" }
A.V2CombatTick(active)
check(calls == 1 and A.V2CombatSnapshot().hits == 0, "subscribe at tail, no historic events")
local cursorSeen
_G.AZS_GetCombatTextEvents = function(cursor)
    cursorSeen = cursor
    return {
        apiVersion = 1,
        streamId = "s1",
        cursor = "next",
        droppedCount = 2,
        events = {
            {
                kind = "damage",
                amount = 123,
                meterSourceKey = "spell:1",
                schoolMask = 4,
                critical = true,
            },
            { kind = "miss", result = { key = "dodge" } },
            { kind = "damage", amount = 30, periodic = true, sourceKind = "pet" },
        },
    }
end
A.V2CombatTick(active)
local s = A.V2CombatSnapshot()
check(cursorSeen == "tail", "independent cursor carried forward")
check(s.hits == 2 and s.misses == 1 and s.damageObserved == 153, "hits, misses and amount")
check(s.critical == 1 and s.periodic == 1 and s.dropped == 2, "flags and losses")
check(s.sources["spell:1"].damage == 123, "source aggregation")
check(s.schools["4"].damage == 123, "school aggregation")
_G.AZS_GetCombatTextEvents = function()
    return nil, { code = "STREAM_CHANGED" }
end
A.V2CombatTick(active)
check(A.V2CombatSnapshot().gaps == 1, "stream reset recorded")
_G.AZS_GetCombatTextEvents = function(cursor)
    return { apiVersion = 1, streamId = "s2", cursor = "new", events = {} }
end
A.V2CombatTick(active)
check(A.V2CombatSnapshot().hits == 2, "new stream does not overwrite observations")
-- Exercise the real V2 transactional store using a retained run identity.
active.values = { duration = 30 }
table.insert(A.db.runs, active)
A.V2CombatTick(active)
local persisted = A.V2Store(false).runs[active.id]
check(
    persisted and persisted.combatIntelligence and persisted.combatIntelligence.hits == 2,
    "bounded run checkpoint persists"
)
check(persisted.combatIntelligence.dropped == 2, "loss flags persist")
table.remove(A.db.runs)
A.V2CombatTick(nil)
check(A.V2CombatSnapshot() == nil, "inactive run clears volatile state")
check(store.schema == 1, "schema-1 retained")
-- Synthetic sustained backlog: never exceed the 8-page / 2048-event tick budget.
local events = {}
for i = 1, 256 do
    events[i] = { kind = "damage", amount = 1, meterSourceKey = "stress" }
end
local page = 0
_G.AZS_GetCombatTextEvents = function()
    page = page + 1
    return {
        apiVersion = 1,
        cursor = "p" .. page,
        streamId = "stress",
        events = events,
        hasMore = true,
    }
end
A.V2CombatTick({ id = "stress", status = "active" })
check(page == 8, "hard limit of eight native reads per tick")
check(A.V2CombatSnapshot().hits == 2048, "all 2048 bounded events aggregated")
check(A.V2CombatSnapshot().truncated == true, "remaining backlog explicitly flagged")
A.V2CombatTick(nil)
-- Malformed server pages must be bounded and flagged, never treated as complete.
local oversized = {}
for i = 1, 300 do
    oversized[i] = { kind = "damage", amount = 1, meterSourceKey = "overflow" }
end
_G.AZS_GetCombatTextEvents = function()
    return {
        apiVersion = 1,
        cursor = "oversized",
        streamId = "oversized",
        droppedCount = -5,
        events = oversized,
    }
end
A.V2CombatTick({ id = "oversized", status = "active" })
local malformed = A.V2CombatSnapshot()
check(malformed.hits == 256, "oversized page capped to 256 events")
check(malformed.truncated == true and malformed.invalid >= 2, "malformed page and drop count flagged")
check(malformed.dropped == 0, "negative drop counter cannot reduce losses")
A.V2CombatTick(nil)
_G.AZS_GetCombatTextEvents = original
A.db, A.run, AzerothStatsDB = db, run, saved
A.V2Invalidate()
print("V2 LOT 2 COMBAT OBSERVER PASSED")

-- RESEARCH ONLY. No game addon loader or real data is modified.
local A = AzerothStats
local M = SharedBackupResearch
local function check(ok, name)
    assert(ok, name)
    TEST_COUNT = TEST_COUNT + 1
end
local priorSaved, priorDB, priorRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "research fixture initialized")
local db = A.db
db.runs = {
    {
        id = "research-run-one",
        class = "warrior",
        values = { damage = 42 },
        accounted = {},
        events = {},
        meters = {},
        note = "original",
    },
    {
        id = "research-run-two",
        class = "mage",
        values = { damage = 19 },
        accounted = {},
        events = {},
        meters = {},
    },
}
check(A.ValidateDatabase(db), "two real-schema synthetic runs validate")
local store = M.new()
local id1, err1 = M.save(store, db, false)
check(id1 ~= nil and not err1, "first manual checkpoint")
check(type(store.entries[id1].state) == "table", "checkpoint has full other state")
check(type(store.entries[id1].state.runs) == "nil", "run list not repeated in other state")
local first, err = M.restore(store, id1)
check(first ~= nil and not err, "first checkpoint can restore")
check(
    SNAPSHOT(first) == SNAPSHOT(db) or A.ValidateDatabase(first),
    "reconstructed checkpoint has valid shape"
)
local priorSeq = db.sequence
db.sequence = priorSeq + 1
db.runs[1].note = "later edit"
db.runs[3] = {
    id = "research-run-three",
    class = "warrior",
    values = { damage = 99 },
    accounted = {},
    events = {},
    meters = {},
}
local id2 = M.save(store, db, true)
check(id2 ~= nil, "auto checkpoint created")
local old = M.restore(store, id1)
local newer = M.restore(store, id2)
check(old.sequence == priorSeq, "older checkpoint preserves prior sequence")
check(newer.sequence == priorSeq + 1, "newer checkpoint preserves changed sequence")
check(old.runs[1].note == "original" and #old.runs == 2, "old run versions preserved")
check(newer.runs[1].note == "later edit" and #newer.runs == 3, "new run versions included")
check(store.pool[1] ~= nil and store.pool[2] ~= nil, "shared pool populated")
check(store.entries[id1].state.runs == nil, "run histories never duplicated in checkpoints")
check(
    store.entries[id1].runRefs[2] == store.entries[id2].runRefs[2],
    "identical run explicitly shared across checkpoint types"
)
check(M.delete(store, id1), "old manual checkpoint can be deleted")
local removed = M.collect(store)
check(removed == 1, "GC removes only old unreferenced edited run version")
check(M.restore(store, id2).sequence == priorSeq + 1, "auto remains intact")
check(
    M.restore(store, id2).runs[2].id == "research-run-two",
    "shared surviving run remains accessible"
)
check(M.restore(store, id1) == nil, "deleted checkpoint unavailable")
local tampered = store.entries[id2]
tampered.runRefs = { 999999 }
check(M.restore(store, id2) == nil, "missing pool reference fails closed")
check(M.collect(store) == nil, "broken reference blocks garbage collection")
check(A.db == db, "research restore never changes active DB pointer")
AzerothStatsDB, A.db, A.run = priorSaved, priorDB, priorRun
print("SHARED BACKUP LUA RESEARCH CONTRACTS PASSED")

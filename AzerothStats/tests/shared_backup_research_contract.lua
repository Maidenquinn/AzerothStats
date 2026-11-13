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
local id2 = M.save(store, db, true)
check(id2 ~= nil, "auto checkpoint created")
local old = M.restore(store, id1)
local newer = M.restore(store, id2)
check(old.sequence == priorSeq, "older checkpoint preserves prior sequence")
check(newer.sequence == priorSeq + 1, "newer checkpoint preserves changed sequence")
check(M.delete(store, id1), "old manual checkpoint can be deleted")
check(M.collect(store) ~= nil, "garbage collector can run after deletion")
check(M.restore(store, id2).sequence == priorSeq + 1, "auto remains intact")
check(M.restore(store, id1) == nil, "deleted checkpoint unavailable")
local tampered = store.entries[id2]
tampered.runRefs = { 999999 }
check(M.restore(store, id2) == nil, "missing pool reference fails closed")
check(M.collect(store) == nil, "broken reference blocks garbage collection")
check(A.db == db, "research restore never changes active DB pointer")
AzerothStatsDB, A.db, A.run = priorSaved, priorDB, priorRun
print("SHARED BACKUP LUA RESEARCH CONTRACTS PASSED")

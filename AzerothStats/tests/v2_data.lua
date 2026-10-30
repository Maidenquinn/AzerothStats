-- Synthetic extension tests only. No native saves or real game state are read.
local A = AzerothStats
local oldDatabase, oldDB, oldRun, oldStats = AzerothStatsDB, A.db, A.run, AZS_STATS
local oldPacket = A.statsPacket
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "V2 data: " .. label)
end
AzerothStatsDB = nil
check(A.InitDB(), "fresh schema-1 base")
check(
    A.db.schema == 1 and A.V2Store(false) == nil,
    "opening does not create an independent database"
)
local run = {
    id = "azstats-1",
    class = "warrior",
    hero = "Synthetic",
    status = "active",
    values = { duration = 15 },
    accounted = {},
    meters = {},
    events = {},
}
table.insert(A.db.runs, run)
A.run = run
AZS_STATS = {
    echo = 0,
    thn = 0.15,
    pick = 8.2,
    gpick = 1.26,
    pet = 0.3,
    malformed = {},
    big = "invalid",
    cc = math.huge,
}
A.statsPacket = nil
A.ObserveV2(run)
check(A.V2Store(false) == nil, "no stale native stats imported")
A.statsPacket = true
local before = A.Sign(run)
A.ObserveV2(run)
local entry = A.V2Store(false).runs[run.id]
check(
    entry.latest.echo == 0 and entry.latest.pet == 0.3,
    "explicit zero and advanced stat retained"
)
check(entry.latest.pick == 8.2 and entry.latest.gpick == 1.26, "different pickup units remain raw")
check(entry.latest.big == nil and entry.latest.cc == nil, "malformed and infinite counters omitted")
check(A.Sign(run) == before, "extension writer does not change common run ledger")
A.ObserveV2(run)
check(table.getn(entry.samples) == 1, "repeated native sample is idempotent")
for i = 2, 38 do
    run.values.duration = i * 15
    A.ObserveV2(run)
end
entry = A.V2Store(false).runs[run.id]
check(table.getn(entry.samples) == 32 and entry.truncated, "bounded history signals truncation")
check(A.ValidateDatabase(A.db), "V1 database validator accepts real extension")
local store = A.V2Store(false)
store.schema = 99
before = A.Sign(store)
run.values.duration = 1000
A.ObserveV2(run)
check(A.V2Store(true) == nil and A.Sign(store) == before, "future version remains untouched")
store.schema = 1
A.db.runs = {}
A.V2Reconcile()
check(
    store.runs[run.id] == nil and table.getn(A.db.runs) == 0,
    "purge never resurrects common runs"
)
A.db.extensions.otherAddon = { preserved = true }
A.V2Reset()
check(
    A.db.extensions.azerothStatsV2 == nil and A.db.extensions.otherAddon.preserved,
    "explicit reset clears only our namespace"
)
AzerothStatsDB, A.db, A.run, AZS_STATS = oldDatabase, oldDB, oldRun, oldStats
A.statsPacket = oldPacket
print("V2 SHARED DATA FOUNDATION PASSED", TEST_COUNT)

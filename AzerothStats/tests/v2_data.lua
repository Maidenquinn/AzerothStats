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
for i = 1, 34 do
    local item = {
        id = "azstats-" .. i,
        class = "warrior",
        zone = "elwynn",
        heroic = 0,
        startedAt = i,
        status = "active",
        values = { duration = 15 },
        accounted = {},
        events = {},
        meters = {},
    }
    table.insert(A.db.runs, item)
    A.run, A.statsPacket = item, true
    A.ObserveV2(item)
    check(A.V2RunData(item).latest ~= nil, "new runs continue collecting after the cache fills")
    item.status = "ended"
    if i == 1 then
        A.ToggleFavorite(A.RunFavorite(item))
    end
    if i == 2 then
        check(A.V2SetNote(item.id, "Keep this note"), "note on old run stored")
    end
end
store = A.V2Store(false)
check(store.runs["azstats-1"].latest ~= nil, "favorite observations protected from expiry")
check(
    store.runs["azstats-2"].expired and store.runs["azstats-2"].note == "Keep this note",
    "expiry preserves local notes"
)
check(
    table.getn(A.db.runs) == 34 and A.V2Retention() == 32,
    "bounded advanced cache preserves common history"
)
local bad = { affixesRaw = {}, reviveState = 4, supportSequence = "bad", maxSummons = {} }
for key, value in pairs(bad) do
    local entry = store.runs["azstats-34"]
    local previous = entry[key]
    entry[key] = value
    A.V2Invalidate()
    check(A.V2Store(false) == nil, "malformed saved field rejected: " .. key)
    entry[key] = previous
    A.V2Invalidate()
end
check(A.V2Store(false) ~= nil, "invalid input is preserved rather than destructively repaired")
AzerothStatsDB, A.db, A.run, AZS_STATS = oldDatabase, oldDB, oldRun, oldStats
A.statsPacket = oldPacket
print("V2 SHARED DATA FOUNDATION PASSED", TEST_COUNT)

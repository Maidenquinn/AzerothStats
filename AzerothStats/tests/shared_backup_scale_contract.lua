-- Synthetic larger histories: count versions, restored data and no aliasing.
local A, M = AzerothStats, SharedBackupResearch
local function check(ok, label)
    assert(ok, label)
    TEST_COUNT = TEST_COUNT + 1
end
local priorSaved, priorDB, priorRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "scale fixture initializes")
local db = A.db
local function countKeys(values)
    local total = 0
    for _ in pairs(values) do
        total = total + 1
    end
    return total
end
for _, count in ipairs({ 100, 500, 1000 }) do
    db.runs = {}
    for index = 1, count do
        db.runs[index] = {
            id = "scale-" .. index,
            class = "warrior",
            values = { damage = index * 15, duration = 240 },
            accounted = {},
            events = {},
            meters = {},
            note = "initial",
        }
    end
    db.sequence = count
    local store = M.new()
    local first = M.save(store, db, false)
    check(first ~= nil, "scale first save at " .. count)
    check(countKeys(store.pool) == count, "initial pool exactly " .. count)
    local originalFirst = M.restore(store, first)
    db.runs[count].note = "edited after initial backup"
    db.sequence = count + 1
    local second = M.save(store, db, true)
    check(second ~= nil, "scale auto save at " .. count)
    check(countKeys(store.pool) == count + 1, "only changed run version added " .. count)
    check(M.sameData(M.restore(store, first), originalFirst), "old snapshot exact " .. count)
    check(M.sameData(M.restore(store, second), db), "new snapshot exact " .. count)
    db.totals.wins = db.totals.wins + 1
    local third = M.save(store, db, false)
    check(third ~= nil, "non-run change can be snapshotted " .. count)
    check(countKeys(store.pool) == count + 1, "non-run change shares all run versions " .. count)
    check(M.sameData(M.restore(store, third), db), "non-run totals exact " .. count)
    check(M.delete(store, first), "remove first snapshot " .. count)
    check(M.collect(store) == 1, "remove orphaned run version " .. count)
    check(M.sameData(M.restore(store, second), originalFirst) == false,
        "later snapshot retains changed run " .. count)
end
AzerothStatsDB, A.db, A.run = priorSaved, priorDB, priorRun
print("SHARED BACKUP SYNTHETIC SCALE CONTRACTS PASSED")

-- Synthetic Lua-table byte proxy. Not native SavedVariables serialization.
local A, M = AzerothStats, SharedBackupResearch
local function check(ok, label)
    assert(ok, label)
    TEST_COUNT = TEST_COUNT + 1
end
local previousSaved, previousDB, previousRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "byte proxy fixture starts")
local db = A.db
local function frozen()
    local scratch = M.new()
    local id = M.save(scratch, db, false)
    assert(id)
    return assert(M.restore(scratch, id))
end
for _, count in ipairs({ 100, 500, 1000 }) do
    db.runs = {}
    for index = 1, count do
        db.runs[index] = {
            id = "synthetic-" .. index,
            class = "warrior",
            values = { damage = index * 15, duration = 300 },
            accounted = {},
            events = {
                { kind = "start", text = "begin" },
                { kind = "level", text = "level gained" },
            },
            meters = {},
            note = string.rep("fictional note-", 12),
        }
    end
    db.sequence = count
    local first = frozen()
    db.sequence = count + 1
    local second = frozen()
    db.sequence = count + 2
    local automatic = frozen()
    local manualRoot = {
        schema = 2,
        nextId = 3,
        entries = {
            { id = 1, at = 100, data = first },
            { id = 2, at = 200, data = second },
        },
    }
    local autoRoot = {
        schema = 2,
        nextId = 2,
        entries = { { id = 1, at = 300, data = automatic } },
    }
    local before = string.len(SNAPSHOT(manualRoot)) + string.len(SNAPSHOT(autoRoot))
    local shared = M.importLegacy(db, manualRoot, autoRoot)
    check(shared ~= nil, "proxy migration succeeds at " .. count)
    check(M.verifyMigration(shared, db, manualRoot, autoRoot), "proxy parity at " .. count)
    local after = string.len(SNAPSHOT(shared))
    check(after < before, "shared proxy bytes smaller at " .. count)
    print(
        "SHARED SNAPSHOT LUA SERIALIZATION PROXY",
        count,
        "legacy-bytes",
        before,
        "shared-bytes",
        after
    )
end
AzerothStatsDB, A.db, A.run = previousSaved, previousDB, previousRun

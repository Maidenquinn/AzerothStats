-- Legacy backup migration contracts. Synthetic Lua fixtures only.
local A, M = AzerothStats, SharedBackupResearch
local function check(ok, name)
    assert(ok, name)
    TEST_COUNT = TEST_COUNT + 1
end
local previousSaved, previousDB, previousRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "migration fixture starts")
local db = A.db
db.runs = {
    {
        id = "fixture-1",
        class = "warrior",
        values = { damage = 15 },
        accounted = {},
        events = {},
        meters = {},
        note = "first",
    },
    {
        id = "fixture-2",
        class = "mage",
        values = { damage = 20 },
        accounted = {},
        events = {},
        meters = {},
    },
}
check(A.ValidateDatabase(db), "migration fixture valid")
local function makeSource(sequence, note)
    local source = {}
    for k, v in pairs(db) do
        source[k] = v
    end
    local copied, err = M.restore((function()
        local temporary = M.new()
        local id = M.save(temporary, db, false)
        return temporary, id
    end)(), 1)
    -- Above would be a copy only if the temporary manifest is valid.
    assert(copied ~= nil and not err)
    copied.sequence = sequence
    copied.runs[1].note = note
    return copied
end
local first = makeSource(11, "old note")
local second = makeSource(12, "updated note")
local auto = makeSource(13, "updated note")
auto.runs[2].values.damage = 21
local manualRoot = {
    schema = 2,
    nextId = 9,
    entries = {
        { id = 3, at = 112, runs = 2, data = first },
        { id = 8, at = 114, runs = 2, data = second },
    },
}
local autoRoot = {
    schema = 2,
    nextId = 4,
    entries = { { id = 3, at = 115, runs = 2, data = auto } },
}
local originalManual, originalAuto = manualRoot, autoRoot
local oldRun, newerRun, autoRun = first.runs[1], second.runs[1], auto.runs[1]
local migrated, err = M.importLegacy(db, manualRoot, autoRoot)
check(migrated ~= nil and not err, "manual and auto stores migrate together")
check(migrated.sourceNextIds.manual == 9 and migrated.sourceNextIds.auto == 4,
    "separate manual and automatic sequence counters retained")
check(manualRoot == originalManual and autoRoot == originalAuto,
    "legacy store roots not replaced during research migration")
check(first.runs[1] == oldRun and second.runs[1] == newerRun and auto.runs[1] == autoRun,
    "original source run tables not rewritten")
local m1 = M.findOrigin(migrated, "manual", 3)
local m2 = M.findOrigin(migrated, "manual", 8)
local a1 = M.findOrigin(migrated, "auto", 3)
check(m1 and m2 and a1 and m1 ~= a1, "duplicate legacy IDs isolated across store types")
check(M.findOrigin(migrated, "manual", 4) == nil, "unknown original ID never guessed")
check(M.sameData(M.restore(migrated, m1), first), "first manual database restored exactly")
check(M.sameData(M.restore(migrated, m2), second), "second manual database restored exactly")
check(M.sameData(M.restore(migrated, a1), auto), "automatic database restored exactly")
check(migrated.entries[m1].origin.at == 112 and migrated.entries[m2].origin.at == 114
    and migrated.entries[a1].origin.at == 115,
    "original timestamps kept")
check(migrated.entries[m1].runRefs[2] == migrated.entries[m2].runRefs[2],
    "unchanged second run shared between manual checkpoints")
check(migrated.entries[m2].runRefs[2] ~= migrated.entries[a1].runRefs[2],
    "modified second run receives a new version in automatic checkpoint")
check(migrated.entries[m2].runRefs[1] == migrated.entries[a1].runRefs[1],
    "updated run version shared between manual and auto")
local originalNote = first.runs[1].note
local loaded = M.restore(migrated, m1)
loaded.runs[1].note = "unrelated restore edit"
check(first.runs[1].note == originalNote and
    M.restore(migrated, m1).runs[1].note == originalNote,
    "restore cannot mutate source or shared pool")
local legacy = { schema = 1, data = first }
local legacyStore = M.importLegacy(db, legacy, nil)
check(legacyStore and legacyStore.sourceNextIds.manual == 2
    and legacyStore.sourceNextIds.auto == 1,
    "single-slot schema 1 and missing auto root supported")
local legacyId = M.findOrigin(legacyStore, "manual", 1)
check(legacyId and legacyStore.entries[legacyId].origin.legacy,
    "single-slot entry carries legacy flag")
check(M.sameData(M.restore(legacyStore, legacyId), first),
    "single-slot roundtrip exact")
local empty = M.importLegacy(db, nil, nil)
check(empty and next(empty.entries) == nil, "missing backup roots produce empty catalogue")
local invalidRoot = { schema = 2, nextId = 4, entries = {
    { id = 3, data = first }, { id = 3, data = second },
} }
check(M.importLegacy(db, manualRoot, invalidRoot) == nil,
    "duplicate source IDs reject entire transaction")
check(M.importLegacy(db, { schema = 3, entries = {} }, autoRoot) == nil,
    "unknown source schema rejected")
check(M.importLegacy(db, { schema = 2, nextId = 2, entries = {
    [2] = { id = 1, data = first },
} }, autoRoot) == nil, "sparse source catalogue rejected")
local badRoot = { schema = 2, nextId = 2, entries = { { id = 1,
    data = { broken = true },
} } }
check(M.importLegacy(db, badRoot, autoRoot) == nil,
    "invalid snapshot aborts migration before publication")
check(M.importLegacy({ invalid = true }, manualRoot, autoRoot) == nil,
    "invalid live database refuses migration")
check(first.runs[1].note == "old note" and second.runs[1].note == "updated note",
    "failed migrations never rewrite source data")
check(A.db == db and AzerothStatsDB == db, "live SavedVariables root unchanged")
AzerothStatsDB, A.db, A.run = previousSaved, previousDB, previousRun
print("LEGACY BACKUP MIGRATION RESEARCH CONTRACTS PASSED")

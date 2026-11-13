-- Legacy backup migration: synthetic databases only; no real save file access.
local A, M = AzerothStats, SharedBackupResearch
local function check(ok, label)
    assert(ok, label)
    TEST_COUNT = TEST_COUNT + 1
end
local previousSaved, previousDB, previousRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "migration fixture initializes")
local db = A.db
db.runs = {
    {
        id = "fixture-one",
        class = "warrior",
        values = { damage = 15 },
        accounted = {},
        events = {},
        meters = {},
        note = "original",
    },
    {
        id = "fixture-two",
        class = "mage",
        values = { damage = 20 },
        accounted = {},
        events = {},
        meters = {},
    },
}
check(A.ValidateDatabase(db), "run fixture passes real DB validator")

local fixtureStore = M.new()
local fixtureID = M.save(fixtureStore, db, false)
check(fixtureID ~= nil, "fixture copied safely")
local function version(sequence, note)
    local copied = M.restore(fixtureStore, fixtureID)
    assert(copied)
    copied.sequence = sequence
    copied.runs[1].note = note
    return copied
end

local first = version(11, "old note")
local second = version(12, "updated note")
local automatic = version(13, "updated note")
automatic.runs[2].values.damage = 21
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
    entries = { { id = 3, at = 115, runs = 2, data = automatic } },
}
local oldFirstRun, oldSecondRun, oldAutoRun = first.runs[1], second.runs[1], automatic.runs[1]
local migrated, err = M.importLegacy(db, manualRoot, autoRoot)
check(migrated and not err, "manual and automatic catalogues migrate together")
check(migrated.sourceNextIds.manual == 9, "manual next ID remains distinct")
check(migrated.sourceNextIds.auto == 4, "automatic next ID remains distinct")
check(first.runs[1] == oldFirstRun, "first source run pointer unchanged")
check(second.runs[1] == oldSecondRun, "second source run pointer unchanged")
check(automatic.runs[1] == oldAutoRun, "automatic source run pointer unchanged")

local m1 = M.findOrigin(migrated, "manual", 3)
local m2 = M.findOrigin(migrated, "manual", 8)
local a1 = M.findOrigin(migrated, "auto", 3)
check(m1 and m2 and a1, "all old snapshot IDs mapped")
check(m1 ~= a1, "manual and auto IDs do not collide")
check(M.findOrigin(migrated, "manual", 4) == nil, "missing source IDs stay missing")
check(M.sameData(M.restore(migrated, m1), first), "first manual restored exactly")
check(M.sameData(M.restore(migrated, m2), second), "second manual restored exactly")
check(M.sameData(M.restore(migrated, a1), automatic), "automatic restored exactly")
-- Simulate the client's save/reload serialization, not just in-memory pointers.
local savedText = SNAPSHOT(migrated)
local parse = assert(loadstring("return " .. savedText))
local reloaded = parse()
check(M.sameData(M.restore(reloaded, m1), first), "old manual survives serialization")
check(M.sameData(M.restore(reloaded, m2), second), "new manual survives serialization")
check(M.sameData(M.restore(reloaded, a1), automatic), "auto survives serialization")
local verified, verifyError = M.verifyMigration(reloaded, db, manualRoot, autoRoot)
check(verified and not verifyError, "all original backups verified after save/reload")
local oldTimestamp = reloaded.entries[a1].origin.at
reloaded.entries[a1].origin.at = oldTimestamp + 1
check(
    not M.verifyMigration(reloaded, db, manualRoot, autoRoot),
    "metadata tampering detected after reload"
)
reloaded.entries[a1].origin.at = oldTimestamp
check(
    M.verifyMigration(reloaded, db, manualRoot, autoRoot),
    "metadata repair restores complete verification"
)

local sharedRef = reloaded.entries[a1].runRefs[2]
local sharedRun = reloaded.pool[sharedRef]
local originalDamage = sharedRun.values.damage
sharedRun.values.damage = originalDamage + 1
check(M.restore(reloaded, a1) == nil, "valid-shape run corruption detected")
sharedRun.values.damage = originalDamage
check(M.sameData(M.restore(reloaded, a1), automatic), "run repair restores access")
local originalSequence = reloaded.entries[m1].state.sequence
reloaded.entries[m1].state.sequence = originalSequence + 1
check(M.restore(reloaded, m1) == nil, "valid-shape state corruption detected")
reloaded.entries[m1].state.sequence = originalSequence
check(M.sameData(M.restore(reloaded, m1), first), "state repair restores access")

check(migrated.entries[m1].origin.at == 112, "first timestamp preserved")
check(migrated.entries[m2].origin.at == 114, "second timestamp preserved")
check(migrated.entries[a1].origin.at == 115, "auto timestamp preserved")
local firstRefs = migrated.entries[m1].runRefs
local secondRefs = migrated.entries[m2].runRefs
local autoRefs = migrated.entries[a1].runRefs
check(firstRefs[2] == secondRefs[2], "unchanged run shared between manual snapshots")
check(secondRefs[1] == autoRefs[1], "unchanged run shared across backup types")
check(secondRefs[2] ~= autoRefs[2], "changed run version never reused")

local modified = M.restore(migrated, m1)
modified.runs[1].note = "local change"
check(first.runs[1].note == "old note", "restore cannot edit old source")
check(M.restore(migrated, m1).runs[1].note == "old note", "shared pool stays immutable")
check(db.runs[1].note == "original", "live history untouched")

local schemaOne = { schema = 1, data = first }
local single = M.importLegacy(db, schemaOne, nil)
check(single ~= nil, "legacy schema 1 migrates")
check(single.sourceNextIds.manual == 2, "legacy next manual ID preserved")
check(single.sourceNextIds.auto == 1, "missing auto root accepted")
local legacyID = M.findOrigin(single, "manual", 1)
check(legacyID ~= nil, "legacy ID remains discoverable")
check(single.entries[legacyID].origin.legacy, "legacy flag preserved")
check(M.sameData(M.restore(single, legacyID), first), "legacy backup restored exactly")
local empty = M.importLegacy(db, nil, nil)
check(empty and next(empty.entries) == nil, "missing backup roots accepted")

local duplicates = {
    schema = 2,
    nextId = 4,
    entries = { { id = 3, data = first }, { id = 3, data = second } },
}
check(M.importLegacy(db, manualRoot, duplicates) == nil, "duplicate IDs rejected")
check(M.importLegacy(db, { schema = 3 }, autoRoot) == nil, "unknown schema rejected")
local sparse = {
    schema = 2,
    nextId = 2,
    entries = { [2] = { id = 1, data = first } },
}
check(M.importLegacy(db, sparse, autoRoot) == nil, "sparse catalogue rejected")
local corrupt = {
    schema = 2,
    nextId = 2,
    entries = { { id = 1, data = { broken = true } } },
}
check(M.importLegacy(db, corrupt, autoRoot) == nil, "corrupt backup refuses migration")
local unknownRoot = {
    schema = 2,
    nextId = 2,
    entries = { { id = 1, data = first } },
    newFeature = "unknown",
}
check(M.importLegacy(db, unknownRoot, nil) == nil, "unknown root metadata rejects lossy migration")
local unknownEntry = {
    schema = 2,
    nextId = 2,
    entries = { { id = 1, data = first, protectedFlag = true } },
}
check(M.importLegacy(db, unknownEntry, nil) == nil, "unknown entry metadata rejects lossy migration")
check(M.importLegacy(db, { schema = 1, data = first, extra = true }, nil) == nil,
    "unexpected legacy schema field rejected")
check(M.importLegacy({ invalid = true }, manualRoot, autoRoot) == nil, "invalid live DB refused")
check(first.runs[1].note == "old note", "failed conversions preserve old source")
check(A.db == db, "migration never installs a database")
AzerothStatsDB, A.db, A.run = previousSaved, previousDB, previousRun
print("LEGACY BACKUP MIGRATION RESEARCH CONTRACTS PASSED")

-- Migration fault-injection and two-start journal research; synthetic only.
local A, M, J = AzerothStats, SharedBackupResearch, SharedBackupMigrationJournalResearch
local function check(ok, name)
    assert(ok, name)
    TEST_COUNT = TEST_COUNT + 1
end
local oldSaved, oldDB, oldRun = AzerothStatsDB, A.db, A.run
AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "journal isolated fixture initialized")
local db = A.db
db.runs = {
    {
        id = "migration-run",
        class = "warrior",
        values = { damage = 7 },
        accounted = {},
        events = {},
        meters = {},
    },
}
local original = M.new()
local snapshotID = M.save(original, db, false)
local source = assert(M.restore(original, snapshotID))
local manual = {
    schema = 2,
    nextId = 3,
    entries = { { id = 2, at = 123, data = source } },
}
local preservedDB, preservedManual = db, manual
local staged = assert(J.prepare(db, manual, nil, "start-1"))
check(staged.phase == "staged", "prepare creates a staging journal")
check(db == preservedDB and manual == preservedManual, "prepare never replaces source pointers")
check(J.preview(staged).eligibleToDeleteLegacy == false, "staged cannot delete old saves")
check(not J.verifyReload(staged, db, manual, nil, "start-1"), "same-session bypass rejected")
check(staged.phase == "staged", "failed verification does not mutate phase")
local text = SNAPSHOT(staged)
local reloaded = assert(loadstring("return " .. text))()
check(J.verifyReload(reloaded, db, manual, nil, "start-2"), "independent session can verify")
check(reloaded.phase == "verified", "journal records verified state")
local report = J.preview(reloaded)
check(report.verified and report.checkpoints == 1, "read-only verification report available")
check(report.eligibleToDeleteLegacy == false, "verified is never delete permission")
check(
    M.sameData(M.restore(reloaded.shadow, M.findOrigin(reloaded.shadow, "manual", 2)), source),
    "source backup fully reconstructable after simulated restart"
)

local changed = assert(loadstring("return " .. text))()
db.sequence = db.sequence + 1
check(
    not J.verifyReload(changed, db, manual, nil, "start-2"),
    "a changed live root blocks migration verification"
)
db.sequence = db.sequence - 1
check(changed.phase == "staged", "source mismatch never marks migration verified")
source.runs[1].values.damage = source.runs[1].values.damage + 1
check(
    not J.verifyReload(changed, db, manual, nil, "start-2"),
    "changed legacy snapshot blocks verification"
)
source.runs[1].values.damage = source.runs[1].values.damage - 1

local corrupt = assert(loadstring("return " .. text))()
local id = M.findOrigin(corrupt.shadow, "manual", 2)
local ref = corrupt.shadow.entries[id].runRefs[1]
corrupt.shadow.pool[ref].values.damage = corrupt.shadow.pool[ref].values.damage + 1
check(
    not J.verifyReload(corrupt, db, manual, nil, "start-2"),
    "corrupted shared pool blocks verification"
)
check(corrupt.phase == "staged", "corrupted shared store remains staged")

local incomplete = assert(loadstring("return " .. text))()
incomplete.shadow.entries[id] = nil
check(
    not J.verifyReload(incomplete, db, manual, nil, "start-2"),
    "partially written shadow manifest blocks verification"
)

local abandoned = assert(loadstring("return " .. text))()
check(J.abort(abandoned), "interrupted staging can be discarded")
check(abandoned.phase == "aborted" and abandoned.shadow == nil, "shadow only removed")
check(db == preservedDB and manual == preservedManual, "abort preserves original roots")
check(
    not J.verifyReload(abandoned, db, manual, nil, "start-2"),
    "aborted migration cannot be verified"
)
check(J.abort(abandoned), "abort is idempotent")
check(J.abort(reloaded), "verified journal can be discarded without touching sources")
check(db == preservedDB and manual == preservedManual, "verified abort preserves old roots")
check(J.prepare(db, manual, nil, "") == nil, "missing session token rejected")
local damagedRoot = assert(loadstring("return " .. text))()
damagedRoot.shadow.digests = nil
check(not J.verifyReload(damagedRoot, db, manual, nil, "start-2"),
    "missing digest root refuses reload verification")
check(M.restore({ schema = 1 }, 1) == nil, "invalid store restore fails closed")
check(M.save({ schema = 1 }, db, false) == nil, "invalid store save fails closed")
check(M.collect({ schema = 1 }) == nil, "invalid store GC fails closed")
check(M.findOrigin({ schema = 1 }, "manual", 2) == nil,
    "invalid store lookup fails closed")
check(not M.delete({ schema = 1 }, 2), "invalid store deletion fails closed")
AzerothStatsDB, A.db, A.run = oldSaved, oldDB, oldRun
print("NON-DESTRUCTIVE MIGRATION JOURNAL CONTRACTS PASSED")

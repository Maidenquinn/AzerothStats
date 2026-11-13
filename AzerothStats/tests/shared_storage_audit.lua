-- Read-only alpha command contracts. No migration or storage writes.
local A = AzerothStats
local function check(ok, label)
    assert(ok, label)
    TEST_COUNT = TEST_COUNT + 1
end

local savedManual, savedAuto, savedDB = AzerothStatsBackup, AzerothStatsAutoBackup, A.db
local function run(id)
    return { id = id, status = "ended" }
end
local db = { runs = { run("active-one") } }
A.db = db
AzerothStatsBackup = {
    schema = 2,
    nextId = 4,
    entries = {
        { id = 2, data = { runs = { run("one"), run("two") } } },
        { id = 3, data = { runs = { run("one"), run("three") } } },
    },
}
AzerothStatsAutoBackup = {
    schema = 1,
    data = { runs = { run("one"), run("three") } },
}
local manualPtr, autoPtr = AzerothStatsBackup, AzerothStatsAutoBackup
local firstPtr = manualPtr.entries[1]
local beforeManual, beforeAuto = SNAPSHOT(manualPtr), SNAPSHOT(autoPtr)
local inventory = A.SharedStorageReadOnlyAudit()
check(inventory.nonDestructive, "audit reports read-only operation")
check(inventory.activeRuns == 1, "reports active runs")
check(inventory.manual.snapshots == 2 and inventory.manual.storedRuns == 4, "manual counts")
check(inventory.manual.distinctRunIDs == 3, "manual unique IDs")
check(inventory.manual.repeatedRunIDs == 1, "manual repeated IDs")
check(inventory.automatic.snapshots == 1 and inventory.automatic.storedRuns == 2, "legacy auto counts")
check(not inventory.exactDeduplicatedBytesKnown, "does not claim byte savings")
check(AzerothStatsBackup == manualPtr and AzerothStatsAutoBackup == autoPtr,
    "audit never replaces SavedVariables root pointers")
check(AzerothStatsBackup.entries[1] == firstPtr, "entry pointer unchanged")
check(SNAPSHOT(manualPtr) == beforeManual and SNAPSHOT(autoPtr) == beforeAuto,
    "audit never changes backup bytes")

AzerothStatsBackup = nil
AzerothStatsAutoBackup = nil
local missing = A.SharedStorageReadOnlyAudit()
check(missing.manual.snapshots == 0 and missing.automatic.snapshots == 0, "missing stores safe")
check(AzerothStatsBackup == nil and AzerothStatsAutoBackup == nil,
    "missing stores are not created")
AzerothStatsBackup = { schema = 999 }
local unknown = A.SharedStorageReadOnlyAudit()
check(unknown.manual.invalid ~= nil, "unknown source is explicitly flagged")
check(AzerothStatsBackup.schema == 999, "unknown source remains intact")

AzerothStatsBackup, AzerothStatsAutoBackup, A.db = savedManual, savedAuto, savedDB
print("READ-ONLY SHARED STORAGE ALPHA AUDIT CONTRACTS PASSED")

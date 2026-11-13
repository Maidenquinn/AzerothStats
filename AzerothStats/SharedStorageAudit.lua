-- Experimental read-only inspection for a future shared backup format.
-- This module NEVER writes SavedVariables or creates a backup.
local A = AzerothStats

local function scan(root, label)
    local report = {
        name = label,
        snapshots = 0,
        storedRuns = 0,
        distinctRunIDs = 0,
        repeatedRunIDs = 0,
        incompleteRunIDs = 0,
        invalid = nil,
    }
    if root == nil then
        return report
    end
    if type(root) ~= "table" then
        report.invalid = "root is not a table"
        return report
    end
    local entries
    if root.schema == 1 and type(root.data) == "table" then
        entries = { { id = 1, data = root.data } }
    elseif root.schema == 2 and type(root.entries) == "table" then
        entries = root.entries
    else
        report.invalid = "unsupported backup root"
        return report
    end
    local seen = {}
    local maxEntries = 100
    local maxCopies = 100000
    local count = 0
    for key in pairs(entries) do
        if type(key) ~= "number" or key < 1 or key > maxEntries or key ~= math.floor(key) then
            report.invalid = "unexpected entry index"
            return report
        end
        count = count + 1
    end
    if count > maxEntries then
        report.invalid = "too many checkpoints for the read-only scan"
        return report
    end
    for index = 1, count do
        local entry = entries[index]
        if type(entry) ~= "table" or type(entry.data) ~= "table"
            or type(entry.data.runs) ~= "table" then
            report.invalid = "missing backup data or run list"
            return report
        end
        report.snapshots = report.snapshots + 1
        local runs = entry.data.runs
        local n = table.getn(runs)
        if n < 0 or report.storedRuns + n > maxCopies then
            report.invalid = "run count exceeds safe scan budget"
            return report
        end
        for i = 1, n do
            local run = runs[i]
            if type(run) ~= "table" then
                report.invalid = "malformed run"
                return report
            end
            local id = run.id
            if type(id) == "string" and id ~= "" then
                if seen[id] then
                    report.repeatedRunIDs = report.repeatedRunIDs + 1
                else
                    seen[id] = true
                    report.distinctRunIDs = report.distinctRunIDs + 1
                end
            else
                report.incompleteRunIDs = report.incompleteRunIDs + 1
            end
        end
        report.storedRuns = report.storedRuns + n
    end
    return report
end

function A.SharedStorageReadOnlyAudit()
    -- Reading globals directly avoids backupStore(), which can initialize or
    -- normalize old roots and would violate the no-mutation guarantee.
    local manual = scan(AzerothStatsBackup, "Manual")
    local automatic = scan(AzerothStatsAutoBackup, "Automatic")
    return {
        manual = manual,
        automatic = automatic,
        activeRuns = type(A.db) == "table" and type(A.db.runs) == "table"
                and table.getn(A.db.runs)
            or 0,
        nonDestructive = true,
        -- Same run ID is NOT proof of identical content. A run can be edited.
        exactDeduplicatedBytesKnown = false,
    }
end

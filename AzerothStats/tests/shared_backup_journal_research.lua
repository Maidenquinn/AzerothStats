-- Research-only migration journal. Never loaded from the addon TOC.
-- The journal models a two-start process but has NO filesystem API and cannot
-- prove that a real client's SavedVariables were durably written to disk.
local M = SharedBackupResearch
local J = {}

local function sourceDigest(value)
    return M.fingerprint(value)
end

local function sourcesMatch(journal, live, manual, automatic)
    if type(journal.sources) ~= "table" then
        return false
    end
    return journal.sources.live == sourceDigest(live)
        and journal.sources.manual == sourceDigest(manual)
        and journal.sources.auto == sourceDigest(automatic)
end

function J.prepare(live, manual, automatic, sessionToken)
    if type(sessionToken) ~= "string" or sessionToken == "" then
        return nil, "session token required"
    end
    local sources = {
        live = sourceDigest(live),
        manual = sourceDigest(manual),
        auto = sourceDigest(automatic),
    }
    if not sources.live or not sources.manual or not sources.auto then
        return nil, "source fingerprint failed"
    end
    local shadow, err = M.importLegacy(live, manual, automatic)
    if not shadow then
        return nil, err
    end
    local verified, reason = M.verifyMigration(shadow, live, manual, automatic)
    if not verified then
        return nil, reason
    end
    return {
        schema = 1,
        phase = "staged",
        startedSession = sessionToken,
        sources = sources,
        shadow = shadow,
    }
end

function J.verifyReload(journal, live, manual, automatic, sessionToken)
    if type(journal) ~= "table" or journal.schema ~= 1
        or journal.phase ~= "staged" then
        return false, "not a staged journal"
    end
    if type(sessionToken) ~= "string" or sessionToken == ""
        or sessionToken == journal.startedSession then
        return false, "independent session required"
    end
    if not sourcesMatch(journal, live, manual, automatic) then
        return false, "source changed since staging"
    end
    local valid, err = M.verifyMigration(journal.shadow, live, manual, automatic)
    if not valid then
        return false, err
    end
    -- No old-format roots are released here; stage verification is read-only.
    journal.phase = "verified"
    journal.checkedSession = sessionToken
    return true
end

function J.abort(journal)
    if type(journal) ~= "table" or journal.schema ~= 1 then
        return false, "invalid migration journal"
    end
    if journal.phase == "aborted" then
        return true
    end
    if journal.phase ~= "staged" and journal.phase ~= "verified" then
        return false, "migration cannot be aborted"
    end
    journal.phase = "aborted"
    journal.shadow = nil
    -- The caller's old roots are never touched by this test-only helper.
    return true
end

function J.preview(journal)
    if type(journal) ~= "table" or journal.schema ~= 1 then
        return nil
    end
    if journal.phase ~= "verified" then
        return { verified = false, eligibleToDeleteLegacy = false }
    end
    local pool = journal.shadow and journal.shadow.pool
    local entries = journal.shadow and journal.shadow.entries
    if type(pool) ~= "table" or type(entries) ~= "table" then
        return nil
    end
    local pooled, checkpoints = 0, 0
    for _ in pairs(pool) do
        pooled = pooled + 1
    end
    for _ in pairs(entries) do
        checkpoints = checkpoints + 1
    end
    return {
        verified = true,
        pooledVersions = pooled,
        checkpoints = checkpoints,
        eligibleToDeleteLegacy = false,
        note = "Native disk persistence, external backup and rollback unverified",
    }
end

-- Intentionally NO destructive commit() or cleanup() API.
SharedBackupMigrationJournalResearch = J

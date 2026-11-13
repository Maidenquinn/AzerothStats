-- RESEARCH ONLY. Never listed in the addon TOC; no live SavedVariables writes.
-- Explicit run IDs in a shared pool, not repeated table references in backups.
local M = {}

local function copy(v, state, depth)
    if depth > 32 then
        return nil, "depth limit"
    end
    state.count = state.count + 1
    if state.count > 4000000 then
        return nil, "node budget"
    end
    local kind = type(v)
    if kind ~= "table" then
        if kind == "nil" or kind == "string" or kind == "boolean" then
            return v
        end
        if kind == "number" and v == v and math.abs(v) < 1e100 then
            return v
        end
        return nil, "unsupported value"
    end
    if getmetatable(v) or state.visiting[v] then
        return nil, "unsafe table"
    end
    state.visiting[v] = true
    local result = {}
    for k, value in pairs(v) do
        if type(k) ~= "string" and type(k) ~= "number" then
            state.visiting[v] = nil
            return nil, "unsupported key"
        end
        local child, err = copy(value, state, depth + 1)
        if err then
            state.visiting[v] = nil
            return nil, err
        end
        result[k] = child
    end
    state.visiting[v] = nil
    return result
end

local function equal(left, right, state, depth)
    if depth > 32 then
        return false
    end
    state.nodes = state.nodes + 1
    if state.nodes > 4000000 or type(left) ~= type(right) then
        return false
    end
    if type(left) ~= "table" then
        return left == right
    end
    if getmetatable(left) or getmetatable(right) then
        return false
    end
    state.visiting = state.visiting or {}
    if state.visiting[left] or state.visiting[right] then
        return false
    end
    state.visiting[left], state.visiting[right] = true, true
    local same = true
    for k, v in pairs(left) do
        if right[k] == nil or not equal(v, right[k], state, depth + 1) then
            same = false
            break
        end
    end
    if same then
        for k in pairs(right) do
            if left[k] == nil then
                same = false
                break
            end
        end
    end
    state.visiting[left], state.visiting[right] = nil, nil
    return same
end

function M.sameData(left, right)
    return equal(left, right, { nodes = 0 }, 0)
end

-- Deterministic, order-independent dual rolling checksum for accidental damage.
-- NOT cryptographic authentication; safe enough only for research diagnostics.
local function fingerprint(value)
    local state = { left = 17, right = 71, nodes = 0, visiting = {} }
    local function feed(str)
        for i = 1, string.len(str) do
            local byte = string.byte(str, i)
            state.left = (state.left * 131 + byte) % 2147483647
            state.right = (state.right * 137 + byte) % 2147483629
        end
    end
    local function walk(v, depth)
        state.nodes = state.nodes + 1
        if state.nodes > 4000000 or depth > 32 then
            return false
        end
        local kind = type(v)
        if kind == "table" then
            if state.visiting[v] or getmetatable(v) then
                return false
            end
            local keys = {}
            for key in pairs(v) do
                if type(key) ~= "string" and type(key) ~= "number" then
                    return false
                end
                table.insert(keys, key)
            end
            table.sort(keys, function(a, b)
                if type(a) ~= type(b) then
                    return type(a) == "number"
                end
                return a < b
            end)
            feed("T" .. tostring(table.getn(keys)) .. ":")
            state.visiting[v] = true
            for _, key in ipairs(keys) do
                if not walk(key, depth + 1) or not walk(v[key], depth + 1) then
                    state.visiting[v] = nil
                    return false
                end
            end
            state.visiting[v] = nil
            return true
        end
        local payload
        if kind == "string" then
            payload = v
        elseif kind == "number" and v == v and math.abs(v) < 1e100 then
            payload = string.format("%.17g", v)
        elseif kind == "boolean" then
            payload = v and "1" or "0"
        elseif kind == "nil" then
            payload = ""
        else
            return false
        end
        feed(kind .. tostring(string.len(payload)) .. ":" .. payload)
        return true
    end
    if not walk(value, 0) then
        return nil
    end
    return tostring(state.left) .. ":" .. tostring(state.right)
end

M.fingerprint = fingerprint

-- Seal checkpoint metadata and ordered run references as well as payloads.
-- This detects accidental redirection to another individually valid pool item.
local function manifestDigest(entry)
    return fingerprint({
        id = entry.id,
        automatic = entry.automatic,
        runRefs = entry.runRefs,
        stateDigest = entry.stateDigest,
        origin = entry.origin,
    })
end

function M.sealEntry(store, id)
    local entry = type(store) == "table" and type(store.entries) == "table" and store.entries[id]
        or nil
    if type(entry) ~= "table" then
        return false, "missing checkpoint"
    end
    local digest = manifestDigest(entry)
    if not digest then
        return false, "unsafe checkpoint manifest"
    end
    entry.manifestDigest = digest
    return true
end

local function validManifest(entry)
    return type(entry) == "table"
        and type(entry.manifestDigest) == "string"
        and manifestDigest(entry) == entry.manifestDigest
end

function M.new()
    return { schema = 1, nextRun = 1, nextBackup = 1, pool = {}, digests = {}, entries = {} }
end

-- In-memory lookup by LOCAL run ID. No persisted index or additional
-- copy of run payloads. Always verify full equality before reusing a version.
local function buildIndex(store)
    local index = {}
    for id, run in pairs(store.pool) do
        if type(run) ~= "table" or type(run.id) ~= "string" then
            return nil, "invalid shared run index"
        end
        local group = index[run.id]
        if not group then
            group = {}
            index[run.id] = group
        end
        table.insert(group, id)
    end
    return index
end

function M.save(store, db, automatic, sharedIndex)
    if type(store) ~= "table" or store.schema ~= 1 then
        return nil, "invalid store"
    end
    if not AzerothStats.ValidateDatabase(db) then
        return nil, "invalid database"
    end
    -- One complete frozen database before any catalogue changes.
    local frozen, err = copy(db, { count = 0, visiting = {} }, 0)
    if err then
        return nil, err
    end
    local index, indexError = sharedIndex, nil
    if not index then
        index, indexError = buildIndex(store)
    end
    if not index then
        return nil, indexError
    end
    local nextRun = store.nextRun
    local staged, pendingIndex = {}, {}
    local runs = frozen.runs
    frozen.runs = nil
    local refs = {}
    for _, run in ipairs(runs) do
        local found
        for _, id in ipairs(index[run.id] or {}) do
            local candidate = store.pool[id]
            if candidate and equal(candidate, run, { nodes = 0 }, 0) then
                found = id
                break
            end
        end
        if not found then
            for _, id in ipairs(pendingIndex[run.id] or {}) do
                if equal(staged[id], run, { nodes = 0 }, 0) then
                    found = id
                    break
                end
            end
        end
        if not found then
            found = nextRun
            nextRun = nextRun + 1
            staged[found] = run
            local group = pendingIndex[run.id]
            if not group then
                group = {}
                pendingIndex[run.id] = group
            end
            table.insert(group, found)
        end
        table.insert(refs, found)
    end
    local stagedDigests = {}
    for id, value in pairs(staged) do
        stagedDigests[id] = fingerprint(value)
        if not stagedDigests[id] then
            return nil, "unsafe shared run fingerprint"
        end
    end
    local stateDigest = fingerprint(frozen)
    if not stateDigest then
        return nil, "unsafe snapshot state fingerprint"
    end
    local backupID = store.nextBackup
    -- Commit only after a full validated copy and complete version resolution.
    for id, value in pairs(staged) do
        store.pool[id] = value
        store.digests[id] = stagedDigests[id]
    end
    store.entries[backupID] = {
        id = backupID,
        automatic = automatic and true or false,
        runRefs = refs,
        state = frozen,
        stateDigest = stateDigest,
    }
    store.nextRun, store.nextBackup = nextRun, backupID + 1
    local sealed, sealError = M.sealEntry(store, backupID)
    if not sealed then
        return nil, sealError
    end
    for localID, pending in pairs(pendingIndex) do
        local group = index[localID]
        if not group then
            group = {}
            index[localID] = group
        end
        for _, ref in ipairs(pending) do
            table.insert(group, ref)
        end
    end
    return backupID
end

function M.restore(store, backupID)
    if type(store) ~= "table" or store.schema ~= 1 then
        return nil, "invalid store"
    end
    local entry = store.entries[backupID]
    if type(entry) ~= "table" or type(entry.state) ~= "table" or type(entry.runRefs) ~= "table" then
        return nil, "missing checkpoint"
    end
    if not validManifest(entry) then
        return nil, "checkpoint manifest checksum mismatch"
    end
    if not entry.stateDigest or fingerprint(entry.state) ~= entry.stateDigest then
        return nil, "snapshot state checksum mismatch"
    end
    local state, err = copy(entry.state, { count = 0, visiting = {} }, 0)
    if err then
        return nil, err
    end
    state.runs = {}
    for index, id in ipairs(entry.runRefs) do
        local v = store.pool[id]
        if type(v) ~= "table" then
            return nil, "missing shared run"
        end
        if not store.digests[id] or fingerprint(v) ~= store.digests[id] then
            return nil, "shared run checksum mismatch"
        end
        local frozen, failure = copy(v, { count = 0, visiting = {} }, 0)
        if failure then
            return nil, failure
        end
        state.runs[index] = frozen
    end
    if not AzerothStats.ValidateDatabase(state) then
        return nil, "invalid reconstructed database"
    end
    return state
end

function M.delete(store, backupID)
    if type(store.entries[backupID]) ~= "table" then
        return false, "missing checkpoint"
    end
    store.entries[backupID] = nil
    return true
end

function M.collect(store)
    -- Never collect a version referenced by either manual or automatic entry.
    local reachable = {}
    for _, entry in pairs(store.entries) do
        if not validManifest(entry) or type(entry.runRefs) ~= "table" then
            return nil, "invalid checkpoint manifest; pool unchanged"
        end
        for _, id in ipairs(entry.runRefs) do
            if not store.pool[id] then
                return nil, "dangling reference; pool unchanged"
            end
            reachable[id] = true
        end
    end
    local removed = 0
    for id in pairs(store.pool) do
        if not reachable[id] then
            store.pool[id] = nil
            store.digests[id] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- Legacy 2.0.4 catalogue migration, completely staged and verified.
-- Never mutate the caller's live database or original backup globals.
-- Internal backup IDs can differ; origin.kind + origin.id retain UI identity.
local function legacyEntries(root, kind)
    if root == nil then
        return {}, 1
    end
    if type(root) ~= "table" then
        return nil, "invalid " .. kind .. " root"
    end
    if root.schema == 1 then
        for key in pairs(root) do
            if key ~= "schema" and key ~= "data" then
                return nil, "unsupported " .. kind .. " legacy field"
            end
        end
        if type(root.data) ~= "table" then
            return nil, "invalid " .. kind .. " legacy snapshot"
        end
        return { { id = 1, at = 0, data = root.data, legacy = true } }, 2
    end
    if root.schema ~= 2 or type(root.entries) ~= "table" then
        return nil, "unsupported " .. kind .. " backup schema"
    end
    -- Unknown source fields must be rejected, never silently discarded.
    -- A future schema revision therefore requires an explicit adapter.
    for key in pairs(root) do
        if key ~= "schema" and key ~= "nextId" and key ~= "entries" then
            return nil, "unsupported " .. kind .. " catalogue field"
        end
    end
    local entries = root.entries
    local count = table.getn(entries)
    local seen = {}
    for key in pairs(entries) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or key > count then
            return nil, "sparse or unexpected " .. kind .. " entry"
        end
    end
    local maxID = 0
    for _, entry in ipairs(entries) do
        if
            type(entry) ~= "table"
            or type(entry.data) ~= "table"
            or type(entry.id) ~= "number"
            or entry.id < 1
            or entry.id ~= math.floor(entry.id)
            or seen[entry.id]
        then
            return nil, "invalid or duplicate " .. kind .. " backup ID"
        end
        for key in pairs(entry) do
            if
                key ~= "id"
                and key ~= "at"
                and key ~= "runs"
                and key ~= "data"
                and key ~= "legacy"
            then
                return nil, "unsupported " .. kind .. " backup field"
            end
        end
        seen[entry.id] = true
        maxID = math.max(maxID, entry.id)
        if entry.at ~= nil and type(entry.at) ~= "number" then
            return nil, "invalid " .. kind .. " backup timestamp"
        end
        if
            entry.runs ~= nil
            and (
                type(entry.runs) ~= "number"
                or entry.runs < 0
                or entry.runs ~= math.floor(entry.runs)
            )
        then
            return nil, "invalid " .. kind .. " run count"
        end
    end
    if
        type(root.nextId) ~= "number"
        or root.nextId <= maxID
        or root.nextId ~= math.floor(root.nextId)
    then
        return nil, "invalid " .. kind .. " next ID"
    end
    return entries, root.nextId
end

function M.importLegacy(live, manual, automatic)
    if not AzerothStats.ValidateDatabase(live) then
        return nil, "invalid live database"
    end
    local manualEntries, manualNext = legacyEntries(manual, "manual")
    if not manualEntries then
        return nil, manualNext
    end
    local autoEntries, autoNext = legacyEntries(automatic, "auto")
    if not autoEntries then
        return nil, autoNext
    end
    local staged = M.new()
    staged.sourceNextIds = { manual = manualNext, auto = autoNext }
    local sharedIndex = {}
    -- The active DB stays a separate root. It is verified, not rewritten.
    for _, kind in ipairs({ "manual", "auto" }) do
        local source = kind == "manual" and manualEntries or autoEntries
        for _, entry in ipairs(source) do
            if not AzerothStats.ValidateDatabase(entry.data) then
                return nil, "invalid source " .. kind .. " backup " .. tostring(entry.id)
            end
            local id, err = M.save(staged, entry.data, kind == "auto", sharedIndex)
            if not id then
                return nil, err
            end
            local saved = staged.entries[id]
            saved.origin = {
                kind = kind,
                id = entry.id,
                at = entry.at,
                legacy = entry.legacy and true or false,
                runs = entry.runs or table.getn(entry.data.runs),
            }
            local sealed, sealError = M.sealEntry(staged, id)
            if not sealed then
                return nil, sealError
            end
            local restored, restoreError = M.restore(staged, id)
            if not restored or not equal(restored, entry.data, { nodes = 0 }, 0) then
                return nil, restoreError or "migration roundtrip mismatch"
            end
        end
    end
    return staged
end

function M.findOrigin(store, kind, sourceID)
    if kind ~= "manual" and kind ~= "auto" then
        return nil
    end
    for id, entry in pairs(store.entries) do
        if
            type(entry.origin) == "table"
            and entry.origin.kind == kind
            and entry.origin.id == sourceID
        then
            return id
        end
    end
end

-- Reverify a staged/reloaded shared catalogue against the still untouched
-- original snapshot roots. A future migration MUST pass after actual disk
-- serialization before it may even offer a destructive space-saving action.
function M.verifyMigration(store, live, manual, automatic)
    if
        type(store) ~= "table"
        or store.schema ~= 1
        or type(store.entries) ~= "table"
        or type(store.pool) ~= "table"
    then
        return false, "invalid shared catalogue"
    end
    if not AzerothStats.ValidateDatabase(live) then
        return false, "invalid original live database"
    end
    local manualEntries, manualNext = legacyEntries(manual, "manual")
    if not manualEntries then
        return false, manualNext
    end
    local autoEntries, autoNext = legacyEntries(automatic, "auto")
    if not autoEntries then
        return false, autoNext
    end
    if
        type(store.sourceNextIds) ~= "table"
        or store.sourceNextIds.manual ~= manualNext
        or store.sourceNextIds.auto ~= autoNext
    then
        return false, "legacy sequence mismatch"
    end
    local expectedCount, actualCount = 0, 0
    for _ in pairs(store.entries) do
        actualCount = actualCount + 1
    end
    for _, kind in ipairs({ "manual", "auto" }) do
        local source = kind == "manual" and manualEntries or autoEntries
        for _, old in ipairs(source) do
            expectedCount = expectedCount + 1
            local id = M.findOrigin(store, kind, old.id)
            if not id then
                return false, "missing migrated " .. kind .. " checkpoint"
            end
            local entry = store.entries[id]
            local meta = entry.origin
            if
                type(meta) ~= "table"
                or meta.at ~= old.at
                or meta.legacy ~= (old.legacy and true or false)
                or meta.runs ~= (old.runs or table.getn(old.data.runs))
                or entry.automatic ~= (kind == "auto")
            then
                return false, "checkpoint metadata mismatch"
            end
            local restored, err = M.restore(store, id)
            if not restored or not equal(restored, old.data, { nodes = 0 }, 0) then
                return false, err or "checkpoint content mismatch"
            end
        end
    end
    if expectedCount ~= actualCount then
        return false, "unexpected additional checkpoints"
    end
    return true
end

-- Research code returns reconstructed data, never installs a live DB itself.
SharedBackupResearch = M

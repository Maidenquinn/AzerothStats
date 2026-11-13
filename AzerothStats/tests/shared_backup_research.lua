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

function M.new()
    return { schema = 1, nextRun = 1, nextBackup = 1, pool = {}, entries = {} }
end

function M.save(store, db, automatic)
    if type(store) ~= "table" or store.schema ~= 1 then
        return nil, "invalid store"
    end
    if not AzerothStats.ValidateDatabase(db) then
        return nil, "invalid database"
    end
    -- Clone completely before reading the catalogue; no writes until validated.
    local frozen, err = copy(db, { count = 0, visiting = {} }, 0)
    if err then
        return nil, err
    end
    local nextRun = store.nextRun
    local staged = {}
    local rest = frozen
    local runs = frozen.runs
    rest.runs = nil
    local refs = {}
    for _, run in ipairs(runs) do
        local found
        for id, candidate in pairs(store.pool) do
            if equal(candidate, run, { nodes = 0 }, 0) then
                found = id
                break
            end
        end
        if not found then
            for id, candidate in pairs(staged) do
                if equal(candidate, run, { nodes = 0 }, 0) then
                    found = id
                    break
                end
            end
        end
        if not found then
            found = nextRun
            nextRun = nextRun + 1
            staged[found] = run
        end
        table.insert(refs, found)
    end
    local backupID = store.nextBackup
    -- Commit state only once all runs have been frozen and versioned.
    for id, value in pairs(staged) do
        store.pool[id] = value
    end
    store.entries[backupID] = {
        id = backupID,
        automatic = automatic and true or false,
        runRefs = refs,
        state = rest,
    }
    store.nextRun, store.nextBackup = nextRun, backupID + 1
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
        if type(root.data) ~= "table" then
            return nil, "invalid " .. kind .. " legacy snapshot"
        end
        return { { id = 1, at = 0, data = root.data, legacy = true } }, 2
    end
    if root.schema ~= 2 or type(root.entries) ~= "table" then
        return nil, "unsupported " .. kind .. " backup schema"
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
        if type(entry) ~= "table" or type(entry.data) ~= "table"
            or type(entry.id) ~= "number" or entry.id < 1
            or entry.id ~= math.floor(entry.id) or seen[entry.id] then
            return nil, "invalid or duplicate " .. kind .. " backup ID"
        end
        seen[entry.id] = true
        maxID = math.max(maxID, entry.id)
        if entry.at ~= nil and type(entry.at) ~= "number" then
            return nil, "invalid " .. kind .. " backup timestamp"
        end
        if entry.runs ~= nil and
            (type(entry.runs) ~= "number" or entry.runs < 0
            or entry.runs ~= math.floor(entry.runs)) then
            return nil, "invalid " .. kind .. " run count"
        end
    end
    if type(root.nextId) ~= "number" or root.nextId <= maxID
        or root.nextId ~= math.floor(root.nextId) then
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
    -- The active DB stays a separate root. It is verified, not rewritten.
    for _, kind in ipairs({ "manual", "auto" }) do
        local source = kind == "manual" and manualEntries or autoEntries
        for _, entry in ipairs(source) do
            if not AzerothStats.ValidateDatabase(entry.data) then
                return nil, "invalid source " .. kind .. " backup " .. tostring(entry.id)
            end
            local id, err = M.save(staged, entry.data, kind == "auto")
            if not id then
                return nil, err
            end
            local saved = staged.entries[id]
            saved.origin = {
                kind = kind, id = entry.id, at = entry.at,
                legacy = entry.legacy and true or false,
                runs = entry.runs or table.getn(entry.data.runs),
            }
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
        if type(entry.origin) == "table" and entry.origin.kind == kind
            and entry.origin.id == sourceID then
            return id
        end
    end
end

-- Research code returns reconstructed data, never installs a live DB itself.
SharedBackupResearch = M

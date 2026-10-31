-- V2-only observations live beside, never inside, the schema-1 accounting maps.
-- Frozen V1 readers ignore this plain-data namespace and keep common run IDs.
-- This foundation does not change the V1 ledger or infer native card choices.
local A = AzerothStats
local namespace = "azerothStatsV2"
local maxRuns, maxSamples, maxNodes = 1000, 32, 240000
local maxEnriched = 32
local validatedStore, validatedDatabase
local fields = {
    "hp",
    "dmg",
    "cd",
    "crit",
    "cm",
    "arm",
    "reg",
    "area",
    "cnt",
    "spd",
    "xp",
    "luck",
    "gold",
    "heal",
    "lch",
    "echo",
    "thn",
    "pick",
    "liv",
    "bp",
    "dots",
    "doth",
    "big",
    "exe",
    "cc",
    "dotd",
    "shd",
    "auto",
    "pet",
    "ghp",
    "gdmg",
    "gcd",
    "gcrit",
    "gcm",
    "garm",
    "garea",
    "gcnt",
    "gecho",
    "gspd",
    "greg",
    "gpick",
    "ggold",
}

-- Own extension must also fit a much smaller budget than the whole V1 tree.
local function valid(value)
    local budget, seen = maxNodes, {}
    local function visit(v, depth)
        budget = budget - 1
        if budget < 0 or depth > 12 then
            return false
        end
        if type(v) ~= "table" then
            return v == nil
                or type(v) == "boolean"
                or (type(v) == "string" and string.len(v) <= 500)
                or (type(v) == "number" and v == v and math.abs(v) < 1e100)
        end
        if seen[v] or getmetatable(v) then
            return false
        end
        seen[v] = true
        for k, child in pairs(v) do
            if
                not ((type(k) == "string" and string.len(k) <= 200) or type(k) == "number")
                or not visit(child, depth + 1)
            then
                return false
            end
        end
        seen[v] = nil
        return true
    end
    return visit(value, 0)
end

-- Plain-data safety is necessary but not sufficient: the views also require
-- typed arrays/maps. Reject a malformed extension without deleting its input.
local function shape(store)
    local function array(value, limit, predicate)
        if value == nil then
            return true
        end
        if type(value) ~= "table" then
            return false
        end
        local count = 0
        for key, item in pairs(value) do
            count = count + 1
            if
                type(key) ~= "number"
                or key ~= math.floor(key)
                or key < 1
                or key > limit
                or not predicate(item)
            then
                return false
            end
        end
        return count == table.getn(value)
    end
    local function map(value, limit, predicate)
        if value == nil then
            return true
        end
        if type(value) ~= "table" then
            return false
        end
        local count = 0
        for key, item in pairs(value) do
            count = count + 1
            if
                count > limit
                or type(key) ~= "string"
                or string.len(key) > 200
                or not predicate(item)
            then
                return false
            end
        end
        return true
    end
    local function timed(v)
        return type(v) == "table" and A.Number(v.t) ~= nil
    end
    local function stats(v)
        return map(v, 64, function(n)
            return type(n) == "number" and A.Number(n) ~= nil
        end)
    end
    local function presence(v)
        return type(v) == "table"
            and type(v.name) == "string"
            and A.Number(v.firstAt)
            and A.Number(v.lastAt)
            and A.Number(v.maximum)
            and (v.target == nil or (type(v.target) == "number" and A.Number(v.target)))
    end
    if
        not map(store.preferences.goals, 12, function(g)
            return A.V2ValidGoal and A.V2ValidGoal(g)
        end)
    then
        return false
    end
    if
        store.preferences.goalSequence ~= nil
        and (
            type(store.preferences.goalSequence) ~= "number"
            or not A.Number(store.preferences.goalSequence)
            or store.preferences.goalSequence > 1000000000
        )
    then
        return false
    end
    for _, data in pairs(store.runs) do
        if type(data) ~= "table" then
            return false
        end
        if data.affixesRaw ~= nil and type(data.affixesRaw) ~= "string" then
            return false
        end
        if data.reviveState ~= nil then
            local state = data.reviveState
            if
                type(state) ~= "table"
                or (state.down ~= 0 and state.down ~= 1)
                or (state.by ~= nil and type(state.by) ~= "string")
                or (state.reviving ~= nil and type(state.reviving) ~= "string")
            then
                return false
            end
        end
        for _, key in ipairs({ "supportSequence", "bossSequence", "maxSummons" }) do
            if data[key] ~= nil and (type(data[key]) ~= "number" or not A.Number(data[key])) then
                return false
            end
        end
        if data.note ~= nil and type(data.note) ~= "string" then
            return false
        end
        if
            not stats(data.latest)
            or not map(data.removed, 128, function(v)
                return v == true
            end)
            or not array(data.progression, 120, timed)
            or not array(data.support, 40, function(v)
                return timed(v)
                    and type(v.kind) == "string"
                    and A.Number(v.seq)
                    and (v.name == nil or type(v.name) == "string")
            end)
            or not array(data.encounters, 16, function(v)
                return type(v) == "table"
                    and A.Number(v.id)
                    and A.Number(v.at)
                    and A.Number(v.lastAt)
                    and type(v.name) == "string"
            end)
            or not array(data.bossSamples, 12, function(v)
                return timed(v)
                    and A.Number(v.seq) ~= nil
                    and array(v.rows, 8, function(r)
                        return type(r) == "table" and type(r.name) == "string" and A.Number(r.dmg)
                    end)
            end)
            or not map(data.summons, 24, presence)
            or not map(data.buffs, 24, presence)
            or not map(data.debuffs, 24, presence)
        then
            return false
        end
    end
    return true
end

--- Read/create our namespace only. Unknown future versions are preserved untouched.
function A.V2Store(create)
    if not A.db then
        return nil
    end
    local ext = A.db.extensions
    if ext == nil and create then
        ext = {}
        A.db.extensions = ext
    end
    if type(ext) ~= "table" then
        return nil
    end
    local store = ext[namespace]
    if store == nil and create then
        store = { schema = 1, runs = {}, preferences = {} }
        ext[namespace] = store
    end
    if
        type(store) ~= "table"
        or store.schema ~= 1
        or type(store.runs) ~= "table"
        or type(store.preferences) ~= "table"
    then
        return nil
    end
    local count = 0
    for _, key in ipairs({ "summons", "effects" }) do
        if store.preferences[key] ~= nil and type(store.preferences[key]) ~= "boolean" then
            return nil
        end
    end
    -- The runtime owns this subtree. Validate once on load and on each bounded
    -- transactional write; a history render must not scan it once per row.
    if validatedStore == store and validatedDatabase == A.db then
        return store
    end
    if not valid(store) or not shape(store) then
        return nil
    end
    for id, entry in pairs(store.runs) do
        count = count + 1
        if
            count > maxRuns
            or type(id) ~= "string"
            or type(entry) ~= "table"
            or type(entry.samples) ~= "table"
            or not A.Number(entry.lastAt)
            or table.getn(entry.samples) > maxSamples
        then
            return nil
        end
        for _, sample in ipairs(entry.samples) do
            if
                type(sample) ~= "table"
                or not A.Number(sample.t)
                or type(sample.stats) ~= "table"
            then
                return nil
            end
        end
    end
    validatedStore, validatedDatabase = store, A.db
    return store
end

function A.V2Invalidate()
    validatedStore, validatedDatabase = nil, nil
end

--- Drop orphan analyses after a purge performed by either version. Never recreate runs.
function A.V2Reconcile()
    local store = A.V2Store(false)
    if not store then
        return
    end
    local retained = {}
    for _, run in ipairs(A.db.runs) do
        retained[run.id] = true
    end
    for id in pairs(store.runs) do
        if not retained[id] then
            store.runs[id] = nil
        end
    end
end

--- Full statistics reset is explicit; other extension namespaces remain untouched.
function A.V2Reset()
    A.v2Limited, A.v2Unavailable = nil, nil
    if A.db and type(A.db.extensions) == "table" then
        local store = A.V2Store(false)
        local preferences = store and store.preferences or {}
        local keep = { summons = preferences.summons, effects = preferences.effects }
        A.db.extensions[namespace] = nil
        if next(keep) then
            A.db.extensions[namespace] = { schema = 1, runs = {}, preferences = keep }
        end
        A.V2Invalidate()
    end
end

--- Immutable per-observation review; completed-run extensions only, never common totals.
function A.V2EntryPlan(action)
    local sections =
        { encounters = true, support = true, summons = true, buffs = true, debuffs = true }
    if
        type(action) ~= "table"
        or not sections[action.section]
        or type(action.runId) ~= "string"
        or type(action.key) ~= "string"
        or string.len(action.key) > 200
    then
        return nil
    end
    local run = A.FindRun(action.runId)
    local store = A.V2Store(false)
    local data = store and store.runs[action.runId]
    if not run or not data then
        return nil
    end
    local value
    if action.section == "encounters" or action.section == "support" then
        for _, item in ipairs(data[action.section] or {}) do
            local key = action.section == "encounters" and (item.id .. ":" .. item.at)
                or tostring(item.seq)
            if key == action.key then
                value = item
            end
        end
    else
        value = data[action.section] and data[action.section][action.key]
    end
    local reason = not value and "No data yet"
        or (run.status == "active" and "Active run cannot be deleted")
        or nil
    local tombstones = 0
    for _ in pairs(data.removed or {}) do
        tombstones = tombstones + 1
    end
    if tombstones >= 128 then
        reason = "Unavailable"
    end
    return {
        kind = "v2",
        runId = run.id,
        section = action.section,
        key = action.key,
        label = A.Text(action.label, 140) or action.key,
        scope = A.RunContext(run),
        count = value and 1 or 0,
        allowed = reason == nil,
        reason = reason,
        signature = A.Sign({
            id = run.id,
            section = action.section,
            key = action.key,
            value = value,
            status = run.status,
            sequence = A.db.sequence,
            reason = reason,
        }),
    }
end

--- Called only after the existing confirmation controller rechecks the review signature.
function A.V2RemoveEntry(plan)
    local data = A.V2Store(false).runs[plan.runId]
    data.removed = data.removed or {}
    data.removed[plan.section .. ":" .. plan.key] = true
    if plan.section == "encounters" or plan.section == "support" then
        for i = table.getn(data[plan.section] or {}), 1, -1 do
            local item = data[plan.section][i]
            local key = plan.section == "encounters" and (item.id .. ":" .. item.at)
                or tostring(item.seq)
            if key == plan.key then
                table.remove(data[plan.section], i)
            end
        end
    else
        data[plan.section][plan.key] = nil
    end
end

local function enriched(data)
    return data
        and (
            data.latest ~= nil
            or data.progression ~= nil
            or data.encounters ~= nil
            or data.support ~= nil
            or data.summons ~= nil
            or data.buffs ~= nil
            or data.debuffs ~= nil
            or data.affixesRaw ~= nil
        )
end

function A.V2Retention()
    local store, count = A.V2Store(false), 0
    for _, data in pairs(store and store.runs or {}) do
        if enriched(data) then
            count = count + 1
        end
    end
    return count, maxEnriched
end

--- Execute only a source-defined observer against an isolated own-data copy.
--- Existing unknown/future data is never repaired or overwritten implicitly.
function A.V2Update(run, observer)
    if not A.db or not run or type(observer) ~= "function" then
        return false
    end
    local retained = false
    for _, item in ipairs(A.db.runs) do
        if item == run then
            retained = true
        end
    end
    if not retained then
        return false
    end
    local store = A.V2Store(true)
    if not store then
        A.v2Unavailable = true
        return false
    end
    local old = store.runs[run.id]
    if not old then
        local count = 0
        for _ in pairs(store.runs) do
            count = count + 1
        end
        if count >= maxRuns then
            A.v2Limited = true
            return false
        end
    end
    local entry = old and A.Copy(old) or { samples = {}, lastAt = 0, partial = true }
    observer(entry)
    local victim, victimData
    if enriched(entry) and not enriched(old) then
        local count = 0
        for _, data in pairs(store.runs) do
            if enriched(data) then
                count = count + 1
            end
        end
        if count >= maxEnriched then
            local protected = A.ProtectedRunIds()
            for _, candidate in ipairs(A.db.runs) do
                if
                    candidate.id ~= run.id
                    and candidate.status ~= "active"
                    and not protected[candidate.id]
                    and enriched(store.runs[candidate.id])
                then
                    victim, victimData = candidate.id, store.runs[candidate.id]
                    break
                end
            end
            if not victim then
                A.v2Limited = true
                return false
            end
            -- Only the bounded advanced cache expires. Retained V1 history,
            -- totals, favorites and user-written notes are never removed here.
            store.runs[victim] = {
                samples = {},
                lastAt = 0,
                partial = true,
                expired = true,
                note = victimData.note,
            }
        end
    end
    store.runs[run.id] = entry
    if not valid(store) or not shape(store) or not A.ValidateDatabase(A.db) then
        store.runs[run.id] = old
        if victim then
            store.runs[victim] = victimData
        end
        A.v2Limited = true
        return false
    end
    return true
end

--- Store a fresh native sample at most every 15 server seconds, bounded per run.
--- Numeric values keep their native units; no absent field is synthesized as zero.
function A.ObserveV2(run)
    if not A.db or not run or run.status ~= "active" or not A.statsPacket then
        return
    end
    local t = A.Number(run.values and run.values.duration)
    if not t then
        return
    end
    local retained = false
    for _, entry in ipairs(A.db.runs) do
        if entry == run then
            retained = true
        end
    end
    if not retained then
        return
    end
    local store = A.V2Store(true)
    if not store then
        A.v2Unavailable = true
        return
    end
    local old = store.runs[run.id]
    if old and (type(old.samples) ~= "table" or not A.Number(old.lastAt)) then
        A.v2Unavailable = true
        return
    end
    if old and t < old.lastAt + 15 then
        return
    end
    local stats, found = {}, false
    local raw = A.ReadFields(AZS_STATS)
    for _, key in ipairs(fields) do
        local n = A.Number(raw[key])
        if n then
            stats[key] = n
            found = true
        end
    end
    if not found then
        return
    end
    A.V2Update(run, function(entry)
        entry.lastAt, entry.latest, entry.expired = t, stats, nil
        table.insert(entry.samples, { t = t, stats = A.Copy(stats) })
        if table.getn(entry.samples) > maxSamples then
            table.remove(entry.samples, 1)
            entry.truncated = true
        end
    end)
end

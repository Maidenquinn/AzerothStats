-- V2-only observations live beside, never inside, the schema-1 accounting maps.
-- Frozen V1 readers ignore this plain-data namespace and keep common run IDs.
-- This foundation does not change the V1 ledger or infer native card choices.
local A = AzerothStats
local namespace = "azerothStatsV2"
local maxRuns, maxSamples, maxNodes = 32, 32, 100000
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
        or not valid(store)
    then
        return nil
    end
    local count = 0
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
    return store
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
    if A.db and type(A.db.extensions) == "table" then
        A.db.extensions[namespace] = nil
    end
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
    if not old then
        local count = 0
        for _ in pairs(store.runs) do
            count = count + 1
        end
        if count >= maxRuns then
            A.v2Limited = true
            return
        end
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
    local entry = old and A.Copy(old) or { samples = {}, partial = run.partial == true }
    entry.lastAt, entry.latest = t, stats
    table.insert(entry.samples, { t = t, stats = A.Copy(stats) })
    if table.getn(entry.samples) > maxSamples then
        table.remove(entry.samples, 1)
        entry.truncated = true
    end
    store.runs[run.id] = entry
    if not valid(store) or not A.ValidateDatabase(A.db) then
        store.runs[run.id] = old
        A.v2Limited = true
    end
end

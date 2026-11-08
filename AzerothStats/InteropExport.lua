-- Read-only interoperability projection. No SavedVariables root or network output.
-- Schema v1 is a Lua table returned on demand; no duplicate history is stored.
local A = AzerothStats
local function number(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end
local function scalar(value, limit)
    if type(value) == "string" and string.len(value) > 0 and string.len(value) <= limit then
        return value
    end
    return nil
end
local function enum(value, allowed)
    if type(value) == "string" and allowed[value] then
        return value
    end
    return nil
end
local statuses = { active = true, ended = true, interrupted = true, terminal = true }
local outcomes = { victory = true, defeat = true, left = true }
local function metric(values, key)
    local value = type(values) == "table" and number(values[key]) or nil
    if value == nil then
        return { availability = "unavailable" }
    end
    return { value = value, availability = "available", provenance = "retained-run" }
end
-- Return an isolated, deliberately allowlisted projection. Never expose names,
-- coop roster, backup roots, event payloads or mutable internal tables.
function A.ExportRunV1(run)
    if type(run) ~= "table" or getmetatable(run) then
        return nil
    end
    local id = scalar(run.id, 80)
    if not id then
        return nil
    end
    local values = run.values
    local metrics = {}
    for _, key in ipairs({
        "duration",
        "level",
        "kills",
        "gold",
        "damage",
        "taken",
        "healing",
        "peakDps",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        metrics[key] = metric(values, key)
    end
    local heroic = number(run.heroic)
    if heroic == nil or heroic < 0 or heroic > 5 or heroic ~= math.floor(heroic) then
        heroic = nil
    end
    local partial = nil
    if type(run.partial) == "boolean" then
        partial = run.partial
    end
    return {
        schemaVersion = "1.0.0",
        source = { addon = "AzerothStats", version = A.version },
        run = {
            localId = id,
            nativeRunId = nil, -- AZS_ZONE.run semantics not yet verified.
            zone = scalar(run.zone, 80),
            class = scalar(run.class, 40),
            heroic = heroic,
            status = enum(run.status, statuses),
            outcome = enum(run.result, outcomes),
            partial = partial,
            startedAt = number(run.startedAt),
            endedAt = number(run.endedAt),
        },
        metrics = metrics,
    }
end

-- Resolve an owned retained run by local ID, without exposing the database or
-- accepting caller-owned tables. Explicit invocation only; no automatic export.
function A.ExportRetainedRunV1(localId)
    if type(localId) ~= "string" or string.len(localId) == 0 or string.len(localId) > 80 then
        return nil
    end
    local database = A.db
    if
        type(database) ~= "table"
        or getmetatable(database)
        or type(database.runs) ~= "table"
        or getmetatable(database.runs)
    then
        return nil
    end
    local matched = nil
    for key, run in pairs(database.runs) do
        if
            type(key) == "number"
            and key >= 1
            and key == math.floor(key)
            and type(run) == "table"
            and run.id == localId
        then
            -- Historical imports may collide. Never silently choose one run.
            if matched then
                return nil
            end
            matched = run
        end
    end
    if matched then
        return A.ExportRunV1(matched)
    end
    return nil
end

-- Observe the same native field read by WoW Logs AS v0.2.2. This is a
-- diagnostic candidate only: never attach it retroactively to a retained run.
-- Native run ID uniqueness, reuse and reload semantics remain unverified.
function A.InteropNativeRunCandidate()
    local zone = AZS_ZONE
    if type(zone) ~= "table" or getmetatable(zone) then
        return nil
    end
    local id = zone.run
    if type(id) == "string" then
        if string.len(id) > 0 and string.len(id) <= 80 then
            return id
        end
    elseif type(id) == "number" and number(id) and id >= 0 and id == math.floor(id) then
        local value = tostring(id)
        if string.len(value) <= 80 then
            return value
        end
    end
    return nil
end

-- AZST1 is a separate, explicit paste contract. It must never be passed off as
-- a WLAS2 payload. The encoder accepts only our own scalar projection.
local function jsonString(value)
    local replacements = {
        [34] = '\\"',
        [92] = '\\\\',
        [8] = '\\b',
        [9] = '\\t',
        [10] = '\\n',
        [12] = '\\f',
        [13] = '\\r',
    }
    local output = { '"' }
    for i = 1, string.len(value) do
        local byte = string.byte(value, i)
        if replacements[byte] then
            table.insert(output, replacements[byte])
        elseif byte < 32 then
            table.insert(output, string.format("\\u%04x", byte))
        else
            table.insert(output, string.char(byte))
        end
    end
    table.insert(output, '"')
    return table.concat(output)
end

local function jsonScalar(value)
    if type(value) == "string" then
        return jsonString(value)
    elseif type(value) == "number" and number(value) then
        return tostring(value)
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    end
    return "null"
end

-- Bounded, deterministic output; all keys originate from a fixed allowlist.
-- This deliberately avoids a general-purpose recursive table serializer.
function A.ExportCodeV1(run)
    local projected = A.ExportRunV1(run)
    if not projected then
        return nil
    end
    local r = projected.run
    local fields = {
        '"v":1',
        '"addon":"AzerothStats"',
        '"schema":"1.0.0"',
    }
    local runFields = {}
    for _, key in ipairs({
        "localId",
        "nativeRunId",
        "zone",
        "class",
        "heroic",
        "status",
        "outcome",
        "partial",
        "startedAt",
        "endedAt",
    }) do
        table.insert(runFields, jsonString(key) .. ":" .. jsonScalar(r[key]))
    end
    table.insert(fields, '"run":{' .. table.concat(runFields, ",") .. "}")
    local metricFields = {}
    for _, key in ipairs({
        "duration",
        "level",
        "kills",
        "gold",
        "damage",
        "taken",
        "healing",
        "peakDps",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        local m = projected.metrics[key]
        local item = '{"availability":' .. jsonString(m.availability)
        if m.availability == "available" then
            item = item .. ',"value":' .. jsonScalar(m.value) .. ',"provenance":"retained-run"'
        end
        table.insert(metricFields, jsonString(key) .. ":" .. item .. "}")
    end
    table.insert(fields, '"metrics":{' .. table.concat(metricFields, ",") .. "}")
    local code = "AZST1:{" .. table.concat(fields, ",") .. "}"
    if string.len(code) > 8192 then
        return nil
    end
    return code
end

function A.ExportRetainedCodeV1(localId)
    local projected = A.ExportRetainedRunV1(localId)
    if not projected then
        return nil
    end
    -- This path is safe because ExportRunV1 only reads its fixed allowlist.
    local r = projected.run
    local values = {}
    for key, metricValue in pairs(projected.metrics) do
        if metricValue.availability == "available" then
            values[key] = metricValue.value
        end
    end
    return A.ExportCodeV1({
        id = r.localId,
        zone = r.zone,
        class = r.class,
        heroic = r.heroic,
        status = r.status,
        result = r.outcome,
        partial = r.partial,
        startedAt = r.startedAt,
        endedAt = r.endedAt,
        values = values,
    })
end

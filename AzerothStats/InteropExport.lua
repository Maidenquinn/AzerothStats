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
    if type(value) == "string" and string.len(value) <= limit then
        return value
    end
    return nil
end
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
    }) do
        metrics[key] = metric(values, key)
    end
    local heroic = number(run.heroic)
    if heroic == nil or heroic < 0 or heroic > 5 or heroic ~= math.floor(heroic) then
        heroic = nil
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
            status = scalar(run.status, 32),
            outcome = scalar(run.result, 32),
            partial = run.partial == true,
            startedAt = number(run.startedAt),
            endedAt = number(run.endedAt),
        },
        metrics = metrics,
    }
end

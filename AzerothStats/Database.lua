-- Own SavedVariables lifecycle and idempotent accounting.
-- Only AzerothStatsDB is changed; raw AZS_* tables remain client-owned/read-only.

local A = AzerothStats
A.metrics = {
    "duration",
    "peakDps",
    "kills",
    "gold",
    "damage",
    "healing",
    "taken",
    "bosses",
    "elites",
    "guardians",
    "chests",
    "magnets",
    "level",
}

--- Initialize a new own database or validate an existing schema-1 tree; migrate only after validation.
function A.InitDB()
    if AzerothStatsDB == nil then
        AzerothStatsDB = {
            schema = 1,
            sequence = 0,
            runs = {},
            totals = {},
            classes = {},
            settings = {},
            migrations = {},
        }
    end
    local database = AzerothStatsDB
    if not A.ValidateDatabase(database) then
        A.Say(A.T("Database incompatible; collection disabled"))
        A.db = nil
        return false
    end
    if database.favorites == nil then
        database.favorites = { version = 1, entries = {} }
    end
    A.db = database
    A.NormalizeJewelry()
    A.CorrectChests()
    local s = database.settings
    s.windowPos = A.FramePosition(s.windowPos)
    s.barPos = A.FramePosition(s.barPos)
    s.barEditorPos = A.FramePosition(s.barEditorPos)
    if
        type(s.miniAngle) ~= "number"
        or s.miniAngle ~= s.miniAngle
        or math.abs(s.miniAngle) > 1000000
    then
        s.miniAngle = 0.785398
    end
    if s.recordSound == nil then
        s.recordSound = true
    end
    if s.bar == nil then
        s.bar = true
    end
    if s.minimap == nil then
        s.minimap = true
    end
    if s.locked == nil then
        s.locked = false
    end
    s.maxRuns = math.max(10, math.min(1000, math.floor(A.Number(s.maxRuns) or 200)))
    s.scale = math.max(0.65, math.min(1.5, A.Number(s.scale) or 1))
    s.opacity = math.max(0.45, math.min(1, A.Number(s.opacity) or 1))
    s.textSize = math.max(11, math.min(16, A.Number(s.textSize) or 12))
    if s.language ~= "auto" and not A.uiText[s.language] then
        s.language = "auto"
    end
    s.hud = A.NormalizeBar(s.hud)
    database.version = A.version
    return true
end

--- Ensure metric dictionaries exist on one already-validated own aggregate bucket.
local function bucket(t)
    t.sum = t.sum or {}
    t.coverage = t.coverage or {}
    t.records = t.records or {}
    return t
end

--- Apply only the difference from each run ledger, so repeated packets cannot add a run twice.
function A.Account(run)
    local database = A.db
    if not database or not run then
        return
    end
    if not database.classes[run.class] then
        database.classes[run.class] = {}
    end
    local groups = { bucket(database.totals), bucket(database.classes[run.class]) }
    for _, group in ipairs(groups) do
        if not run.counted then
            group.runs = (group.runs or 0) + 1
        end
        if run.result == "victory" and not run.winCounted then
            group.wins = (group.wins or 0) + 1
        end
        for _, key in ipairs(A.metrics) do
            local value, old = A.Number(run.values[key]), run.accounted[key]
            if value then
                if old == nil then
                    group.coverage[key] = (group.coverage[key] or 0) + 1
                end
                if key ~= "level" and key ~= "peakDps" then
                    group.sum[key] = (group.sum[key] or 0) + value - (old or 0)
                end
                local rec = group.records[key]
                if not rec or value > rec.value then
                    group.records[key] = { value = value, id = run.id, at = run.startedAt }
                end
            end
        end
    end
    run.counted = true
    if run.result == "victory" then
        run.winCounted = true
    end
    A.AccountInsights(run)
    for _, key in ipairs(A.metrics) do
        if run.values[key] ~= nil then
            run.accounted[key] = run.values[key]
        end
    end
    -- Separate ledger for sampled spell counters. Never add rates or last-boss meters.
    run.spellAccounted = run.spellAccounted or {}
    for _, mode in ipairs({ "damage", "healing", "taken" }) do
        local m = run.meters[mode]
        if m then
            local current = {}
            for _, row in ipairs(m.rows) do
                local name = tostring(row.name or row.source or "?")
                current[name] = (current[name] or 0) + row.dmg
            end
            run.spellAccounted[mode] = run.spellAccounted[mode] or {}
            for name, value in pairs(current) do
                if
                    A.Admit(
                        run.spellAccounted[mode],
                        name,
                        A.limits.spellSources,
                        run,
                        "spellSourcesTruncated"
                    )
                then
                    local old = run.spellAccounted[mode][name] or 0
                    if value < old then
                        value = old
                        run.spellSourcesTruncated = true
                    end
                    for _, group in ipairs(groups) do
                        group.spells = group.spells or {}
                        group.spells[mode] = group.spells[mode] or {}
                        if
                            A.Admit(
                                group.spells[mode],
                                name,
                                A.limits.spellSources,
                                group,
                                "spellSourcesTruncated"
                            )
                        then
                            group.spells[mode][name] = (group.spells[mode][name] or 0) + value - old
                        end
                    end
                    run.spellAccounted[mode][name] = value
                end
            end
        end
    end
end

--- Prune oldest unprotected run details, preserving the live run, favorite sources and lifetime totals.
function A.Trim()
    local protected = A.ProtectedRunIds()
    local ordinary = 0
    for _, run in ipairs(A.db.runs) do
        if not protected[run.id] then
            ordinary = ordinary + 1
        end
    end
    local i = 1
    while ordinary > A.db.settings.maxRuns and i <= table.getn(A.db.runs) do
        local run = A.db.runs[i]
        if run ~= A.run and not protected[run.id] then
            table.remove(A.db.runs, i)
            ordinary = ordinary - 1
            A.db.pruned = (A.db.pruned or 0) + 1
        else
            i = i + 1
        end
    end
end

--- Mirror Trim's protection/live-run rules without mutating history.
function A.RetentionImpact(limit)
    local protected, ordinary, removable = A.ProtectedRunIds(), 0, 0
    for _, run in ipairs(A.db.runs) do
        if not protected[run.id] then
            ordinary = ordinary + 1
            if run ~= A.run then
                removable = removable + 1
            end
        end
    end
    return math.min(removable, math.max(0, ordinary - limit))
end

--- Confirm destructive reductions using current impact; a changed count needs a new confirmation.
function A.RequestRetention(value, confirmed)
    local limit = math.max(10, math.min(1000, math.floor(A.Number(value) or A.db.settings.maxRuns)))
    local count = A.RetentionImpact(limit)
    local pending = A.pendingRetention
    if
        count > 0
        and (not confirmed or not pending or pending.limit ~= limit or pending.count ~= count)
    then
        A.pendingRetention = { limit = limit, count = count }
        if A.ShowRetentionConfirmation then
            A.ShowRetentionConfirmation()
        end
        return false
    end
    A.pendingRetention = nil
    A.db.settings.maxRuns = limit
    A.Trim()
    return true
end

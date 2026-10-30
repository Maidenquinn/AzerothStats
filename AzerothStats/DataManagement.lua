-- Explicit local data removal. No native writes, file I/O, arithmetic subtraction
-- from cumulative ledgers, or implicit reset from slash-command arguments.
local A = AzerothStats
-- Category resets are global and require an explicit between-run boundary.
A.dataCategories =
    { nemesis = "Nemesis", records = "Records", trends = "Trends", favorites = "Favorites" }
local function size(value)
    local count = 0
    for _ in pairs(value or {}) do
        count = count + 1
    end
    return count
end

--- Count visible aggregate entries and historical category details, never guess lost totals.
local function categoryImpact(kind, plan)
    local total = A.db.totals
    if kind == "nemesis" then
        plan.count = size(total.deathEvidence and total.deathEvidence.sources)
        plan.observed = total.deathEvidence and total.deathEvidence.deaths or 0
    elseif kind == "records" then
        plan.count = size(total.records)
    elseif kind == "trends" then
        plan.count = size(total.usage and total.usage.spells)
            + size(total.usage and total.usage.jewelry)
            + size(total.companions)
    else
        plan.count = size(A.db.favorites.entries)
    end
    plan.details = 0
    for _, run in ipairs(A.db.runs) do
        local count = kind == "nemesis" and table.getn(run.deaths or {})
            or kind == "records" and size(run.reportRecords)
            or kind == "trends" and (size(run.usage and run.usage.spells) + size(
                run.usage and run.usage.jewelry
            ))
            or 0
        if count > 0 then
            table.insert(plan.ids, run.id)
            plan.details = plan.details + count
        end
    end
    -- Class-only entries may outlive a global admission limit.
    plan.classEntries = 0
    for _, group in pairs(A.db.classes) do
        if kind == "nemesis" then
            plan.classEntries = plan.classEntries
                + size(group.deathEvidence and group.deathEvidence.sources)
        elseif kind == "records" then
            plan.classEntries = plan.classEntries + size(group.records)
        elseif kind == "trends" then
            plan.classEntries = plan.classEntries
                + size(group.usage and group.usage.spells)
                + size(group.usage and group.usage.jewelry)
                + size(group.companions)
        end
    end
end

--- Clear only the named category; historical numeric combat results remain intact.
local function clearCategory(kind)
    local groups = { A.db.totals }
    for _, group in pairs(A.db.classes) do
        table.insert(groups, group)
    end
    for _, group in ipairs(groups) do
        if kind == "nemesis" then
            group.deathEvidence = nil
        elseif kind == "records" then
            group.records = {}
        elseif kind == "trends" then
            group.usage, group.companions = nil, nil
            group.usageTruncated, group.companionsTruncated = nil, nil
            group.legacyJewelry14 = nil
        end
    end
    for _, run in ipairs(A.db.runs) do
        if kind == "nemesis" then
            run.deaths, run.deathsTruncated, run.nemesisReset = nil, nil, true
        elseif kind == "records" then
            run.reportRecords, run.recordBaseline, run.recordsReset = nil, nil, true
        elseif kind == "trends" then
            run.usage, run.usageTruncated, run.trendsReset = nil, nil, true
        end
    end
    if kind == "nemesis" then
        A.deathWatch = nil
    elseif kind == "trends" then
        A.view.coopPartner = nil
    elseif kind == "favorites" then
        A.db.favorites = { version = 1, entries = {} }
    end
    A.view.page = 1
end

--- Build a fresh impact summary. History removal deliberately keeps all lifetime ledgers.
function A.DataPlan(kind, class, id)
    if
        not A.db
        or (kind ~= "run" and kind ~= "history" and kind ~= "reset" and not A.dataCategories[kind])
    then
        return nil
    end
    if A.dataCategories[kind] and class ~= nil then
        return nil
    end
    if class ~= nil and (type(class) ~= "string" or not A.knownClasses[class]) then
        return nil
    end
    if kind == "run" and (type(id) ~= "string" or string.len(id) > 80) then
        return nil
    end
    local plan = { kind = kind, class = class, id = id, ids = {}, protected = 0, favorites = 0 }
    local pins = A.ProtectedRunIds()
    for _, run in ipairs(A.db.runs) do
        local matches = kind == "reset"
            or (kind == "run" and run.id == id)
            or (kind == "history" and (not class or class == run.class))
        if matches then
            if kind ~= "reset" and (run == A.run or run.status == "active" or pins[run.id]) then
                plan.protected = plan.protected + 1
                if kind == "run" then
                    plan.reason = (run == A.run or run.status == "active")
                            and "Active run cannot be deleted"
                        or "Remove run bookmarks first"
                end
            else
                table.insert(plan.ids, run.id)
            end
        end
    end
    for _ in pairs(A.db.favorites.entries) do
        plan.favorites = plan.favorites + 1
    end
    plan.count = table.getn(plan.ids)
    if A.dataCategories[kind] then
        categoryImpact(kind, plan)
    end
    if kind == "reset" or A.dataCategories[kind] then
        -- An explicit ready phase is required: absence of the API is not a safe boundary.
        if A.ReadProgress().ph ~= "ready" or (A.run and A.run.status == "active") then
            plan.reason = "Reset is available between runs only"
        elseif
            A.dataCategories[kind]
            and plan.count == 0
            and plan.details == 0
            and plan.classEntries == 0
            and (plan.observed or 0) == 0
        then
            plan.reason = "No data yet"
        end
    elseif plan.count == 0 then
        plan.reason = plan.reason or "No matching run details"
    end
    plan.allowed = plan.reason == nil
    plan.signature = A.Sign({
        kind = kind,
        class = class,
        id = id,
        ids = plan.ids,
        protected = plan.protected,
        favorites = plan.favorites,
        sequence = A.db.sequence,
        allowed = plan.allowed,
        reason = plan.reason,
        count = plan.count,
        details = plan.details,
        observed = plan.observed,
        classEntries = plan.classEntries,
    })
    return plan
end

--- Opening/reviewing a plan never changes persisted data or retention settings.
function A.PrepareDataAction(kind, class, id)
    A.pendingDataPlan = A.DataPlan(kind, class, id)
    return A.pendingDataPlan
end

--- Apply only the explicitly reviewed, still-current plan. Full reset also requires RESET.
function A.ConfirmDataAction(token)
    local pending = A.pendingDataPlan
    if not pending then
        return false, "Review data removal first"
    end
    local fresh = A.DataPlan(pending.kind, pending.class, pending.id)
    if not fresh then
        A.pendingDataPlan = nil
        return false, "Review data removal first"
    end
    A.pendingDataPlan = fresh
    if not fresh.allowed then
        return false, fresh.reason
    end
    if fresh.signature ~= pending.signature then
        return false, "Data changed; review again"
    end
    if fresh.kind == "reset" and token ~= "RESET" then
        return false, "Type RESET to confirm"
    end
    if A.dataCategories[fresh.kind] then
        clearCategory(fresh.kind)
    elseif fresh.kind == "reset" then
        A.V2Reset()
        -- Keep schema/version, migrations, monotonic IDs and the exact settings object.
        -- Do not rebuild totals from retained runs: their older history may be pruned.
        A.db.runs, A.db.totals, A.db.classes = {}, {}, {}
        A.db.favorites = { version = 1, entries = {} }
        A.db.pruned = 0
        A.run, A.pendingReport, A.partySession, A.deathWatch = nil, nil, nil, nil
        A.journalPhaseRun, A.journalPhase, A.journalStatsWindow = nil, nil, nil
        A.packetSummary, A.packetReady = nil, nil
        A.meterPackets = {}
        A.boundaryGate = A.Gate()
        A.newBoundary = true
        A.inventoryBaseline = A.InventorySignature()
        A.buildBaseline = { spells = A.Sign(A.Copy(AZS_SPELLS)), stats = A.Sign(A.Copy(AZS_STATS)) }
        A.spellPacket, A.statsPacket = nil, nil
        A.inReady = true
        A.view =
            { tab = 8, page = 1, mode = "damage", characterTab = "Spells", combatTab = "Spells" }
    else
        local remove = {}
        for _, id in ipairs(fresh.ids) do
            remove[id] = true
        end
        for i = table.getn(A.db.runs), 1, -1 do
            if remove[A.db.runs[i].id] then
                table.remove(A.db.runs, i)
                A.db.pruned = (A.db.pruned or 0) + 1
            end
        end
        if remove[A.view.selected] then
            A.view.selected = nil
            A.view.tab, A.view.historySection, A.view.cumulative = 3, "History", false
        end
        if remove[A.view.compareA] then
            A.view.compareA = nil
        end
        if remove[A.view.compareB] then
            A.view.compareB = nil
        end
        if A.pendingReport and remove[A.pendingReport.id] then
            A.pendingReport = nil
        end
        A.view.page = 1
    end
    A.pendingDataPlan = nil
    A.V2Reconcile()
    return true, "Local data cleared"
end

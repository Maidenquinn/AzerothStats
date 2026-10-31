-- Per-page presentation preferences and narrowly scoped local data actions.
-- Hiding is reversible and never changes accounting. Resets use explicit keys,
-- operate on all classes, and fence old runs against importing the erased entry.
local A = AzerothStats

local function metric(key)
    for _, value in ipairs(A.metrics) do
        if value == key then
            return true
        end
    end
end

--- Preserve row identity across value changes, ranks and translated UI labels.
local function identity(item)
    if type(item.visibilityKey) == "string" then
        return "v2:" .. string.sub(item.visibilityKey, 1, 200)
    end
    if item.metric then
        return "metric:" .. item.metric
    end
    if item.entryAction then
        return item.entryAction.kind
            .. ":"
            .. (item.entryAction.section or "")
            .. ":"
            .. item.entryAction.key
    end
    if item.favorite then
        return "favorite:" .. A.FavoriteId(item.favorite.kind, item.favorite.key)
    end
    if item.link then
        return "link:" .. item.link
    end
    local label = tostring(item.label or "")
    local canonical
    for key, text in pairs(A.uiText[A.Locale()] or {}) do
        if text == label and (not canonical or key < canonical) then
            canonical = key
        end
    end
    return "label:" .. (canonical or label)
end

--- Scope visibility to a page/subpage and actual retained run, not to pagination.
function A.EditContext(run)
    local v = A.view
    return A.Sign({
        tab = v.tab,
        class = v.class,
        mode = v.mode,
        overview = v.overviewStats,
        a = v.compareA,
        b = v.compareB,
        compare = v.compareSection,
        history = v.historySection,
        report = v.reportSection,
        character = v.characterTab,
        usage = v.usageTab,
        combat = v.combatTab,
        category = v.favoriteCategory,
        v2Goals = v.v2Goals,
        v2BossSample = v.v2BossSample,
        run = (
            v.tab == 4
            or v.tab == 5
            or (v.tab == 3 and v.historySection ~= "History")
            or (v.tab == 9 and not v.cumulative)
        )
                and run
                and run.id
            or nil,
        cumulative = v.cumulative and true or false,
    })
end

--- Apply bounded, reversible visibility preferences to one trusted model.
function A.DecorateEditing(model, run)
    if A.view.tab == 8 then
        return
    end -- Settings edits settings; it has no data rows.
    local context = A.EditContext(run)
    model.editContext, model.editable = context, true
    local hidden = A.db.settings.hiddenRows and A.db.settings.hiddenRows[context] or {}
    model.hiddenCount = 0
    for _, field in ipairs({ "rows", "cards", "records", "sections" }) do
        local visible = {}
        for _, item in ipairs(model[field] or {}) do
            local key = identity(item)
            item.editIdentity, item.editContext = key, context
            item.hidden = hidden[key] == true
            if (A.view.tab == 6 or field == "records") and item.metric then
                item.entryAction = { kind = "record", key = item.metric, label = item.label }
            elseif A.view.tab == 10 and item.favorite then
                item.entryAction = {
                    kind = "bookmark",
                    key = A.FavoriteId(item.favorite.kind, item.favorite.key),
                    label = item.label,
                }
            elseif
                (
                    A.view.tab == 1
                    or (A.view.tab == 3 and (A.view.historySection or "History") == "History")
                )
                and item.favorite
                and item.favorite.kind == "run"
            then
                item.entryAction = { kind = "run", key = item.favorite.key, label = item.label }
            end
            if item.hidden then
                model.hiddenCount = model.hiddenCount + 1
            end
            if not item.hidden or A.editMode then
                table.insert(visible, item)
            end
        end
        model[field] = visible
    end
    if model.hiddenCount > 0 then
        model.note = (model.note or "") .. " · " .. A.T("Hidden rows do not change totals")
    end
end

--- Hide/show only a validated own presentation key, with a shared finite budget.
function A.ToggleHiddenRow(item)
    if
        not item
        or type(item.editContext) ~= "string"
        or type(item.editIdentity) ~= "string"
        or string.len(item.editContext) > 1600
        or string.len(item.editIdentity) > 1000
    then
        return false
    end
    local all = A.db.settings.hiddenRows or {}
    local page = all[item.editContext] or {}
    if page[item.editIdentity] then
        page[item.editIdentity] = nil
    else
        local count = 0
        for _, rows in pairs(all) do
            for _ in pairs(rows) do
                count = count + 1
            end
        end
        if count >= 2048 then
            return false
        end
        page[item.editIdentity] = true
    end
    all[item.editContext] = next(page) and page or nil
    A.db.settings.hiddenRows = all
    return true
end

function A.RestorePageRows(context)
    if A.db.settings.hiddenRows then
        A.db.settings.hiddenRows[context] = nil
    end
end

local function target(group, action)
    if action.kind == "record" then
        return group.records and group.records[action.key]
    end
    if action.kind == "nemesis" then
        return group.deathEvidence and group.deathEvidence.sources[action.key]
    end
    if action.section == "companions" then
        return group.companions and group.companions[action.key]
    end
    return group.usage and group.usage[action.section] and group.usage[action.section][action.key]
end

--- Return an immutable data-only review plan. Invalid/unsupported descriptors fail closed.
function A.EntryPlan(action)
    if type(action) == "table" and action.kind == "v2Goal" then
        return A.V2GoalPlan(action)
    end
    if type(action) == "table" and action.kind == "v2" then
        return A.V2EntryPlan(action)
    end
    if
        not A.db
        or type(action) ~= "table"
        or type(action.key) ~= "string"
        or string.len(action.key) > 600
    then
        return nil
    end
    local kind = action.kind
    if
        kind ~= "record"
        and kind ~= "nemesis"
        and kind ~= "trend"
        and kind ~= "bookmark"
        and kind ~= "run"
    then
        return nil
    end
    if kind == "record" and not metric(action.key) then
        return nil
    end
    if
        kind == "trend"
        and action.section ~= "spells"
        and action.section ~= "jewelry"
        and action.section ~= "companions"
    then
        return nil
    end
    local plan = {
        kind = kind,
        key = action.key,
        section = action.section,
        label = A.Text(action.label, 140) or action.key,
        count = 0,
    }
    local state = {}
    if kind == "run" then
        plan.history = A.DataPlan("run", nil, action.key)
        if not plan.history then
            return nil
        end
        plan.reason, plan.count = plan.history.reason, plan.history.count
        state = plan.history.signature
    elseif kind == "bookmark" then
        state = A.db.favorites.entries[action.key]
        plan.count = state and 1 or 0
    else
        state = { global = target(A.db.totals, action), classes = {} }
        for class, group in pairs(A.db.classes) do
            state.classes[class] = target(group, action)
        end
        if state.global then
            plan.count = plan.count + 1
        end
        for _ in pairs(state.classes) do
            plan.count = plan.count + 1
        end
        if A.ReadProgress().ph ~= "ready" or (A.run and A.run.status == "active") then
            plan.reason = "Reset is available between runs only"
        end
    end
    if kind == "trend" or kind == "nemesis" then
        for _, run in ipairs(A.db.runs) do
            local entries = kind == "nemesis" and run.nemesisResets
                or (run.trendResets and run.trendResets[action.section])
            if entries and not entries[action.key] then
                local count = 0
                for _ in pairs(entries) do
                    count = count + 1
                end
                local limit = action.section == "companions" and 1024 or 512
                if count >= limit then
                    plan.reason = "Unavailable"
                end
            end
        end
    end
    if not plan.reason and plan.count == 0 then
        plan.reason = "No data yet"
    end
    plan.allowed = plan.reason == nil
    plan.signature = A.Sign({
        kind = kind,
        key = plan.key,
        section = plan.section,
        state = state,
        sequence = A.db.sequence,
        allowed = plan.allowed,
        reason = plan.reason,
    })
    return plan
end

--- Reset one category key, not its numeric combat contribution or lifetime sums.
function A.ConfirmEntryAction()
    local old = A.pendingEntryPlan
    if not old then
        return false, "Review data removal first"
    end
    local plan = A.EntryPlan(old)
    A.pendingEntryPlan = plan
    if not plan then
        return false, "Review data removal first"
    end
    if not plan.allowed then
        return false, plan.reason
    end
    if plan.signature ~= old.signature then
        return false, "Data changed; review again"
    end
    if plan.kind == "run" then
        A.pendingDataPlan = plan.history
        local ok, reason = A.ConfirmDataAction()
        if not ok then
            return false, reason
        end
    elseif plan.kind == "bookmark" then
        A.db.favorites.entries[plan.key] = nil
    elseif plan.kind == "v2" then
        A.V2RemoveEntry(plan)
    elseif plan.kind == "v2Goal" then
        A.V2Store(false).preferences.goals[plan.key] = nil
    else
        local groups = { A.db.totals }
        for _, group in pairs(A.db.classes) do
            table.insert(groups, group)
        end
        for _, group in ipairs(groups) do
            if plan.kind == "record" then
                if group.records then
                    group.records[plan.key] = nil
                end
            elseif plan.kind == "nemesis" then
                local evidence = group.deathEvidence
                local source = evidence and evidence.sources[plan.key]
                if source then
                    evidence.deaths = math.max(
                        0,
                        evidence.deaths - (source.confirmed or 0) - (source.probable or 0)
                    )
                    evidence.sources[plan.key] = nil
                end
            elseif plan.section == "companions" then
                if group.companions then
                    group.companions[plan.key] = nil
                end
            elseif group.usage and group.usage[plan.section] then
                group.usage[plan.section][plan.key] = nil
            end
        end
        for _, run in ipairs(A.db.runs) do
            if plan.kind == "record" then
                run.recordResets = run.recordResets or {}
                run.recordResets[plan.key] = true
                if run.reportRecords then
                    run.reportRecords[plan.key] = nil
                end
            elseif plan.kind == "nemesis" then
                run.nemesisResets = run.nemesisResets or {}
                run.nemesisResets[plan.key] = true
                for i = table.getn(run.deaths or {}), 1, -1 do
                    if run.deaths[i].source == plan.key then
                        table.remove(run.deaths, i)
                    end
                end
            else
                run.trendResets = run.trendResets or {}
                run.trendResets[plan.section] = run.trendResets[plan.section] or {}
                run.trendResets[plan.section][plan.key] = true
                if run.usage and run.usage[plan.section] then
                    run.usage[plan.section][plan.key] = nil
                end
            end
        end
        if plan.kind == "nemesis" then
            A.deathWatch = nil
        end
        if plan.kind == "trend" then
            A.view.coopPartner = nil
        end
    end
    A.pendingEntryPlan = nil
    return true, "Local data cleared"
end

function A.TrendKeyReset(run, section, key)
    return run.trendsReset
        or (run.trendResets and run.trendResets[section] and run.trendResets[section][key])
end

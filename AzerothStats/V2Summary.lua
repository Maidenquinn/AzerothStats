-- Read-only landing/report composition. Every chart point comes from a retained
-- sample. Ready-state identity is transient and never creates/account a run.
local A = AzerothStats

function A.V2LiveContext()
    local progress = A.ReadProgress()
    if progress.ph ~= "ready" then
        return A.run and A.run.status == "active" and A.run or nil
    end
    local _, class, hero, zone = A.Identity()
    return {
        hero = hero,
        class = class,
        zone = zone,
        heroic = A.ReadHeroic(),
        prepared = true,
        values = {},
    }
end

local function highlights(run)
    local out = {}
    local entries = run and run.buildJournal and run.buildJournal.entries or {}
    for i = table.getn(entries), 1, -1 do
        local entry = entries[i]
        if not entry.initial and entry.changes and entry.changes[1] then
            table.insert(
                out,
                A.Duration(entry.t)
                    .. " · "
                    .. A.Text(A.JournalChange(entry.kind, entry.changes[1]), 95)
            )
            if table.getn(out) == 2 then
                break
            end
        end
    end
    return table.getn(out) > 0 and table.concat(out, "\n") or A.T("No build journal recorded")
end

local function nextGoal()
    local store = A.V2Store(false)
    local keys = {}
    for key in pairs(store and store.preferences.goals or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local goal = store.preferences.goals[key]
        local count = A.V2GoalProgress(goal)
        if
            (not A.view.class or goal.class == "all" or goal.class == A.view.class)
            and count < goal.target
        then
            return A.V2GoalLabel(goal)
                .. "\n"
                .. A.V2GoalScope(goal)
                .. "\n"
                .. A.Format(count)
                .. " / "
                .. A.Format(goal.target)
                .. " · "
                .. A.T("Retained history only")
        end
    end
    return A.T("Personal objectives") .. "\n" .. A.T("No data yet")
end

local function part(model, key, label, text)
    local item = {
        visibilityKey = "summary:" .. key,
        summaryPart = key,
        label = A.T(label),
        value = "",
        detail = text,
    }
    table.insert(model.sections, item)
    if A.editMode then
        table.insert(model.rows, item)
    end
end

function A.V2SummaryModel(model, run)
    local home = model.layout == "dashboard"
    local report = model.report and A.view.reportSection == "Overview"
    if report and not run then
        return
    end
    if not home and not report then
        return
    end
    model.v2Summary, model.sections = home and "home" or "report", {}
    model.liveHero = home and A.V2LiveContext() or nil
    if A.editMode and home then
        model.layout, model.cards, model.records = "list", {}, nil
        model.rowY, model.rowHeight, model.capacity = 194, 48, 8
    end
    local source = run
    if home then
        source = A.run
        if not source then
            for i = table.getn(A.db.runs), 1, -1 do
                if not A.view.class or A.db.runs[i].class == A.view.class then
                    source = A.db.runs[i]
                    break
                end
            end
        end
    end
    model.curveRun = source
    model.curveMetric = A.view.v2CurveMetric or "kills"
    model.curve = source and A.V2Curve(source, model.curveMetric) or {}
    model.plotTop, model.curveWidth, model.curveHeight = home and 540 or 410, 440, 150
    -- The home chart is explicitly one run's cumulative samples, not lifetime
    -- kills synthesized from an aggregate ledger or from final totals.
    model.curveCaption = source and A.ZoneName(source) or A.T("No data yet")
    part(model, "curve", "Progression curves", model.curveCaption)
    if home then
        if model.cards[4] then
            model.cards[4].label = A.T("Cumulative kills")
        end
        part(
            model,
            "takeaways",
            "Takeaways",
            source
                    and (A.ZoneName(source) .. " · " .. A.Status(source.result or source.status) .. "\n" .. highlights(
                        source
                    ))
                or A.T("No data yet")
        )
        part(model, "goal", "Next objective", nextGoal())
        if not A.editMode then
            -- The complete retained history is one click away. Three compact
            -- recent rows leave room for the same two-column story as the mockup.
            model.rowY, model.rowHeight, model.capacity = 382, 50, 3
        end
    elseif run then
        table.insert(model.cards, {
            label = A.Metric("level"),
            value = A.Format(run.values.level),
            detail = A.T("Last sample"),
            metric = "level",
            icon = A.metricIcons.level,
        })
        local data = A.V2RunData(run)
        local affixes = data and data.affixesRaw
        local context = A.HeroicLabel(run)
            .. "\n"
            .. (A.CoopLabel(run) or (A.T("Co-op") .. " : " .. A.T("Unavailable")))
            .. "\n"
            .. A.T("Affixes")
            .. " : "
            .. (affixes == nil and A.T("Unavailable") or affixes == "" and "∅" or affixes)
            .. "\n"
            .. A.Metric("gold")
            .. " : "
            .. A.Short(run.values.gold)
            .. "\n"
            .. A.Metric("chests")
            .. " : "
            .. A.Format(run.values.chests)
            .. "\n"
            .. A.T(run.partial and "Partial" or "Values from available samples")
        part(model, "context", "Run context", context)
        part(model, "moments", "Highlights", highlights(run))
        part(model, "note", "Your note", data and data.note or A.T("No data yet"))
        if not A.editMode then
            model.cardsTop = 292
            model.columnLabel = nil
        end
    end
end

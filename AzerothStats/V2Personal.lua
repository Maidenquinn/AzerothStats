-- Local notes and personal objectives. Never native achievements or unlock claims.
local A = AzerothStats
function A.V2SetNote(id, text)
    local run = A.FindRun(id)
    if not run or type(text) ~= "string" or string.len(text) > 500 then
        return false
    end
    return A.V2Update(run, function(data)
        data.note = A.Text(text, 500)
    end)
end

-- Metrics describe retained completed runs only. Level is a personal best;
-- other counters accumulate known observations, never unavailable fields.
A.v2GoalMetrics = { "wins", "runs", "kills", "gold", "damage", "duration", "level", "bosses" }
function A.V2ValidGoal(g)
    if type(g) ~= "table" or getmetatable(g) then
        return false
    end
    local metric = g.metric or "wins"
    local known = false
    for _, key in ipairs(A.v2GoalMetrics) do
        if metric == key then
            known = true
        end
    end
    return known
        and type(g.zone) == "string"
        and string.len(g.zone) <= 80
        and (g.class == "all" or (A.knownClasses[g.class] and g.class ~= "unknown"))
        and (g.heroic == "all" or (type(g.heroic) == "number" and A.HeroicLevel(g.heroic) ~= nil))
        and type(g.target) == "number"
        and A.Number(g.target)
        and g.target >= 1
        and g.target <= (g.metric and 1000000000000 or 100)
        and g.target == math.floor(g.target)
        and (
            g.title == nil
            or (type(g.title) == "string" and string.len(g.title) > 0 and string.len(g.title) <= 80)
        )
end
function A.V2CreateGoal(spec)
    if not A.V2ValidGoal(spec) then
        return false
    end
    local store = A.V2Store(true)
    if not store then
        return false
    end
    local oldGoals, oldSequence = store.preferences.goals, store.preferences.goalSequence
    local goals, count = A.Copy(oldGoals or {}), 0
    for _ in pairs(goals) do
        count = count + 1
    end
    if count >= 12 then
        return false
    end
    store.preferences.goalSequence = (A.Number(oldSequence) or 0) + 1
    local id = "goal-" .. store.preferences.goalSequence
    -- Explicit scalar copy: UI callers cannot introduce callbacks or extra fields.
    goals[id] = {
        class = spec.class,
        zone = spec.zone,
        heroic = spec.heroic,
        target = spec.target,
        metric = spec.metric,
        title = spec.title and A.Text(spec.title, 80),
    }
    store.preferences.goals = goals
    A.V2Invalidate()
    if not A.V2Store(false) or not A.ValidateDatabase(A.db) then
        store.preferences.goals, store.preferences.goalSequence = oldGoals, oldSequence
        A.V2Invalidate()
        return false
    end
    return id
end
-- Compatibility contract for the original exact-zone victory objectives.
function A.V2AddGoal(run, target)
    if not run or not run.zone then
        return false
    end
    return A.V2CreateGoal({
        class = run.class,
        zone = run.zone,
        heroic = run.heroic,
        target = target,
    })
end
function A.V2GoalLabel(goal)
    return goal.title
        or (
            goal.zone == "all"
                and A.T(
                    goal.metric == "runs" and "Runs observed"
                        or (goal.metric == "wins" or not goal.metric) and "Wins"
                        or A.Metric(goal.metric)
                )
            or A.ZoneName(goal)
        )
end
function A.V2GoalScope(goal)
    return A.T(
        goal.metric == "runs" and "Runs observed"
            or (goal.metric == "wins" or not goal.metric) and "Wins"
            or A.Metric(goal.metric)
    ) .. " · " .. (goal.class == "all" and A.T("All classes") or A.ClassName(goal.class)) .. " · " .. (goal.zone == "all" and A.T(
        "All zones"
    ) or A.ZoneName(goal)) .. " · " .. (goal.heroic == "all" and A.T("All difficulties") or A.HeroicLabel(
        goal
    ))
end
function A.V2GoalProgress(goal)
    local value, seen, known, matching = 0, {}, 0, 0
    local metric = goal.metric or "wins"
    for _, run in ipairs(A.db.runs) do
        if
            not seen[run.id]
            and run.status ~= "active"
            and run.status ~= "terminal"
            and (goal.class == "all" or run.class == goal.class)
            and (goal.zone == "all" or run.zone == goal.zone)
            and (goal.heroic == "all" or run.heroic == goal.heroic)
        then
            seen[run.id], matching = true, matching + 1
            local n
            if metric == "wins" then
                n = run.result == "victory" and 1 or 0
            elseif metric == "runs" then
                n = 1
            else
                n = A.Number(run.values and run.values[metric])
            end
            if n then
                known = known + 1
                value = metric == "level" and math.max(value, n) or value + n
            end
        end
    end
    return value, known, matching
end

function A.V2GoalPlan(action)
    local store = A.V2Store(false)
    local goal = type(action.key) == "string"
        and store
        and store.preferences.goals
        and store.preferences.goals[action.key]
    if not goal or type(goal) ~= "table" then
        return nil
    end
    return {
        kind = "v2Goal",
        key = action.key,
        label = A.V2GoalLabel(goal),
        count = 1,
        allowed = true,
        scope = A.V2GoalScope(goal),
        signature = A.Sign(goal),
    }
end

function A.V2GoalsModel(model)
    local store = A.V2Store(false)
    model.rows, model.cards, model.banner, model.records = {}, {}, nil, nil
    model.layout, model.title, model.subtitle =
        "list", A.T("My progress"), A.T("Personal objectives")
    model.rowY, model.rowHeight = 194, 52
    model.columnLabel, model.columnValue = A.T("Personal objectives"), A.T("Progression")
    model.note = A.T("Retained history only") .. " · " .. A.T("Personal objectives")
    for id, goal in pairs(store and store.preferences.goals or {}) do
        if
            type(goal) == "table"
            and A.Number(goal.target)
            and (not A.view.class or goal.class == "all" or A.view.class == goal.class)
            and (
                A.view.difficulty == nil
                or goal.heroic == "all"
                or A.view.difficulty == goal.heroic
            )
        then
            local progress, known, matching = A.V2GoalProgress(goal)
            table.insert(model.rows, {
                label = A.V2GoalLabel(goal),
                value = A.Format(progress) .. " / " .. A.Format(goal.target),
                detail = A.V2GoalScope(goal),
                exact = A.V2GoalScope(goal)
                    .. "\n"
                    .. A.T("Coverage")
                    .. " : "
                    .. known
                    .. " / "
                    .. matching
                    .. "\n"
                    .. A.T("Retained history only"),
                visibilityKey = "goal:" .. id,
                entryAction = { kind = "v2Goal", key = id },
                icon = A.metricIcons.level,
            })
        end
    end
    table.sort(model.rows, function(a, b)
        return a.visibilityKey < b.visibilityKey
    end)
end

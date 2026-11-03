-- V2 navigation and measured-point plots, using only native 11200 widgets.
-- All legacy page models remain reachable; no second collector or database.
local A, W = AzerothStats, AzerothStats.widgets
local refresh = A.RefreshUI
local function menu(anchor, choices, action)
    local options = {}
    for _, choice in ipairs(choices) do
        local key, label = choice[1], choice[2]
        table.insert(options, {
            label = A.T(label),
            value = key,
            action = function()
                action(key)
            end,
        })
    end
    A.ShowMenu(anchor, options)
end

local function section(key)
    local id = A.Selected() and A.Selected().id
    if key == "Combat" then
        A.SelectRun(id)
    else
        A.OpenReport(id)
    end
    A.view.reportSection, A.view.page = key, 1
    A.view.v2BossSample = nil
end

-- Notes belong to the retained run selected when the editor opens. Navigation
-- behind this independent dialog cannot redirect the subsequent save.
function A.V2OpenNote()
    local run = A.Selected()
    if not run then
        return
    end
    local frame = A.v2NoteWindow
    if not frame then
        frame = CreateFrame("Frame", "AzerothStatsV2Note", UIParent)
        A.v2NoteWindow = frame
        frame:SetWidth(580)
        frame:SetHeight(350)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetFrameLevel(A.window:GetFrameLevel() + 90)
        frame:SetToplevel(true)
        W.surface(frame, "window")
        W.drag(frame, "v2NotePosition")
        frame.title = W.font(frame, 24, 20, 530, 32, 22, nil, true)
        frame.context = W.font(frame, 24, 58, 530, 30, 11)
        -- A separate lower plate prevents themed BORDER art from covering the
        -- native EditBox text/caret. Mouse input belongs to the EditBox itself.
        frame.plate = CreateFrame("Frame", nil, frame)
        frame.plate:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -100)
        frame.plate:SetWidth(538)
        frame.plate:SetHeight(162)
        W.surface(frame.plate, "card")
        frame.input = CreateFrame("EditBox", nil, frame)
        frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -106)
        frame.input:SetWidth(530)
        frame.input:SetHeight(150)
        frame.input:SetMultiLine(true)
        frame.input:SetAutoFocus(false)
        frame.input:SetMaxLetters(500)
        frame.input:EnableMouse(true)
        frame.input:SetJustifyV("TOP")
        frame.input:SetScript("OnMouseDown", function()
            this:SetFocus()
        end)
        frame:SetScript("OnHide", function()
            frame.input:ClearFocus()
        end)
        frame.input:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        frame.status = W.font(frame, 24, 266, 530, 28, 11)
        frame.cancel = W.button(frame, 24, 306, 240, 26, "Cancel", function()
            frame:Hide()
        end)
        frame.apply = W.button(frame, 306, 306, 248, 26, "Apply", function()
            local value = frame.input:GetText() or ""
            if string.len(value) > 500 then
                W.put(frame.status, A.T("Text limit reached"))
            elseif A.V2SetNote(frame.runId, value) then
                frame:Hide()
                A.RefreshUI()
            else
                W.put(frame.status, A.T("Unavailable"))
            end
        end)
        frame.close = W.button(frame, 546, 14, 22, 22, "x", function()
            frame:Hide()
        end)
        if UISpecialFrames then
            table.insert(UISpecialFrames, "AzerothStatsV2Note")
        end
    end
    frame.runId = run.id
    frame:SetFrameLevel(A.window:GetFrameLevel() + 90)
    -- Native 11200 does not consistently propagate changed parent levels.
    for _, child in ipairs({ frame.input, frame.cancel, frame.apply, frame.close }) do
        child:SetFrameLevel(frame:GetFrameLevel() + 2)
    end
    frame.input:SetFont(A.Font(false), 13, "")
    frame.input:SetTextColor(unpack(A.theme.text))
    W.put(frame.title, A.T("Your note"))
    W.put(frame.context, A.RunLabel(run))
    W.put(frame.status, A.T("Local history") .. " · 500 bytes")
    W.put(frame.cancel.label, A.T("Cancel"))
    W.put(frame.apply.label, A.T("Apply"))
    frame.input:SetText((A.V2RunData(run) or {}).note or "")
    frame:Show()
    frame.plate:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.input:SetFrameLevel(frame:GetFrameLevel() + 3)
    frame.input:SetFocus()
end

-- The draft is local to the dialog. No objective is persisted before Apply.
function A.V2OpenGoal()
    if A.ui.menu then
        A.ui.menu:Hide()
    end
    local f = A.v2GoalWindow
    if not f then
        f = CreateFrame("Frame", "AzerothStatsV2Goal", UIParent)
        A.v2GoalWindow = f
        f:SetWidth(600)
        f:SetHeight(540)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        W.surface(f, "window")
        W.drag(f, "v2GoalPosition")
        f.title = W.font(f, 24, 20, 550, 32, 22, nil, true)
        f.help = W.font(f, 24, 58, 550, 36, 11)
        f.fields = {}
        for i, key in ipairs({ "metric", "class", "zone", "heroic" }) do
            local field = key
            local y = 108 + (i - 1) * 46
            f.fields[key] = W.button(f, 24, y, 550, 30, "", function(self)
                local choices = {}
                if field == "metric" then
                    for _, v in ipairs(A.v2GoalMetrics) do
                        table.insert(choices, {
                            v,
                            v == "wins" and "Wins" or v == "runs" and "Runs observed" or A.Metric(
                                v
                            ),
                        })
                    end
                elseif field == "class" then
                    table.insert(choices, { "all", "All classes" })
                    for v in pairs(A.knownClasses) do
                        if v ~= "unknown" then
                            table.insert(choices, { v, A.ClassName(v) })
                        end
                    end
                elseif field == "zone" then
                    table.insert(choices, { "all", "All zones" })
                    for v in pairs(A.gameText.en or {}) do
                        local _, _, id = string.find(v, "^zone%.([%w_%-]+)%.name$")
                        if id then
                            table.insert(choices, { id, A.ZoneName({ zone = id }) })
                        end
                    end
                else
                    table.insert(choices, { "all", "All difficulties" })
                    for v = 0, 5 do
                        table.insert(choices, { v, A.HeroicLabel({ heroic = v }) })
                    end
                end
                menu(self, choices, function(value)
                    f.draft[field] = value
                    f.update()
                end)
            end)
            W.dropdown(f.fields[key])
        end
        f.nameLabel = W.font(f, 24, 294, 550, 24, 12)
        f.targetLabel = W.font(f, 24, 368, 550, 24, 12)
        f.plates = {}
        for i, key in ipairs({ "name", "target" }) do
            local y = i == 1 and 320 or 394
            local plate = CreateFrame("Frame", nil, f)
            table.insert(f.plates, plate)
            plate:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -y)
            plate:SetWidth(550)
            plate:SetHeight(34)
            W.surface(plate, "card")
            local input = CreateFrame("EditBox", nil, f)
            f[key] = input
            input:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -y)
            input:SetWidth(530)
            input:SetHeight(34)
            input:SetAutoFocus(false)
            input:SetMaxLetters(i == 1 and 80 or 13)
            input:EnableMouse(true)
            input:SetScript("OnMouseDown", function()
                this:SetFocus()
            end)
            input:SetScript("OnEscapePressed", function()
                f:Hide()
            end)
        end
        f.status = W.font(f, 24, 436, 550, 44, 11)
        f.cancel = W.button(f, 24, 492, 240, 28, "Cancel", function()
            f:Hide()
        end)
        f.apply = W.button(f, 334, 492, 240, 28, "Add goal", function()
            local draft = A.Copy(f.draft)
            local target = f.target:GetText() or ""
            draft.target = string.find(target, "^%d+$") and tonumber(target) or nil
            draft.title = A.Text(f.name:GetText(), 80)
            if A.V2CreateGoal(draft) then
                f:Hide()
                A.view.tab, A.view.page, A.view.v2Goals = 6, 1, true
                A.RefreshUI()
            else
                W.put(f.status, A.T("Check objective fields or the 12-objective limit"))
            end
        end)
        f.close = W.button(f, 560, 14, 22, 22, "x", function()
            f:Hide()
        end)
        f:SetScript("OnHide", function()
            f.name:ClearFocus()
            f.target:ClearFocus()
            if A.ui.menu and A.ui.menu.owner == f then
                A.ui.menu:Hide()
            end
        end)
        if UISpecialFrames then
            table.insert(UISpecialFrames, "AzerothStatsV2Goal")
        end
        f.update = function()
            local d = f.draft
            W.put(
                f.fields.metric.label,
                A.T(
                    d.metric == "wins" and "Wins"
                        or d.metric == "runs" and "Runs observed"
                        or A.Metric(d.metric)
                )
            )
            W.put(
                f.fields.class.label,
                d.class == "all" and A.T("All classes") or A.ClassName(d.class)
            )
            W.put(f.fields.zone.label, d.zone == "all" and A.T("All zones") or A.ZoneName(d))
            W.put(
                f.fields.heroic.label,
                d.heroic == "all" and A.T("All difficulties") or A.HeroicLabel(d)
            )
            W.put(
                f.targetLabel,
                A.T("Target") .. (d.metric == "duration" and " · " .. A.T("Seconds") or "")
            )
            W.put(
                f.status,
                A.T(
                    d.metric == "level" and "Best level in retained completed runs"
                        or "Totals from retained completed runs; missing values excluded"
                )
            )
        end
    end
    f.draft = {
        metric = "wins",
        class = A.view.class or "all",
        zone = "all",
        heroic = type(A.view.difficulty) == "number" and A.view.difficulty or "all",
    }
    f:SetFrameLevel(A.window:GetFrameLevel() + 90)
    for _, plate in ipairs(f.plates) do
        plate:SetFrameLevel(f:GetFrameLevel() + 1)
    end
    for _, input in ipairs({ f.name, f.target }) do
        input:SetFrameLevel(f:GetFrameLevel() + 3)
        input:SetFont(A.Font(false), 14, "")
        input:SetTextColor(unpack(A.theme.text))
    end
    for _, control in pairs(f.fields) do
        control:SetFrameLevel(f:GetFrameLevel() + 3)
    end
    for _, control in ipairs({ f.apply, f.cancel, f.close }) do
        control:SetFrameLevel(f:GetFrameLevel() + 3)
    end
    W.put(f.title, A.T("Custom objective"))
    W.put(f.help, A.T("Choose a metric, scope, name and target"))
    W.put(f.nameLabel, A.T("Objective name (optional)"))
    W.put(f.apply.label, A.T("Add goal"))
    W.put(f.cancel.label, A.T("Cancel"))
    f.name:SetText("")
    f.target:SetText("1")
    f.update()
    f:Show()
    if f.Raise then
        f:Raise()
    end
    f.name:SetFocus()
end
local function addGoal()
    A.V2OpenGoal()
end

local function buildMenu(anchor)
    menu(anchor, {
        { "Spells", "Spells" },
        { "Equipment", "Equipment" },
        { "Attributes", "Attributes" },
        { "Build journal", "Build journal" },
        { "Summons", "Summons" },
        { "Effects", "Effects" },
    }, function(key)
        if key == "Spells" or key == "Equipment" then
            A.view.tab, A.view.characterTab, A.view.page = 5, key, 1
        else
            section(key)
        end
    end)
end

local function options(anchor)
    local store = A.V2Store(true)
    if not store then
        return
    end
    local rows = {}
    for _, def in ipairs({ { "summons", "Summons" }, { "effects", "Effects" } }) do
        local key = def[1]
        table.insert(rows, {
            label = A.T(def[2]) .. " · " .. A.T(
                store.preferences[key] and "Enabled" or "Disabled"
            ),
            detail = A.T("Observed presence"),
            action = function()
                store.preferences[key] = not store.preferences[key]
            end,
        })
    end
    A.ShowMenu(anchor, rows)
end

local function setup(ui)
    if ui.v2ProgressTabs then
        return
    end
    ui.v2ProgressTabs = {}
    for i, def in ipairs({
        { 6, "Records" },
        { 2, "Classes" },
        { 9, "Trends" },
        { "goals", "Personal objectives" },
    }) do
        local key, label = def[1], def[2]
        local b = W.button(A.window, 218 + (i - 1) * 180, 160, 172, 26, "", function()
            A.view.tab, A.view.page, A.view.v2Goals = key == "goals" and 6 or key, 1, key == "goals"
            A.editMode = false
            A.RefreshUI()
        end)
        b.v2Label, b.v2Tab = label, key
        table.insert(ui.v2ProgressTabs, b)
    end
    ui.v2Cohort = W.font(A.window, 218, 214, 714, 22, 11)
    ui.v2AttrTotal = W.font(A.window, 528, 322, 170, 20, 11)
    ui.v2AttrGear = W.font(A.window, 718, 322, 180, 20, 11)
    ui.v2AttrTotal:SetJustifyH("RIGHT")
    ui.v2AttrGear:SetJustifyH("RIGHT")
    ui.v2AttributeGroup = W.button(A.window, 518, 138, 198, 26, "", function(self)
        menu(self, {
            { "all", "All attributes" },
            { "essential", "Essential attributes" },
            { "advanced", "Advanced attributes" },
            { "gear", "Equipment contribution" },
        }, function(key)
            A.view.v2AttributeGroup, A.view.page = key, 1
        end)
    end)
    W.dropdown(ui.v2AttributeGroup)
    ui.v2AddGoal = W.button(A.window, 718, 138, 214, 26, "Add goal", addGoal)
    ui.v2BossBack = W.button(A.window, 218, 282, 240, 26, "Back", function()
        A.view.v2BossSample, A.view.page = nil, 1
        A.RefreshUI()
    end)
    local hero = CreateFrame("Frame", nil, A.window)
    ui.v2Hero = hero
    hero:SetPoint("TOPLEFT", A.window, "TOPLEFT", 218, -164)
    hero:SetWidth(714)
    hero:SetHeight(88)
    W.surface(hero, "card")
    hero.photo = hero:CreateTexture(nil, "ARTWORK")
    hero.photo:SetPoint("TOPLEFT", hero, "TOPLEFT", 6, -6)
    hero.photo:SetWidth(174)
    hero.photo:SetHeight(76)
    hero.title = W.font(hero, 194, 8, 370, 26, 19, A.theme.gold, true)
    hero.context = W.font(hero, 194, 36, 500, 18, 10)
    hero.status = W.font(hero, 194, 58, 280, 18, 11)
    hero.open = W.button(hero, 526, 57, 180, 26, "Analyze run", function()
        if A.run then
            A.OpenReport(A.run.id)
            A.view.reportSection = "Overview"
            A.RefreshUI()
        end
    end)
    ui.v2Options = W.button(A.window, 23, 573, 170, 31, "Optional analyses", options)
    local route = ui.nav[4]
    route.callback = function()
        section("Overview")
        A.RefreshUI()
    end
    local keys = { "Overview", "Combat", "Character", "Encounters", "Co-op", "Details" }
    for i, button in ipairs(ui.reportSections) do
        local key = keys[i]
        button.v2Key = key
        button.callback = function(self)
            if key == "Character" then
                buildMenu(self)
            elseif key == "Details" then
                menu(self, {
                    { "Records", "Records" },
                    { "Timeline", "Progression curves" },
                    { "Build journal", "Build journal" },
                    { "Observed support", "Observed support" },
                    { "note", "Your note" },
                    { "cumulative", "All runs" },
                }, function(value)
                    if value == "note" then
                        A.V2OpenNote()
                    elseif value == "cumulative" then
                        A.view.tab, A.view.cumulative, A.view.page = 4, true, 1
                    else
                        section(value)
                    end
                end)
            else
                section(key)
                A.RefreshUI()
            end
        end
    end
    local graph = CreateFrame("Frame", nil, A.window)
    ui.v2Graph = graph
    graph:SetWidth(710)
    graph:SetHeight(210)
    graph.points, graph.grid = {}, {}
    for i = 0, 3 do
        local line = W.solid(graph, 0.5, 0.5, 0.5, 0.18)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", graph, "TOPLEFT", 8, -60 - i * 40)
        line:SetWidth(690)
        line:SetHeight(1)
        table.insert(graph.grid, line)
    end
    graph.yLabel = W.font(graph, 8, 34, 150, 18, 11)
    graph.startLabel = W.font(graph, 8, 187, 100, 18, 11)
    graph.endLabel = W.font(graph, 575, 187, 130, 18, 11)
    graph.note = W.font(graph, 145, 187, 420, 18, 10)
    graph.legend = W.font(graph, 497, 0, 210, 30, 10)
    graph.metric = W.button(graph, 0, 0, 216, 26, "", function(self)
        local choices = {}
        for _, key in ipairs({ "kills", "gold", "level", "damage", "healing", "taken" }) do
            local metric = key
            table.insert(choices, {
                label = A.Metric(metric),
                action = function()
                    A.view.v2CurveMetric, A.view.page = metric, 1
                end,
            })
        end
        A.ShowMenu(self, choices)
    end)
    graph.compare = W.button(graph, 224, 0, 265, 26, "Compare runs", function(self)
        local choices = {
            {
                label = A.T("Current run"),
                action = function()
                    A.view.v2CurveCompare = nil
                end,
            },
        }
        for i = table.getn(A.db.runs), 1, -1 do
            local run = A.db.runs[i]
            local id = run.id
            table.insert(choices, {
                label = A.RunLabel(run),
                detail = A.RunContext(run),
                action = function()
                    A.view.v2CurveCompare = id
                end,
            })
        end
        A.ShowMenu(self, choices)
    end)
    W.dropdown(graph.metric)
    W.dropdown(graph.compare)
end

local function plot(ui, model)
    local graph = ui.v2Graph
    if not model.curve or A.editMode then
        graph:Hide()
        return
    end
    graph:ClearAllPoints()
    graph:SetPoint("TOPLEFT", A.window, "TOPLEFT", 218, -(model.plotTop or 290))
    graph:Show()
    local width, height = model.curveWidth or 710, model.curveHeight or 210
    local plotWidth, plotHeight = width - 24, height - 78
    graph:SetWidth(width)
    graph:SetHeight(height)
    for i, line in ipairs(graph.grid) do
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", graph, "TOPLEFT", 8, -48 - (i - 1) * plotHeight / 3)
        line:SetWidth(plotWidth)
    end
    for _, item in ipairs({
        { graph.startLabel, 8 },
        { graph.note, 105 },
        {
            graph.endLabel,
            width - 92,
        },
    }) do
        item[1]:ClearAllPoints()
        item[1]:SetPoint("TOPLEFT", graph, "TOPLEFT", item[2], -height + 20)
    end
    graph.note:SetWidth(width - 210)
    graph.note.fontWidth = width - 210
    graph.endLabel:SetWidth(90)
    graph.endLabel.fontWidth = 90
    graph.metric:SetWidth(model.v2Summary and 180 or 216)
    if model.v2Summary then
        graph.compare:Hide()
    else
        graph.compare:Show()
    end
    graph.legend:ClearAllPoints()
    graph.legend:SetPoint("TOPLEFT", graph, "TOPLEFT", model.v2Summary and 190 or 497, 0)
    graph.legend:SetWidth(model.v2Summary and 245 or 210)
    graph.legend.fontWidth = model.v2Summary and 245 or 210
    local visible = {}
    for _, item in ipairs(model.rows) do
        if item.point then
            table.insert(visible, item.point)
        end
    end
    if model.v2Summary then
        visible = model.curve
    end
    local series = { visible }
    if model.curveCompare then
        table.insert(series, A.V2Curve(model.curveCompare, model.curveMetric))
    end
    local maxT, maxY = 1, 1
    for _, points in ipairs(series) do
        for _, p in ipairs(points) do
            maxT, maxY = math.max(maxT, p.t), math.max(maxY, p.value)
        end
    end
    maxT, maxY = math.max(120, math.ceil(maxT / 60) * 60), A.V2ChartScale(maxY, 10)
    graph.axisMaxT, graph.axisMaxY = maxT, maxY
    graph.metric.label:SetWidth(graph.metric:GetWidth() - 40)
    graph.metric.label.fontWidth = graph.metric:GetWidth() - 40
    A.UpdateThemeFrame(graph.metric)
    W.put(
        graph.metric.label,
        model.curveMetric == "kills" and A.T("Cumulative kills") or A.Metric(model.curveMetric)
    )
    W.put(
        graph.compare.label,
        model.curveCompare and A.RunLabel(model.curveCompare) or A.T("Compare runs")
    )
    W.put(graph.yLabel, A.Short(maxY))
    W.put(graph.startLabel, "00:00")
    W.put(graph.endLabel, A.Duration(maxT))
    W.put(graph.note, A.T(table.getn(visible) == 0 and "No data yet" or "Sample guides"))
    W.put(
        graph.legend,
        model.curveCompare and ("A / B · " .. A.T(A.V2Context(A.Selected(), model.curveCompare)))
            or ("A · " .. (model.curveCaption or A.ZoneName(A.Selected())))
    )
    A.V2DrawChart(graph, series, plotWidth, plotHeight, maxT, maxY, model.curveMetric)
end

local function place(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", A.window, "TOPLEFT", x, -y)
end

-- Shared chrome follows the selected route, never the legacy numeric tab alone.
local function chrome(ui, model)
    local tab, analysis = A.view.tab, model.analysis
    for _, b in ipairs(ui.historySections) do
        b:Hide()
    end
    ui.reportDetails:Hide()
    ui.v2Cohort:SetText(model.cohort or "")
    if model.cohort then
        ui.v2Cohort:Show()
        ui.subtitle:Hide()
        place(ui.difficultyButton, 518, 138)
        for i, widget in ipairs(ui.historyFilters) do
            place(widget, ({ 218, 454, 610, 766 })[i], 174)
        end
    else
        ui.v2Cohort:Hide()
    end
    if model.cohort or analysis then
        ui.reportCompare:Show()
    end
    if analysis then
        ui.scopeRun:Hide()
        ui.scopeAll:Hide()
        ui.latest:Show()
    end
    for i, b in ipairs(ui.reportSections) do
        if analysis then
            b:Show()
        else
            b:Hide()
        end
        place(b, 218 + (i - 1) * 120, 246)
    end
    for i, b in ipairs(ui.characterButtons) do
        place(b, 218 + (i - 1) * 180, 286)
    end
    for i, b in ipairs(ui.modeButtons) do
        place(b, 218 + (i - 1) * 144, analysis and 286 or 160)
    end
    place(ui.journalFilter, 714, 286)
    for i, b in ipairs(ui.usageButtons) do
        place(b, 218 + (i - 1) * 240, 200)
    end
    if model.comparison then
        for i = 1, 2 do
            place(ui.compareSelectors[i], 218 + (i - 1) * 360, 160)
            place(ui.compareHeaders[i], 218 + (i - 1) * 360, 194)
            place(ui.compareColumns[i], 398 + (i - 1) * 185, 354)
        end
    end
    for i, b in ipairs(ui.compareSections) do
        place(b, 218 + (i - 1) * 180, 292)
    end
    if tab == 8 then
        place(ui.v2Options, 518, 138)
        ui.v2Options:SetWidth(198)
        ui.v2Options:Show()
    else
        ui.v2Options:Hide()
    end
    for _, b in ipairs(ui.v2ProgressTabs) do
        if tab == 2 or tab == 6 or tab == 9 then
            b:Show()
        else
            b:Hide()
        end
        W.put(b.label, A.T(b.v2Label))
        W.selected(
            b,
            b.v2Tab == "goals" and tab == 6 and A.view.v2Goals
                or b.v2Tab == tab and not (tab == 6 and A.view.v2Goals)
        )
    end
    for _, widget in ipairs({ ui.v2AttrTotal, ui.v2AttrGear, ui.v2AttributeGroup }) do
        if model.attributeTable then
            widget:Show()
        else
            widget:Hide()
        end
    end
    if model.attributeTable then
        ui.columnValue:Hide()
        place(ui.v2AttrTotal, 528, model.rowY - 28)
        place(ui.v2AttrGear, 718, model.rowY - 28)
        W.put(ui.v2AttrTotal, A.T("Observed total"))
        W.put(ui.v2AttrGear, A.T("Equipment contribution"))
        W.put(
            ui.v2AttributeGroup.label,
            A.T(({
                all = "All attributes",
                essential = "Essential attributes",
                advanced = "Advanced attributes",
                gear = "Equipment contribution",
            })[A.view.v2AttributeGroup or "all"])
        )
    end
    local counts = tab == 10 and A.FavoriteCounts() or {}
    for _, b in ipairs(ui.favoriteCategories) do
        if not b.countLabel then
            b.countLabel = W.font(b, b:GetWidth() - 30, 0, 22, 26, 11)
            b.label:SetWidth(b:GetWidth() - 44)
            b.label.fontWidth = b:GetWidth() - 44
        end
        W.put(b.label, A.T(b.categoryLabel))
        W.put(b.countLabel, A.Format(counts[b.category] or 0))
    end
end

function A.RefreshUI()
    refresh()
    local ui = A.ui
    if not ui or not ui.model or not A.window then
        return
    end
    setup(ui)
    ui.v2Hero:Hide()
    local nav = {
        { 1, 221, "Overview" },
        { 3, 277, "My runs" },
        { 4, 333, "Analyze run" },
        { 6, 389, "My progress" },
        { 10, 445, "My favorites" },
        { 11, 501, "Nemesis" },
        { 8, 666, "Settings" },
        { 7, 709, "Diagnostics" },
    }
    for _, i in ipairs({ 2, 5, 9 }) do
        ui.nav[i]:Hide()
    end
    local tab = A.view.tab
    if ui.model.report and A.view.reportSection == "Encounters" and A.view.v2BossSample then
        ui.v2BossBack:Show()
        W.put(ui.v2BossBack.label, A.T("Back") .. " · " .. A.T("Encounters"))
    else
        ui.v2BossBack:Hide()
    end
    if tab == 6 and A.view.v2Goals and not A.editMode then
        ui.v2AddGoal:Show()
        W.put(ui.v2AddGoal.label, A.T("Add goal"))
    else
        ui.v2AddGoal:Hide()
    end
    local analyzing = tab == 4 or tab == 5 or (tab == 3 and ui.model.report)
    for _, def in ipairs(nav) do
        local b = ui.nav[def[1]]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", A.window, "TOPLEFT", 23, -def[2])
        W.put(b.label, A.T(def[3]))
        b:Show()
        local active = def[1] == tab
        if def[1] == 3 then
            active = tab == 3 and not ui.model.report
        elseif def[1] == 4 then
            active = analyzing
        elseif def[1] == 6 then
            active = tab == 2 or tab == 6 or tab == 9
        end
        W.selected(b, active)
    end
    ui.progression:Hide()
    W.put(ui.v2Options.label, A.T("Optional analyses"))
    for _, b in ipairs(ui.reportSections) do
        W.put(
            b.label,
            A.T(
                b.v2Key == "Character" and "Build" or b.v2Key == "Overview" and "Summary" or b.v2Key
            )
        )
        local section = tab == 5 and "Character" or tab == 4 and "Combat" or A.view.reportSection
        local active = section == b.v2Key
        if b.v2Key == "Character" then
            active = section == "Character"
                or section == "Attributes"
                or section == "Summons"
                or section == "Effects"
                or section == "Build journal"
        elseif b.v2Key == "Details" then
            active = section == "Records" or section == "Timeline" or section == "Observed support"
        end
        W.selected(b, active)
    end
    chrome(ui, ui.model)
    plot(ui, ui.model)
    A.V2SummaryUI(ui, ui.model)
end

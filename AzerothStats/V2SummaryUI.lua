-- Summary-only composition of existing models. Own reusable frames; no gameplay
-- hooks or data collection. Editing falls back to the full editable data list.
local A, W = AzerothStats, AzerothStats.widgets
local function place(frame, parent, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if width then
        frame:SetWidth(width)
    end
    if height then
        frame:SetHeight(height)
    end
    if width and frame.label and frame:GetObjectType() == "Button" then
        frame.label:SetWidth(width - 38)
        frame.label.fontWidth = width - 38
    end
    if frame.materialParts then
        A.UpdateThemeFrame(frame)
    end
end
local function panel(parent)
    local f = CreateFrame("Frame", nil, parent)
    W.surface(f, "card")
    f.title = W.font(f, 12, 8, 210, 24, 17, nil, true)
    f.body = W.font(f, 12, 38, 210, 120, 11)
    f.body:SetJustifyV("TOP")
    f.open = W.button(f, 12, 140, 210, 26, "", function(self)
        if self.action then
            self.action()
            A.RefreshUI()
        end
    end)
    return f
end
local function setup(ui)
    if ui.v2SummaryPanels then
        return
    end
    ui.v2SummaryPanels = {}
    for _, key in ipairs({ "takeaways", "goal", "context", "moments", "note" }) do
        ui.v2SummaryPanels[key] = panel(A.window)
    end
    ui.v2ChooseHint = W.font(ui.context, 500, 43, 200, 18, 11)
    ui.v2ChooseHint:SetJustifyH("RIGHT")
    ui.context:SetScript("OnClick", function()
        if A.ui.model.analysis then
            A.RunMenu(this)
        end
    end)
end
local function showPanel(ui, model, key, x, y, w, h, target, caption)
    local f = ui.v2SummaryPanels[key]
    local item
    for _, candidate in ipairs(model.sections or {}) do
        if candidate.summaryPart == key then
            item = candidate
            break
        end
    end
    if not item then
        f:Hide()
        return
    end
    place(f, A.window, x, y, w, h)
    A.UpdateThemeFrame(f)
    f.title:SetWidth(w - 24)
    f.title.fontWidth = w - 24
    f.body:SetWidth(w - 24)
    f.body.fontWidth = w - 24
    f.body:SetHeight(h - (target and 78 or 46))
    W.put(f.title, item.label)
    W.put(f.body, item.detail)
    if target then
        place(f.open, f, 12, h - 34, w - 24, 26)
        f.open.action = target
        W.put(f.open.label, A.T(caption))
        f.open:Show()
    else
        f.open:Hide()
    end
    f:Show()
end
local function openGoals()
    A.view.tab, A.view.page, A.view.v2Goals = 6, 1, true
end
local function openJournal()
    A.OpenReport(A.Selected() and A.Selected().id)
    A.view.reportSection, A.view.journalKind = "Build journal", nil
end
function A.V2SummaryUI(ui, model)
    setup(ui)
    for _, f in pairs(ui.v2SummaryPanels) do
        f:Hide()
    end
    if model.analysis then
        place(ui.latest, A.window, 578, 100, 354, 26)
        W.put(
            ui.latest.label,
            A.T("Choose run")
                .. " · "
                .. A.ZoneName(
                    A.view.selected and A.FindRun(A.view.selected)
                        or (not A.view.selected and A.Selected())
                )
        )
        W.put(ui.v2ChooseHint, A.T("Choose run") .. "  ▾")
        ui.v2ChooseHint:Show()
    else
        ui.v2ChooseHint:Hide()
    end
    if model.cohort then
        -- Title action, filter row, search row, then cohort: no scattered buttons.
        place(ui.reportCompare, A.window, 718, 100, 214, 26)
        place(ui.classButton, A.window, 218, 138, 198, 26)
        place(ui.difficultyButton, A.window, 426, 138, 198, 26)
        place(ui.editToggle, A.window, 734, 138, 198, 26)
    else
        place(ui.classButton, A.window, 714, 100, 218, 26)
        place(ui.editToggle, A.window, 834, 138, 98, 24)
        place(ui.reportCompare, A.window, 518, 138, 198, 26)
    end
    if model.attributeTable then
        -- Keep the filter next to its data-column headings, leaving the full
        -- compare label readable in the shared action row.
        place(ui.v2AttributeGroup, A.window, 218, model.rowY - 32, 286, 26)
        ui.columnLabel:Hide()
    end
    if A.view.tab == 6 and A.view.v2Goals then
        place(ui.v2AddGoal, A.window, 518, 138, 198, 26)
    end
    if A.view.tab == 10 then
        for i, b in ipairs(ui.favoriteCategories) do
            place(
                b,
                A.window,
                218 + math.mod(i - 1, 3) * 240,
                160 + math.floor((i - 1) / 3) * 34,
                232,
                26
            )
            b.label:SetWidth(188)
            b.label.fontWidth = 188
            place(b.countLabel, b, 202, 0, 22, 26)
            W.put(b.label, A.T(b.categoryLabel))
            A.UpdateThemeFrame(b)
        end
    end
    if not model.v2Summary then
        return
    end
    if A.editMode then
        ui.v2Graph:Hide()
        ui.v2Hero:Hide()
        return
    end
    local hasCurve = false
    for _, item in ipairs(model.sections or {}) do
        if item.summaryPart == "curve" then
            hasCurve = true
        end
    end
    if not hasCurve then
        ui.v2Graph:Hide()
    end
    ui.empty:Hide()
    ui.columnLabel:Hide()
    ui.columnValue:Hide()
    ui.previous:Hide()
    ui.next:Hide()
    ui.paging:Hide()
    if model.v2Summary == "home" then
        local live, hero = model.liveHero, ui.v2Hero
        place(hero, A.window, 218, 164, 714, 68)
        A.UpdateThemeFrame(hero)
        if live then
            A.ZoneIllustration(hero.photo, live.zone)
            W.put(hero.title, A.ZoneName(live))
            W.put(hero.context, A.ClassName(live.class) .. " · " .. A.HeroicLabel(live))
            W.put(
                hero.status,
                A.T(live.prepared and "Ready" or "Current run")
                    .. (live.prepared and "" or " · " .. A.Duration(live.values.duration))
            )
        else
            A.ZoneIllustration(hero.photo, nil)
            W.put(hero.title, A.T("Outside a run"))
            W.put(hero.context, A.T("Start a run to begin"))
            W.put(hero.status, "")
        end
        place(hero.photo, hero, 6, 6, 110, 56)
        place(hero.title, hero, 132, 4, 370, 24)
        place(hero.context, hero, 132, 28, 370, 17)
        place(hero.status, hero, 132, 46, 370, 17)
        place(hero.open, hero, 526, 34, 180, 26)
        W.put(hero.open.label, A.T("Analyze run"))
        if live and live.id then
            hero.open:Show()
        else
            hero.open:Hide()
        end
        hero:Show()
        for i, card in ipairs(ui.cards) do
            if card:IsShown() then
                place(
                    card,
                    A.window,
                    218 + (i - 1) * 181,
                    244,
                    A.theme.material == "flat" and 168 or 171,
                    A.theme.quiet and 90 or 94
                )
                place(card.icon, card, 129, 8, 32, 32)
                place(card.label, card, 10, 10, 115, 22)
                place(card.value, card, 10, 40, 150, 34)
                card.label.fontWidth, card.value.fontWidth = 115, 150
                card.label.baseSize, card.value.baseSize = 12, 26
                card.label:SetJustifyH("LEFT")
                card.value:SetJustifyH("LEFT")
                W.put(card.label, card.item.label)
                W.put(card.value, card.item.value)
                card.detail:Hide()
                A.UpdateThemeFrame(card)
            end
        end
        place(ui.recentTitle, A.window, 218, 348, 270, 28)
        place(ui.historyLink, A.window, 524, 348, 134, 26)
        ui.recordsTitle:Hide()
        ui.recordsLink:Hide()
        ui.recordPanel:Hide()
        for _, r in ipairs(ui.rows) do
            if r:IsShown() then
                r:SetWidth(440)
                place(r.thumbnail, r, 4, 4, 84, 42)
                place(r.label, r, 100, 2, 200, 23)
                r.label.fontWidth, r.label.baseSize = 200, 13
                place(r.detail, r, 100, 26, 300, 18)
                r.detail.fontWidth = 300
                place(r.value, r, 300, 2, 110, 23)
                r.value.fontWidth = 110
                place(r.favorite, r, 412, 2, 24, 24)
                W.put(r.label, r.item.label)
                W.put(r.detail, r.item.detail)
                local run = A.FindRun(r.item.favorite.key)
                local status = run.status == "active" and "active" or run.result or run.status
                r.value:SetTextColor(
                    unpack(
                        status == "victory" and A.theme.green
                            or status == "defeat" and A.theme.red
                            or A.theme.gold
                    )
                )
                W.put(r.value, A.Status(status))
                W.put(r.detail, A.Duration(run.values.duration) .. " · " .. r.item.detail)
            end
        end
        showPanel(ui, model, "takeaways", 678, 348, 254, 208, function()
            A.OpenReport(model.curveRun and model.curveRun.id)
            A.view.reportSection = "Overview"
        end, "Analyze run")
        showPanel(ui, model, "goal", 678, 568, 254, 132, openGoals, "Personal objectives")
    else
        for i, card in ipairs(ui.cards) do
            if card:IsShown() then
                place(card, A.window, 218 + (i - 1) * 181, 292, 171, 104)
                place(card.label, card, 10, 8, 120, 23)
                card.label.fontWidth = 120
                place(card.value, card, 10, 36, 150, 34)
                card.value.fontWidth = 150
                place(card.detail, card, 10, 77, 150, 18)
                card.detail.fontWidth = 150
                place(card.icon, card, 135, 9, 26, 26)
                W.put(card.label, card.item.label)
                W.put(card.value, card.item.value)
                W.put(card.detail, card.item.detail)
                A.UpdateThemeFrame(card)
            end
        end
        for _, r in ipairs(ui.rows) do
            r:Hide()
        end
        ui.note:Hide()
        showPanel(ui, model, "context", 678, 410, 254, 178)
        showPanel(ui, model, "moments", 218, 570, 440, 130, openJournal, "Build journal")
        showPanel(ui, model, "note", 678, 600, 254, 100, A.V2OpenNote, "Edit note")
    end
end

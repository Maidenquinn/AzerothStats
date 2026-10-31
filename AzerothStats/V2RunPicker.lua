-- Read-only run chooser. Six reusable illustrated rows replace the dense menu.
-- Search is literal/local; choosing a retained ID changes navigation only.
local A, W = AzerothStats, AzerothStats.widgets
function A.V2RunChoices(query)
    local out = {}
    query = string.lower(A.Text(query or "", 80) or "")
    for i = table.getn(A.db.runs), 1, -1 do
        local run = A.db.runs[i]
        local text = A.ZoneName(run)
            .. " "
            .. A.ClassName(run.class)
            .. " "
            .. (run.hero or "")
            .. " "
            .. A.Date(run.startedAt)
            .. " "
            .. A.HeroicLabel(run)
            .. " "
            .. A.Status(run.result or run.status)
        if query == "" or string.find(string.lower(text), query, 1, true) then
            table.insert(out, run)
        end
    end
    return out
end
local function choose(id)
    if not A.FindRun(id) then
        return false
    end
    A.view.selected, A.view.cumulative, A.view.page = id, false, 1
    A.v2RunPicker:Hide()
    A.RefreshUI()
    return true
end
function A.V2RefreshRunPicker()
    local f = A.v2RunPicker
    if not f then
        return
    end
    local choices = A.V2RunChoices(f.search:GetText())
    local pages = math.max(1, math.ceil(table.getn(choices) / 6))
    f.page = math.min(pages, math.max(1, f.page or 1))
    W.put(f.title, A.T("Choose run"))
    W.put(f.searchLabel, A.T("Search runs"))
    W.put(f.empty, A.T("No data yet"))
    if table.getn(choices) == 0 then
        f.empty:Show()
    else
        f.empty:Hide()
    end
    W.put(
        f.paging,
        A.Format(table.getn(choices))
            .. " · "
            .. A.T("Retained runs")
            .. " · "
            .. A.T("Page")
            .. " "
            .. f.page
            .. " / "
            .. pages
    )
    for i, b in ipairs(f.rows) do
        local run = choices[(f.page - 1) * 6 + i]
        b.runId = run and run.id
        if run then
            local status = run.status == "active" and "active" or run.result or run.status
            A.ZoneIllustration(b.photo, run.zone)
            W.put(b.label, A.ZoneName(run))
            W.put(
                b.context,
                A.Date(run.startedAt)
                    .. " · "
                    .. A.ClassName(run.class)
                    .. " · "
                    .. A.HeroicLabel(run)
            )
            W.put(b.result, A.Status(status))
            b.result:SetTextColor(
                unpack(
                    status == "victory" and A.theme.green
                        or status == "defeat" and A.theme.red
                        or A.theme.gold
                )
            )
            W.put(b.duration, A.Duration(run.values.duration))
            W.selected(
                b,
                run.id == A.view.selected or (not A.view.selected and run == A.Selected())
            )
            b:Show()
        else
            b:Hide()
        end
    end
    if pages > 1 then
        f.previous:Show()
        f.next:Show()
    else
        f.previous:Hide()
        f.next:Hide()
    end
end
local function setup()
    local f = CreateFrame("Frame", "AzerothStatsV2RunPicker", UIParent)
    A.v2RunPicker = f
    f:SetWidth(600)
    f:SetHeight(548)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    W.surface(f, "window")
    local handle = CreateFrame("Frame", nil, f)
    handle:SetWidth(550)
    handle:SetHeight(52)
    handle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    W.drag(f, "v2RunPickerPosition", handle)
    f.title = W.font(f, 24, 14, 500, 32, 23, nil, true)
    f.close = W.button(f, 552, 14, 24, 24, "x", function()
        f:Hide()
    end)
    local plate = CreateFrame("Frame", nil, f)
    plate:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -62)
    plate:SetWidth(552)
    plate:SetHeight(42)
    W.surface(plate, "card")
    f.searchPlate = plate
    f.searchLabel = W.font(plate, 10, 0, 530, 15, 10)
    f.search = CreateFrame("EditBox", nil, f)
    f.search:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -79)
    f.search:SetWidth(530)
    f.search:SetHeight(22)
    f.search:SetAutoFocus(false)
    f.search:SetMaxLetters(80)
    f.search:EnableMouse(true)
    f.search:SetScript("OnMouseDown", function()
        this:SetFocus()
    end)
    f.search:SetScript("OnTextChanged", function()
        f.page = 1
        A.V2RefreshRunPicker()
    end)
    f.search:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    f:SetScript("OnHide", function()
        f.search:ClearFocus()
    end)
    f.rows = {}
    for i = 1, 6 do
        local b = W.button(f, 24, 116 + (i - 1) * 62, 552, 56, "", function(self)
            choose(self.runId)
        end)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 100, -3)
        b.label:SetHeight(24)
        b.label:SetWidth(312)
        b.label.fontWidth = 312
        b.label.baseSize = 14
        b.photo = b:CreateTexture(nil, "ARTWORK")
        b.photo:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
        b.photo:SetWidth(84)
        b.photo:SetHeight(46)
        b.context = W.font(b, 100, 30, 322, 19, 10)
        b.result = W.font(b, 424, 4, 116, 23, 12)
        b.result:SetJustifyH("RIGHT")
        b.duration = W.font(b, 444, 30, 96, 19, 11)
        b.duration:SetJustifyH("RIGHT")
        table.insert(f.rows, b)
    end
    f.empty = W.font(f, 24, 236, 552, 44, 16)
    f.paging = W.font(f, 24, 508, 400, 24, 11)
    f.previous = W.button(f, 472, 508, 46, 26, "<", function()
        f.page = f.page - 1
        A.V2RefreshRunPicker()
    end)
    f.next = W.button(f, 530, 508, 46, 26, ">", function()
        f.page = f.page + 1
        A.V2RefreshRunPicker()
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "AzerothStatsV2RunPicker")
    end
    return f
end
function A.RunMenu(anchor)
    if A.ui.menu then
        A.ui.menu:Hide()
    end
    local f = A.v2RunPicker or setup()
    f:SetFrameLevel(A.window:GetFrameLevel() + 80)
    f.searchPlate:SetFrameLevel(f:GetFrameLevel() + 1)
    f.search:SetFrameLevel(f:GetFrameLevel() + 3)
    for _, b in ipairs(f.rows) do
        b:SetFrameLevel(f:GetFrameLevel() + 2)
    end
    for _, b in ipairs({ f.previous, f.next, f.close }) do
        b:SetFrameLevel(f:GetFrameLevel() + 2)
    end
    f.search:SetFont(A.Font(false), 13, "")
    f.search:SetTextColor(unpack(A.theme.text))
    f.page = 1
    f.search:SetText("")
    A.V2RefreshRunPicker()
    f:Show()
end

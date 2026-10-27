-- Native 11200 widgets owned by Azeroth Stats.
-- Legacy handlers use client-provided this/event/arg1 globals, not modern self args.
-- All callbacks below are local closures; no saved string is evaluated as code.
-- Widget changes affect addon frames/tooltips only, not character/game state.

local A = AzerothStats
local UI = { fonts = {}, solids = {}, cards = {}, rows = {}, nav = {}, controls = {} }
A.ui = UI
local COLORS = A.theme

local coords = {
    warrior = { 0, 0.25, 0, 0.25 },
    mage = { 0.25, 0.496, 0, 0.25 },
    rogue = { 0.496, 0.742, 0, 0.25 },
    druid = { 0.742, 0.988, 0, 0.25 },
    hunter = { 0, 0.25, 0.25, 0.5 },
    shaman = { 0.25, 0.496, 0.25, 0.5 },
    priest = { 0.496, 0.742, 0.25, 0.5 },
    warlock = { 0.742, 0.988, 0.25, 0.5 },
    paladin = { 0, 0.25, 0.5, 0.75 },
}

--- Create an owned font string and retain its sizing metadata for accessible repainting.
local function font(parent, x, y, w, h, size, color, title)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    t:SetWidth(w)
    t:SetHeight(h)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("MIDDLE")
    t.baseSize = size or 12
    t.titleFont = title
    t.fontWidth = w
    color = color or COLORS.text
    t:SetTextColor(color[1], color[2], color[3])
    table.insert(UI.fonts, t)
    return t
end

--- Bound and paint display text, caching font/text state and shrinking only within the readability floor.
local function put(t, value)
    value = string.sub(tostring(value or ""), 1, 4096)
    local size = t.baseSize
        * ((t.titleFont or t.fixedSize) and 1 or ((A.db and A.db.settings.textSize or 12) / 12))
    size = math.max(11, size)
    local path = A.Font(t.titleFont, t.localeFont)
    if
        t.fullText == value
        and t.paintFont == path
        and t.paintBase == size
        and t.paintWidth == t.fontWidth
    then
        return
    end
    t.fullText = value
    t.paintFont = path
    t.paintBase = size
    t.paintWidth = t.fontWidth
    if t.activeFont ~= path or t.activeSize ~= size then
        t:SetFont(path, size, "")
    end
    t:SetText(value)
    if t.GetStringWidth then
        while size > 11 and t:GetStringWidth() > t.fontWidth do
            size = size - 0.5
            t:SetFont(path, size, "")
        end
    end
    t.activeFont = path
    t.activeSize = size
end

--- Create one flat owned background texture with the requested color/alpha.
local function solid(parent, r, g, b, alpha, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(parent)
    t:SetTexture(r, g, b)
    t:SetAlpha(alpha or 1)
    return t
end

--- Apply an owned frame backdrop and register its base for opacity updates.
local function surface(frame, kind)
    local color = kind == "card" and A.theme.panel or A.theme.background
    local base = solid(frame, color[1], color[2], color[3], 1)
    table.insert(UI.solids, { texture = base, main = kind == "main" })
    local grain = frame:CreateTexture(nil, "BACKGROUND")
    grain:SetAllPoints(frame)
    grain:SetTexture(A.theme.grain)
    grain:SetAlpha(0.16)
    table.insert(UI.solids, { texture = grain, multiplier = 0.16 })
    frame.grain = grain
    frame:SetBackdrop({
        edgeFile = A.theme.edge,
        edgeSize = kind == "main" and 32 or 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropBorderColor(0.85, 0.71, 0.42, 1)
    frame.base = base
    return base
end

--- Resolve a fixed class atlas or a validated Interface icon path, with a known fallback.
local function icon(tex, name, cls)
    if cls and coords[cls] then
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(unpack(coords[cls]))
    else
        name = A.TexturePath(name) or "Interface\\Icons\\INV_Misc_Book_09"
        if not string.find(name, "\\", 1, true) and not string.find(name, "/", 1, true) then
            name = "Interface\\Icons\\" .. name
        end
        tex:SetTexture(name)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

--- Display a row/card explanation or delegate to the bounded item tooltip renderer.
local function tooltip(frame)
    if not frame.item then
        return
    end
    local d = frame.item
    if A.ItemTooltip(frame, d) then
        return
    end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.label or "Azeroth Stats", 0.95, 0.8, 0.5)
    if d.value then
        GameTooltip:AddLine(d.exact or d.value, 0.94, 0.92, 0.87)
    end
    if d.detail and d.detail ~= "" then
        GameTooltip:AddLine(d.detail, 0.7, 0.68, 0.61, true)
    end
    if d.action then
        GameTooltip:AddLine(A.T("Click to inspect"), 0.5, 0.8, 0.5)
    end
    GameTooltip:Show()
end

--- Paint the active-state background/border of an addon button.
local function selected(b, active)
    b.selected = active and true or false
    b.base:SetTexture(active and 0.21 or 0.063, active and 0.17 or 0.09, active and 0.10 or 0.106)
    b.base:SetAlpha(A.db.settings.opacity)
    b:SetBackdropBorderColor(0.85, 0.71, 0.42, (b.navigation and not active) and 0 or 1)
    if b.marker then
        if active then
            b.marker:Show()
        else
            b.marker:Hide()
        end
    end
end

--- Add a native arrow to an owned button and reserve label space for it.
local function dropdown(b)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -5, 0)
    b.arrow:SetWidth(20)
    b.arrow:SetHeight(20)
    b.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    b.label:SetWidth(b:GetWidth() - 40)
    b.label.fontWidth = b:GetWidth() - 40
end

--- Create a trusted local button callback and standard hover visuals.
local function button(parent, x, y, w, h, label, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    b:SetWidth(w)
    b:SetHeight(h or 27)
    surface(b, "button")
    b.label = font(b, 10, 0, w - 20, h or 27, 12, COLORS.gold)
    b.key = label
    b.callback = fn
    b:SetScript("OnClick", function()
        if this.callback then
            this.callback(this)
        end
    end)
    b:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(0.9, 0.7, 0.34, 1)
    end)
    b:SetScript("OnLeave", function()
        selected(this, this.selected)
    end)
    table.insert(UI.controls, b)
    return b
end

--- Create an owned heart control; only user clicks change local bookmark data.
local function favoriteButton(parent, x, y)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    b:SetWidth(24)
    b:SetHeight(24)
    b.heart = b:CreateTexture(nil, "ARTWORK")
    b.heart:SetAllPoints()
    b:SetScript("OnClick", function()
        if this.favorite then
            A.ToggleFavorite(this.favorite)
            A.RefreshUI()
        end
    end)
    b:SetScript("OnEnter", function()
        local d = this.favorite
        if not d then
            return
        end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(
            A.T(A.IsFavorite(d.kind, d.key) and "Remove favorite" or "Add favorite"),
            1,
            0.82,
            0.4
        )
        GameTooltip:AddLine(d.label or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return b
end

--- Choose one of two bundled fixed heart textures from the bookmark state.
local function paintFavorite(b)
    local d = b.favorite
    if not d then
        return
    end
    b.heart:SetTexture(
        "Interface\\AddOns\\AzerothStats\\media\\"
            .. (
                A.IsFavorite(d.kind, d.key) and "FavoriteHeartFilled.tga"
                or "FavoriteHeartEmpty.tga"
            )
    )
end

--- Change local page state and close the owned popup menu.
local function selectTab(i)
    A.view.tab = i
    A.view.page = 1
    if i == 9 then
        A.view.cumulative = A.view.usageTab ~= "Co-op"
    end
    if UI.menu then
        UI.menu:Hide()
    end
    A.RefreshUI()
end

--- Attach legacy mouse handlers that save only an addon frame position when unlocked.
local function drag(frame, key)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
    frame:SetScript("OnDragStart", function()
        if not A.db.settings.locked then
            this:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local p, _, rel, x, y = this:GetPoint()
        A.db.settings[key] = { p, rel, x, y }
    end)
end

--- Restore a normalized own frame anchor or use the supplied default position.
local function place(frame, key, p, x, y)
    local settings = A.db.settings[key]
    frame:ClearAllPoints()
    if
        type(settings) == "table"
        and type(settings[1]) == "string"
        and type(settings[2]) == "string"
        and type(settings[3]) == "number"
        and type(settings[4]) == "number"
    then
        frame:SetPoint(
            settings[1],
            UIParent,
            settings[2],
            math.max(-600, math.min(600, settings[3])),
            math.max(-450, math.min(450, settings[4]))
        )
    else
        frame:SetPoint(p, UIParent, p, x, y)
    end
end

--- Render a bounded page of trusted local options, reusing popup widgets.
function A.ShowMenu(anchor, options, offset)
    if not offset and UI.menu and UI.menu.anchor == anchor and UI.menu:IsShown() then
        UI.menu:Hide()
        return
    end
    if not UI.menu then
        UI.menu = CreateFrame("Frame", "AzerothStatsMenu", A.window)
        surface(UI.menu, "main")
        UI.menu:SetFrameStrata("DIALOG")
        UI.menu:SetFrameLevel(A.window:GetFrameLevel() + 30)
        UI.menu.items = {}
    end
    local menu = UI.menu
    if menu.SetClampedToScreen then
        menu:SetClampedToScreen(true)
    end
    local all = options
    offset = offset or 1
    if table.getn(all) > 15 then
        options = {}
        if offset > 1 then
            table.insert(options, {
                label = "<  " .. A.T("Page"),
                action = function()
                    A.ShowMenu(anchor, all, math.max(1, offset - 12))
                end,
            })
        end
        for i = offset, math.min(table.getn(all), offset + 11) do
            table.insert(options, all[i])
        end
        if offset + 12 <= table.getn(all) then
            table.insert(options, {
                label = A.T("Page") .. "  >",
                action = function()
                    A.ShowMenu(anchor, all, offset + 12)
                end,
            })
        end
    end
    menu.anchor = anchor
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)
    menu:SetWidth(268)
    menu:SetHeight(table.getn(options) * 24 + 12)
    for i, entry in ipairs(options) do
        local b = menu.items[i]
        if not b then
            b = button(menu, 6, 6 + (i - 1) * 24, 256, 24, "", function(self)
                local action = self.option.action
                menu:Hide()
                action()
                A.RefreshUI()
            end)
            menu.items[i] = b
        end
        b.option = entry
        b.label.localeFont = entry.locale
        put(b.label, entry.label)
        b:Show()
    end
    for i = table.getn(options) + 1, table.getn(menu.items) do
        menu.items[i]:Hide()
    end
    menu:Show()
end

--- Build a local class-filter menu from the own validated aggregate keys.
function A.CycleClass()
    local options = {
        {
            label = A.T("All classes"),
            action = function()
                A.view.class = nil
                A.view.page = 1
            end,
        },
    }
    local keys = {}
    for cls in pairs(A.db.classes) do
        table.insert(keys, cls)
    end
    table.sort(keys)
    for _, cls in ipairs(keys) do
        local c = cls
        table.insert(options, {
            label = A.ClassName(c),
            action = function()
                A.view.class = c
                A.view.page = 1
            end,
        })
    end
    A.ShowMenu(UI.classButton, options)
end

--- Build a paginated local selector of retained runs.
function A.RunMenu(anchor)
    local options = {
        {
            label = A.T(A.run and A.run.status == "active" and "Current run" or "Latest run"),
            action = function()
                A.view.selected = nil
                A.view.cumulative = false
                A.view.page = 1
            end,
        },
    }
    for i = table.getn(A.db.runs), 1, -1 do
        local r = A.db.runs[i]
        local id = r.id
        if r ~= (A.run or A.db.runs[table.getn(A.db.runs)]) then
            table.insert(options, {
                label = A.Date(r.startedAt)
                    .. " · "
                    .. A.ClassName(r.class)
                    .. " · "
                    .. A.Duration(r.values.duration),
                action = function()
                    A.view.selected = id
                    A.view.cumulative = false
                    A.view.page = 1
                end,
            })
        end
    end
    A.ShowMenu(anchor, options)
end

--- Apply pending settings only after release, preventing scale/coordinate feedback during dragging.
function A.CommitSliders()
    local changed = false
    for _, sl in ipairs(UI.sliders or {}) do
        if sl.pending then
            A.db.settings[sl.setting] = sl.pending
            sl.pending = nil
            sl.pendingAt = nil
            changed = true
        end
        sl.dragging = nil
    end
    if changed then
        A.ApplyUI()
        A.RefreshUI()
    end
end

--- Clamp scale to the screen and apply own opacity/visibility settings without changing client CVars.
function A.ApplyUI()
    if not A.window then
        return
    end
    local settings = A.db.settings
    local fit = math.min(
        settings.scale,
        math.max(0.45, (UIParent:GetWidth() - 24) / 960),
        math.max(0.45, (UIParent:GetHeight() - 40) / 650)
    )
    UI.effectiveScale = fit
    local old = A.window:GetScale()
    if old ~= fit then
        -- Keep the saved physical anchor stable while changing the window's coordinate scale.
        local p, parent, rel, x, y = A.window:GetPoint()
        A.window:SetScale(fit)
        if p and x and y then
            A.window:ClearAllPoints()
            A.window:SetPoint(p, parent, rel, x * old / fit, y * old / fit)
            if settings.windowPos then
                settings.windowPos = { p, rel, x * old / fit, y * old / fit }
            end
        end
    end
    for _, t in ipairs(UI.fonts) do
        put(t, t.fullText or "")
    end
    for _, v in ipairs(UI.solids) do
        v.texture:SetAlpha(settings.opacity * (v.multiplier or 1))
    end
    if UI.menu then
        UI.menu.base:SetAlpha(1)
    end
    A.RefreshBar()
    if settings.bar then
        A.bar:Show()
    else
        A.bar:Hide()
    end
    if settings.minimap then
        A.mini:Show()
    else
        A.mini:Hide()
    end
end

--- Reset only the addon window/bar/minimap-button anchors to known defaults.
function A.ResetPosition()
    A.db.settings.windowPos = nil
    A.db.settings.barPos = nil
    A.db.settings.miniAngle = 0.785398
    place(A.window, "windowPos", "CENTER", 0, 0)
    place(A.bar, "barPos", "TOP", 0, -38)
    A.mini:ClearAllPoints()
    A.mini:SetPoint("CENTER", Minimap or UIParent, "CENTER", 56, 56)
end

--- Toggle an owned widget from a boolean condition.
local function show(frame, yes)
    if yes then
        frame:Show()
    else
        frame:Hide()
    end
end

--- Synchronize own option widgets without recursively triggering live slider updates.
local function settingsRefresh()
    local settings = A.db.settings
    for _, b in ipairs(UI.checks) do
        b:SetChecked(settings[b.setting])
        put(b.caption, A.T(b.key))
    end
    for _, sl in ipairs(UI.sliders) do
        local value = sl.pending or settings[sl.setting]
        if not sl.dragging then
            sl.syncing = true
            sl:SetValue(value)
            sl.syncing = nil
        end
        put(sl.caption, A.T(sl.key))
        put(
            sl.number,
            sl.setting == "opacity" and (math.floor(value * 100 + 0.5) .. "%")
                or A.Decimal(value, sl.setting == "textSize" and 0 or 2)
        )
    end
    put(
        UI.scaleHint,
        A.T("Applied on release")
            .. (
                settings.scale > (UI.effectiveScale or settings.scale) + 0.001
                    and (" · " .. A.T("Screen limit") .. " " .. A.Decimal(UI.effectiveScale, 2))
                or ""
            )
    )
    put(UI.textHint, A.T("Applied on release"))
    local chosen = settings.language or "auto"
    local label = A.T("Automatic")
    for _, lg in ipairs(A.languages) do
        if lg[1] == chosen then
            label = lg[1] == "auto" and A.T("Automatic") or lg[2]
        end
    end
    if chosen == "auto" then
        for _, lg in ipairs(A.languages) do
            if lg[1] == A.Locale() then
                label = label .. " · " .. lg[2]
            end
        end
    end
    UI.language.label.localeFont = chosen == "auto" and A.Locale() or chosen
    put(UI.language.label, label)
    put(UI.languageCaption, A.T("Language"))
    put(UI.retentionCaption, A.T("Retained runs"))
    put(UI.retention.label, A.Format(settings.maxRuns))
    put(UI.appearance, A.T("Appearance"))
    put(UI.behaviour, A.T("Behaviour"))
    put(UI.storage, A.T("Storage"))
    put(UI.saveNote, A.T("Saved on normal game exit"))
end

--- Paint the active model and local top bar; skip expensive page building while the window is hidden.
function A.RefreshUI()
    if not A.window then
        return
    end
    local settings = A.db.settings
    settings.view = {
        tab = A.view.tab,
        mode = A.view.mode,
        class = A.view.class,
        cumulative = A.view.cumulative,
        characterTab = A.view.characterTab,
        usageTab = A.view.usageTab,
        favoriteCategory = A.view.favoriteCategory or "run",
        overviewStats = A.view.overviewStats == true,
    }
    local live = A.run
    local r = A.Selected()
    A.RefreshBar()
    if not A.window:IsShown() then
        return
    end
    local model = A.PageModel()
    UI.model = model
    put(UI.title, "AZEROTH STATS")
    put(UI.version, A.version)
    put(
        UI.breadcrumb,
        (A.view.tab == 4 or A.view.tab == 9)
                and A.view.cumulative
                and (A.T("All runs") .. " · " .. (A.view.class and A.ClassName(A.view.class) or A.T(
                    "All classes"
                )))
            or r and ((r.hero or "?") .. " · " .. A.ClassName(r.class) .. " · " .. A.ZoneName(r) .. " · " .. A.Status(
                r.result or r.status
            ))
            or A.T("Start a run to begin")
    )
    put(UI.sectionTitle, model.title)
    put(UI.subtitle, model.subtitle)
    put(UI.sidebarNote, A.T("Collected since installation"))
    put(UI.explore, A.T("Explore"))
    put(UI.progression, A.T("Progression"))
    for i, b in ipairs(UI.nav) do
        put(b.label, A.T(A.tabs[i]))
        selected(b, i == A.view.tab)
    end
    local tab = A.view.tab
    UI.favoriteRun.favorite = (tab == 4 or tab == 5 or tab == 9)
            and not A.view.cumulative
            and A.RunFavorite(r)
        or nil
    show(UI.favoriteRun, UI.favoriteRun.favorite ~= nil)
    if UI.favoriteRun.favorite then
        paintFavorite(UI.favoriteRun)
    end
    show(UI.classButton, tab == 1 or tab == 2 or tab == 3 or tab == 6 or tab == 10 or tab == 11)
    put(UI.classButton.label, (A.view.class and A.ClassName(A.view.class) or A.T("All classes")))
    show(UI.latest, tab == 5)
    put(
        UI.latest.label,
        A.view.selected and (A.T("History") .. " · " .. A.Date(r and r.startedAt))
            or A.T("Latest run")
    )
    for _, b in ipairs(UI.modeButtons) do
        show(b, tab == 4)
        put(b.label, b.mode and A.ModeName(b.mode) or A.T("Activity"))
        local active = (b.mode and b.mode == A.view.mode and A.view.combatTab ~= "Activity")
            or (not b.mode and A.view.combatTab == "Activity")
        selected(b, active)
    end
    local counts = tab == 10 and A.FavoriteCounts() or {}
    for _, b in ipairs(UI.favoriteCategories) do
        show(b, tab == 10)
        put(b.label, A.T(b.categoryLabel) .. " (" .. A.Format(counts[b.category] or 0) .. ")")
        selected(b, b.category == (A.view.favoriteCategory or "run"))
    end
    for _, b in ipairs(UI.usageButtons) do
        show(b, tab == 9)
        put(b.label, A.T(b.key))
        selected(b, b.key == (A.view.usageTab or "Spells"))
    end
    for _, b in ipairs(UI.characterButtons) do
        show(b, tab == 5)
        put(b.label, A.T(b.key))
        selected(b, b.key == A.view.characterTab)
    end
    show(UI.scopeRun, tab == 4 or tab == 9)
    show(UI.scopeAll, tab == 4 or tab == 9)
    put(
        UI.scopeRun.label,
        A.view.selected and (A.T("History") .. " · " .. A.Date(r and r.startedAt))
            or A.T(A.run and A.run.status == "active" and "Current run" or "Latest run")
    )
    put(UI.scopeAll.label, A.T("All runs"))
    selected(UI.scopeRun, not A.view.cumulative)
    selected(UI.scopeAll, A.view.cumulative)
    local dashboard = model.layout == "dashboard"
    show(UI.statsLink, tab == 1)
    put(UI.statsLink.label, A.T(dashboard and "All statistics" or "Overview"))
    show(UI.recentTitle, dashboard)
    show(UI.recentEmpty, dashboard and table.getn(model.rows) == 0)
    put(UI.recentEmpty, A.T("No data yet"))
    show(UI.historyLink, dashboard)
    show(UI.recordsTitle, dashboard)
    show(UI.recordsLink, dashboard)
    show(UI.recordPanel, dashboard)
    put(UI.recentTitle, A.T("Recent runs"))
    put(UI.recordsTitle, A.T("Your records"))
    for index, record in ipairs(model.records or {}) do
        local widget = UI.recordItems[index]
        put(widget.label, record.label)
        put(widget.value, record.value)
        widget.item = { label = record.label, value = record.value, exact = record.exact }
    end
    show(UI.settings, tab == 8)
    if tab == 8 then
        settingsRefresh()
    end
    -- Two-line rows keep a real gap even at the largest accessibility font size.
    if model.layout ~= "overview" and model.layout ~= "classes" and model.layout ~= "settings" then
        local hasDetail = false
        for _, d in ipairs(model.rows) do
            if d.detail and d.detail ~= "" then
                hasDetail = true
                break
            end
        end
        if hasDetail then
            model.rowHeight = math.max(model.rowHeight, 46)
            model.capacity = math.max(1, math.floor((580 - model.rowY) / model.rowHeight))
        end
    end
    if A.view.focusFavorite then
        for i, d in ipairs(model.rows) do
            if
                d.favorite
                and A.FavoriteId(d.favorite.kind, d.favorite.key) == A.view.focusFavorite
            then
                A.view.page = math.ceil(i / model.capacity)
                break
            end
        end
        A.view.focusFavorite = nil
    end
    for _, d in ipairs(model.rows) do
        d.focused = d.favorite
            and A.FavoriteId(d.favorite.kind, d.favorite.key) == A.view.highlightFavorite
    end
    local per = model.capacity
    local pages = math.max(1, math.ceil(table.getn(model.rows) / per))
    A.view.page = math.max(1, math.min(pages, A.view.page))
    for i, c in ipairs(UI.cards) do
        local d = model.cards[i]
        if d then
            c.item = d
            c:ClearAllPoints()
            local tall = model.layout == "classes"
            local top = model.layout == "combat" and 195 or 163
            local h = tall and 116 or (model.layout == "combat" and 76 or 94)
            c:SetPoint(
                "TOPLEFT",
                A.window,
                "TOPLEFT",
                218 + math.mod(i - 1, 3) * 238,
                -top - math.floor((i - 1) / 3) * (h + 10)
            )
            local dashboard = model.layout == "dashboard"
            if dashboard then
                c:SetWidth(171)
                c:SetPoint("TOPLEFT", A.window, "TOPLEFT", 218 + (i - 1) * 180, -163)
                h = 106
            else
                c:SetWidth(224)
            end
            c:SetHeight(h)
            c.label.fontWidth = dashboard and 125 or 176
            c.label:SetWidth(c.label.fontWidth)
            c.value.fontWidth = dashboard and 144 or 199
            c.value:SetWidth(c.value.fontWidth)
            c.detail.fontWidth = dashboard and 144 or 199
            c.detail:SetWidth(c.detail.fontWidth)
            c.detail:ClearAllPoints()
            c.detail:SetPoint("TOPLEFT", c, "TOPLEFT", 13, model.layout == "combat" and -58 or -69)
            c.value:SetHeight(model.layout == "combat" and 27 or 34)
            if model.layout == "dashboard" then
                A.ThemeIcon(c.icon, ({ 1, 6, 3, 11 })[i])
            else
                icon(c.icon, d.icon, d.class)
            end
            put(c.label, d.label)
            put(c.value, d.value)
            put(c.detail, model.layout == "dashboard" and "" or d.detail)
            c:Show()
        else
            c:Hide()
            c.item = nil
        end
    end
    for i, frame in ipairs(UI.rows) do
        local d = i <= per and model.rows[(A.view.page - 1) * per + i] or nil
        if d then
            frame.favorite.favorite = d.favorite
            show(frame.favorite, d.favorite ~= nil)
            if d.favorite then
                paintFavorite(frame.favorite)
            end
            frame.item = d
            frame:ClearAllPoints()
            frame:SetPoint(
                "TOPLEFT",
                A.window,
                "TOPLEFT",
                218,
                -model.rowY - (i - 1) * model.rowHeight
            )
            frame:SetHeight(model.rowHeight - 1)
            local compact = model.layout == "overview"
            frame.detail:ClearAllPoints()
            frame.detail:SetPoint(
                "TOPLEFT",
                frame,
                "TOPLEFT",
                35,
                -(model.rowHeight >= 40 and 24 or 16)
            )
            frame.detail:SetHeight(model.rowHeight >= 40 and 20 or 12)
            frame.label:SetHeight(model.rowHeight >= 40 and 22 or 22)
            frame.icon:SetWidth(compact and 17 or 22)
            frame.icon:SetHeight(compact and 17 or 22)
            icon(frame.icon, d.icon, d.class)
            put(frame.label, d.label)
            put(frame.value, d.value)
            put(frame.detail, compact and "" or d.detail)
            frame.fill:SetWidth(
                math.max(1, 710 * math.max(0, math.min(1, d.fraction or (d.focused and 1) or 0)))
            )
            frame.fill:SetAlpha(d.fraction and 0.15 or (d.focused and 0.1) or 0)
            frame:Show()
        else
            frame.item = nil
            frame:Hide()
        end
    end
    show(UI.empty, model.empty)
    put(
        UI.empty,
        model.emptyText
            or (
                A.T("No data yet")
                .. (table.getn(A.db.runs) == 0 and ("\n" .. A.T("Start a run to begin")) or "")
            )
    )
    put(UI.note, model.note or "")
    put(UI.paging, A.T("Page") .. " " .. A.view.page .. " / " .. pages)
    show(UI.previous, pages > 1)
    show(UI.next, pages > 1)
    show(UI.paging, pages > 1)
    for _, b in ipairs(UI.controls) do
        if b.key and b.key ~= "" then
            put(b.label, A.T(b.key))
        end
    end
end

--- Show/hide the main addon window and remember that local preference.
function A.ToggleUI(value)
    if not A.window then
        return
    end
    if value == true or (value == nil and not A.window:IsShown()) then
        A.window:Show()
        A.RefreshUI()
    else
        A.window:Hide()
        if UI.menu then
            UI.menu:Hide()
        end
    end
    A.db.settings.open = A.window:IsShown() and true or false
end

--- Create own setting sliders, checks and menus with validated ranges and deferred scale updates.
local function buildSettings(frame)
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -158)
    p:SetWidth(712)
    p:SetHeight(421)
    UI.settings = p
    UI.appearance = font(p, 0, 0, 690, 24, 16, COLORS.gold, true)
    UI.behaviour = font(p, 0, 205, 320, 24, 16, COLORS.gold, true)
    UI.storage = font(p, 370, 205, 320, 24, 16, COLORS.gold, true)
    UI.saveNote = font(p, 0, 388, 710, 30, 11, COLORS.muted)
    UI.sliders = {}
    UI.checks = {}
    local definitions = {
        { "opacity", "Background opacity", 0, 55, 0.45, 1, 0.05 },
        { "scale", "Window scale", 370, 55, 0.65, 1.5, 0.05 },
        { "textSize", "Font size", 0, 135, 11, 16, 1 },
    }
    for _, def in ipairs(definitions) do
        local sl = CreateFrame("Slider", "AzerothStatsSlider" .. def[1], p, "OptionsSliderTemplate")
        sl.setting = def[1]
        sl.key = def[2]
        sl:SetPoint("TOPLEFT", p, "TOPLEFT", def[3] + 8, -def[4] - 25)
        sl:SetWidth(310)
        sl:SetHeight(18)
        sl:SetMinMaxValues(def[5], def[6])
        sl:SetValueStep(def[7])
        for _, suffix in ipairs({ "Text", "Low", "High" }) do
            local t = getglobal(sl:GetName() .. suffix)
            if t then
                t:Hide()
            end
        end
        sl.caption = font(p, def[3], def[4] - 10, 245, 22, 12, COLORS.text)
        sl.number = font(p, def[3] + 250, def[4] - 10, 90, 22, 12, COLORS.gold)
        sl.number:SetJustifyH("RIGHT")
        sl:SetScript("OnMouseDown", function()
            this.dragging = true
        end)
        sl:SetScript("OnMouseUp", function()
            A.CommitSliders()
        end)
        sl:SetScript("OnHide", function()
            A.CommitSliders()
        end)
        sl:SetScript("OnUpdate", function()
            -- Native click/value script ordering may differ; never resize synchronously from OnValueChanged.
            if this.pending and not this.dragging and GetTime() - (this.pendingAt or 0) > 0.25 then
                A.CommitSliders()
            end
        end)
        sl:SetScript("OnValueChanged", function()
            if this.syncing then
                return
            end
            local value = this:GetValue()
            if this.setting == "scale" or this.setting == "textSize" then
                this.pending = value
                this.pendingAt = GetTime()
                settingsRefresh()
            else
                A.db.settings[this.setting] = value
                A.ApplyUI()
                A.RefreshUI()
            end
        end)
        table.insert(UI.sliders, sl)
    end
    UI.scaleHint = font(p, 370, 104, 330, 18, 9, COLORS.muted)
    UI.textHint = font(p, 0, 183, 330, 18, 9, COLORS.muted)
    UI.languageCaption = font(p, 370, 125, 332, 24, 12, COLORS.text)
    UI.language = button(p, 370, 153, 330, 28, "", function(self)
        local options = {}
        for _, lg in ipairs(A.languages) do
            local code = lg[1]
            table.insert(options, {
                label = code == "auto" and A.T("Automatic") or lg[2],
                locale = code == "auto" and A.Locale() or code,
                action = function()
                    A.SetLanguage(code)
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    for i, def in ipairs({
        { "bar", "Top bar" },
        { "minimap", "Minimap button" },
        { "locked", "Lock position" },
        { "recordSound", "Record sounds" },
    }) do
        local b = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -237 - (i - 1) * 39)
        b:SetWidth(24)
        b:SetHeight(24)
        b.setting = def[1]
        b.key = def[2]
        b.caption = font(p, 32, 237 + (i - 1) * 39, 310, 24, 12, COLORS.text)
        b:SetScript("OnClick", function()
            A.db.settings[this.setting] = not A.db.settings[this.setting]
            A.ApplyUI()
            A.RefreshUI()
        end)
        table.insert(UI.checks, b)
    end
    UI.retentionCaption = font(p, 370, 235, 330, 22, 12, COLORS.text)
    UI.retention = button(p, 370, 263, 330, 28, "", function(self)
        local options = {}
        for _, n in ipairs({ 50, 100, 200, 500, 1000 }) do
            local value = n
            table.insert(options, {
                label = A.Format(value),
                action = function()
                    A.db.settings.maxRuns = value
                    A.Trim()
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    dropdown(UI.language)
    dropdown(UI.retention)
    button(p, 370, 355, 330, 28, "Customize bar", function()
        A.OpenBarEditor()
    end)
    button(p, 370, 317, 330, 28, "Reset position", function()
        A.ResetPosition()
    end)
end

--- Create all addon-owned frames once, then initialize local positioning and presentation.
function A.BuildUI()
    local frame = CreateFrame("Frame", "AzerothStatsWindow", UIParent)
    A.window = frame
    frame:SetWidth(960)
    frame:SetHeight(650)
    frame:SetFrameStrata("DIALOG")
    surface(frame, "main")
    drag(frame, "windowPos")
    place(frame, "windowPos", "CENTER", 0, 0)
    frame:SetScript("OnHide", function()
        A.CommitSliders()
        A.db.settings.open = false
        if UI.menu then
            UI.menu:Hide()
        end
    end)
    frame:SetScript("OnMouseDown", function()
        if UI.menu then
            UI.menu:Hide()
        end
    end)
    local emblem = frame:CreateTexture(nil, "ARTWORK")
    emblem:SetPoint("TOPLEFT", frame, "TOPLEFT", 21, -15)
    emblem:SetWidth(48)
    emblem:SetHeight(48)
    emblem:SetTexture(A.theme.seal)
    UI.title = font(frame, 72, 19, 370, 28, 23, COLORS.gold, true)
    UI.version = font(frame, 448, 23, 200, 20, 11, COLORS.muted)
    UI.breadcrumb = font(frame, 72, 49, 810, 18, 11, COLORS.muted)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -6)
    close:SetWidth(30)
    close:SetHeight(30)
    close:SetScript("OnClick", function()
        A.ToggleUI(false)
    end)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -79)
    divider:SetWidth(914)
    divider:SetHeight(1)
    divider:SetTexture(0.42, 0.32, 0.16)
    UI.sidebarNote = font(frame, 29, 625, 152, 16, 10, COLORS.muted)
    UI.explore = font(frame, 29, 91, 160, 18, 10, COLORS.muted)
    UI.progression = font(frame, 29, 296, 160, 18, 10, COLORS.muted)
    local navY = { 115, 320, 155, 195, 235, 360, 588, 545, 440, 493, 400 }
    for i, key in ipairs(A.tabs) do
        local index = i
        local b = button(frame, 23, navY[i], 170, i == 7 and 27 or 36, "", function()
            selectTab(index)
        end)
        b.marker = solid(b, 1, 0.68, 0.2, 1, "ARTWORK")
        b.marker:ClearAllPoints()
        b.marker:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -3)
        b.marker:SetWidth(3)
        b.marker:SetHeight(30)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 39, 0)
        b.label:SetWidth(123)
        b.label.fontWidth = 123
        b.label.baseSize = 13
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.icon:SetWidth(21)
        b.icon:SetHeight(21)
        A.ThemeIcon(b.icon, i == 7 and 12 or i)
        b.navigation = true
        UI.nav[i] = b
    end
    UI.sectionTitle = font(frame, 218, 96, 285, 28, 21, COLORS.gold, true)
    UI.subtitle = font(frame, 218, 128, 710, 22, 11, COLORS.muted)
    UI.classButton = button(frame, 714, 100, 218, 26, "", function()
        A.CycleClass()
    end)
    dropdown(UI.classButton)
    UI.favoriteRun = favoriteButton(frame, 904, 43)
    UI.latest = button(frame, 714, 100, 218, 26, "", function(self)
        A.RunMenu(self)
    end)
    dropdown(UI.latest)
    UI.modeButtons = {}
    UI.characterButtons = {}
    for i, mode in ipairs({ "damage", "healing", "taken", "boss", "activity" }) do
        local key = mode
        local b = button(frame, 218 + (i - 1) * 144, 160, 136, 26, "", function()
            A.view.combatTab = key == "activity" and "Activity" or "Spells"
            if key == "activity" then
                A.view.cumulative = false
            end
            if key ~= "activity" then
                A.view.mode = key
            end
            A.view.page = 1
            A.RefreshUI()
        end)
        b.mode = mode ~= "activity" and mode or nil
        table.insert(UI.modeButtons, b)
    end
    for i, key in ipairs({ "Spells", "Equipment", "Attributes", "Timeline" }) do
        local section = key
        local b = button(frame, 218 + (i - 1) * 180, 160, 172, 26, "", function()
            A.view.characterTab = section
            A.view.page = 1
            A.RefreshUI()
        end)
        b.key = key
        table.insert(UI.characterButtons, b)
    end
    UI.favoriteCategories = {}
    for i, c in ipairs(A.favoriteCategories) do
        local key = c[1]
        local b = button(frame, 218 + (i - 1) * 120, 160, 112, 26, "", function()
            A.view.favoriteCategory = key
            A.view.page = 1
            A.RefreshUI()
        end)
        b.category = key
        b.categoryLabel = c[2]
        table.insert(UI.favoriteCategories, b)
    end
    UI.usageButtons = {}
    for i, key in ipairs({ "Spells", "Jewelry", "Co-op" }) do
        local section = key
        local b = button(frame, 218 + (i - 1) * 240, 160, 232, 26, "", function()
            A.view.usageTab = section
            A.view.coopPartner = nil
            if section == "Co-op" then
                A.view.cumulative = false
            end
            A.view.page = 1
            A.RefreshUI()
        end)
        b.key = key
        table.insert(UI.usageButtons, b)
    end
    UI.scopeRun = button(frame, 518, 100, 198, 26, "", function(self)
        A.RunMenu(self)
    end)
    dropdown(UI.scopeRun)
    UI.scopeAll = button(frame, 724, 100, 208, 26, "", function()
        A.view.cumulative = true
        A.view.coopPartner = nil
        A.view.combatTab = "Spells"
        A.view.page = 1
        A.RefreshUI()
    end)
    for i = 1, 9 do
        local c = CreateFrame("Button", nil, frame)
        c:SetWidth(224)
        surface(c, "card")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -12)
        c.icon:SetWidth(22)
        c.icon:SetHeight(22)
        c.label = font(c, 13, 9, 176, 20, 11, COLORS.text)
        c.value = font(c, 13, 32, 199, 34, 23, COLORS.gold, true)
        c.detail = font(c, 13, 69, 199, 18, 9, COLORS.muted)
        c:SetScript("OnEnter", function()
            tooltip(this)
        end)
        c:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        c:SetScript("OnClick", function()
            if this.item and this.item.action then
                this.item.action()
                A.RefreshUI()
            end
        end)
        UI.cards[i] = c
    end
    for i = 1, 12 do
        local r = CreateFrame("Button", nil, frame)
        r:SetWidth(714)
        r.shade = solid(r, 0.22, 0.29, 0.32, math.mod(i, 2) == 0 and 0.28 or 0.11)
        r.fill = r:CreateTexture(nil, "ARTWORK")
        r.fill:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.fill:SetHeight(27)
        r.fill:SetTexture(0.65, 0.42, 0.13)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.icon:SetWidth(22)
        r.icon:SetHeight(22)
        r.label = font(r, 35, 1, 412, 22, 12, COLORS.text)
        r.value = font(r, 455, 0, 225, 23, 13, COLORS.gold)
        r.value:SetJustifyH("RIGHT")
        r.favorite = favoriteButton(r, 687, 1)
        r.detail = font(r, 35, 19, 670, 15, 9, COLORS.muted)
        r:SetScript("OnEnter", function()
            tooltip(this)
        end)
        r:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        r:SetScript("OnClick", function()
            if this.item and this.item.action then
                this.item.action()
                A.RefreshUI()
            end
        end)
        UI.rows[i] = r
    end
    UI.statsLink = button(frame, 518, 100, 186, 26, "", function()
        A.view.overviewStats = not A.view.overviewStats
        A.view.page = 1
        A.RefreshUI()
    end)
    UI.recentTitle = font(frame, 218, 284, 430, 27, 18, COLORS.gold, true)
    UI.recentEmpty = font(frame, 240, 370, 650, 55, 14, COLORS.muted)
    UI.historyLink = button(frame, 714, 284, 218, 27, "History", function()
        selectTab(3)
    end)
    UI.recordsTitle = font(frame, 218, 509, 430, 26, 18, COLORS.gold, true)
    UI.recordsLink = button(frame, 714, 509, 218, 26, "Records", function()
        selectTab(6)
    end)
    UI.recordPanel = CreateFrame("Frame", nil, frame)
    UI.recordPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -541)
    UI.recordPanel:SetWidth(714)
    UI.recordPanel:SetHeight(44)
    surface(UI.recordPanel, "card")
    UI.recordItems = {}
    for index = 1, 3 do
        local record = CreateFrame("Button", nil, UI.recordPanel)
        record:SetPoint("TOPLEFT", UI.recordPanel, "TOPLEFT", 10 + (index - 1) * 238, 0)
        record:SetWidth(218)
        record:SetHeight(44)
        record.label = font(record, 0, 1, 208, 16, 11, COLORS.muted)
        record.value = font(record, 0, 17, 208, 25, 17, COLORS.text)
        record:SetScript("OnEnter", function()
            tooltip(this)
        end)
        record:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        record:SetScript("OnClick", function()
            selectTab(6)
        end)
        UI.recordItems[index] = record
    end
    UI.empty = font(frame, 268, 293, 608, 80, 16, COLORS.muted, true)
    UI.note = font(frame, 218, 589, 714, 19, 10, COLORS.muted)
    UI.previous = button(frame, 218, 615, 38, 24, "<", function()
        A.view.page = math.max(1, A.view.page - 1)
        A.RefreshUI()
    end)
    UI.next = button(frame, 265, 615, 38, 24, ">", function()
        local model = A.PageModel()
        A.view.page = math.min(math.ceil(table.getn(model.rows) / model.capacity), A.view.page + 1)
        A.RefreshUI()
    end)
    UI.paging = font(frame, 320, 616, 400, 23, 11, COLORS.muted)
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function()
            A.view.page = A.view.page - (arg1 or 0)
            A.RefreshUI()
        end)
    end
    buildSettings(frame)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "AzerothStatsWindow")
    end
    A.tabButtons = UI.nav
    A.uiRows = UI.rows
    A.classButton = UI.classButton
    A.BuildBar()
    local mini = CreateFrame("Button", "AzerothStatsMinimap", Minimap or UIParent)
    A.mini = mini
    mini:SetWidth(30)
    mini:SetHeight(30)
    mini:SetFrameStrata("MEDIUM")
    surface(mini, "main")
    mini.icon = mini:CreateTexture(nil, "ARTWORK")
    mini.icon:SetPoint("CENTER", mini, "CENTER", 0, 0)
    mini.icon:SetWidth(21)
    mini.icon:SetHeight(21)
    mini.icon:SetTexture(A.theme.seal)
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:RegisterForDrag("LeftButton")
    mini:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            selectTab(8)
            A.ToggleUI(true)
        else
            A.ToggleUI()
        end
    end)
    mini:SetScript("OnDragStart", function()
        if not A.db.settings.locked then
            this.dragging = true
        end
    end)
    mini:SetScript("OnDragStop", function()
        this.dragging = nil
    end)
    mini:SetScript("OnUpdate", function()
        if not this.dragging or not GetCursorPosition then
            return
        end
        local x, y = GetCursorPosition()
        local cx, cy = (Minimap or UIParent):GetCenter()
        local scale = (Minimap or UIParent):GetEffectiveScale()
        local angle = math.atan2(y / scale - cy, x / scale - cx)
        A.db.settings.miniAngle = angle
        this:ClearAllPoints()
        this:SetPoint(
            "CENTER",
            Minimap or UIParent,
            "CENTER",
            math.cos(angle) * 80,
            math.sin(angle) * 80
        )
    end)
    local angle = tonumber(A.db.settings.miniAngle) or 0.785398
    if angle ~= angle or math.abs(angle) > 100 then
        angle = 0.785398
    end
    mini:SetPoint(
        "CENTER",
        Minimap or UIParent,
        "CENTER",
        math.cos(angle) * 80,
        math.sin(angle) * 80
    )
    mini:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Azeroth Stats", 0.95, 0.8, 0.5)
        GameTooltip:AddLine(A.T("Open") .. " / " .. A.T("Settings"), 0.85, 0.82, 0.75)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if not A.db.settings.open then
        frame:Hide()
    end
    A.ApplyUI()
    A.RefreshUI()
end

-- Shared trusted widget constructors for the separately owned HUD editor.
A.widgets = {
    font = font,
    put = put,
    solid = solid,
    surface = surface,
    icon = icon,
    button = button,
    dropdown = dropdown,
    drag = drag,
    place = place,
}

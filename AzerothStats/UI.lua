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
        * (
            (t.fixedSize or (t.titleFont and not t.accessible)) and 1
            or ((A.db and A.db.settings.textSize or 12) / 12)
        )
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
        local floor = (t.fixedSize or (t.titleFont and not t.accessible)) and 11
            or math.min(size, A.db and A.db.settings.textSize or 12)
        while size > floor and t:GetStringWidth() > t.fontWidth do
            size = math.max(floor, size - 0.5)
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
    A.ThemeFrame(frame, kind)
    if frame.materialCenter then
        table.insert(UI.solids, { texture = frame.materialCenter })
    end
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
    A.MaterialState(b, active)
    if b.materialCenter then
        b.materialCenter:SetAlpha((b.navigation and not active) and 0 or A.db.settings.opacity)
    end
    A.PaintBorder(b, 0.85, 0.71, 0.42, (b.navigation and not active) and 0 or (active and 1 or 0.5))
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
        A.PaintBorder(this, 0.95, 0.8, 0.5, 1)
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
    if i == 3 then
        A.view.historySection = "History"
    end
    if i == 9 then
        A.view.cumulative = true
    end
    if UI.menu then
        UI.menu:Hide()
    end
    A.RefreshUI()
end

--- Attach legacy mouse handlers that save only an addon frame position when unlocked.
local function drag(frame, key, handle)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    handle = handle or frame
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
    handle:SetScript("OnDragStart", function()
        if not A.db.settings.locked then
            frame:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local p, _, rel, x, y = frame:GetPoint()
        A.db.settings[key] = A.FramePosition({ p, rel, x, y })
    end)
end

--- Change an owned top-level frame's scale while preserving its physical anchor.
local function rescale(frame, value, key)
    local old = frame:GetScale()
    if old == value then
        return
    end
    local p, parent, rel, x, y = frame:GetPoint()
    frame:SetScale(value)
    if p and x and y then
        frame:ClearAllPoints()
        frame:SetPoint(p, parent, rel, x * old / value, y * old / value)
        if A.db.settings[key] then
            A.db.settings[key] = A.FramePosition({ p, rel, x * old / value, y * old / value })
        end
    end
end

--- Restore a normalized own frame anchor or use the supplied default position.
local function place(frame, key, p, x, y, screenBounds)
    local settings = A.db.settings[key]
    -- Independent panels can legitimately exceed the legacy main-window limits.
    -- Native clamping still keeps their final rectangle on screen.
    local limitX, limitY = 600, 450
    if screenBounds then
        local scale = math.max(0.45, frame:GetScale())
        limitX, limitY = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
    end
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
            math.max(-limitX, math.min(limitX, settings[3])),
            math.max(-limitY, math.min(limitY, settings[4]))
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
        UI.menu:SetFrameStrata("FULLSCREEN_DIALOG")
        UI.menu:SetFrameLevel(A.window:GetFrameLevel() + 30)
        UI.menu.items = {}
    end
    local menu = UI.menu
    -- Menus belong to the window that owns their anchor. A main-window-owned
    -- menu can promote that root over an independent editor when clicked.
    local owner, node = A.window, anchor
    for depth = 1, 32 do
        if not node then
            break
        end
        if node == A.barEditor or node == UI.dataDialog then
            owner = node
            break
        end
        node = node:GetParent()
    end
    menu:SetParent(owner)
    menu.owner = owner
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(owner:GetFrameLevel() + 30)
    if owner == A.barEditor and A.FocusBarEditor then
        A.FocusBarEditor()
    end
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
    A.UpdateThemeFrame(menu)
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
        b.item = { label = entry.label, detail = entry.detail or "", value = entry.value }
        b:SetScript("OnEnter", function()
            A.PaintBorder(this, 0.95, 0.8, 0.5, 1)
            tooltip(this)
        end)
        b:SetScript("OnLeave", function()
            selected(this, this.selected)
            GameTooltip:Hide()
        end)
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
    local newest = A.run or A.db.runs[table.getn(A.db.runs)]
    if newest then
        options[1].label = options[1].label .. " · " .. A.RunLabel(newest)
        options[1].detail = A.RunContext(newest)
    end
    for i = table.getn(A.db.runs), 1, -1 do
        local run = A.db.runs[i]
        local id = run.id
        if run ~= newest then
            table.insert(options, {
                label = A.RunContext(run) .. " · " .. A.RunLabel(run),
                detail = A.RunContext(run),
                value = id,
                action = function()
                    A.view.selected, A.view.cumulative, A.view.page = id, false, 1
                end,
            })
        end
    end
    A.ShowMenu(anchor, options)
end

--- Owned selectors retain exact IDs; they do not change accounting or choose a gameplay action.
function A.ComparisonRunMenu(anchor, side)
    local choices = {}
    for i = table.getn(A.db.runs), 1, -1 do
        local run = A.db.runs[i]
        local id = run.id
        table.insert(choices, {
            label = A.RunContext(run) .. " · " .. A.RunLabel(run),
            detail = A.RunContext(run),
            value = run.id,
            action = function()
                A.view[side == "A" and "compareA" or "compareB"] = id
                A.view.page = 1
            end,
        })
    end
    if table.getn(choices) == 0 then
        table.insert(choices, { label = A.T("No data yet"), action = function() end })
    end
    A.ShowMenu(anchor, choices)
end

--- One short-lived actionable notice per accepted run summary; no auto-opening over gameplay.
function A.RefreshReportNotice()
    local pending = A.pendingReport
    local visible = pending and GetTime() <= pending.expires and A.FindRun(pending.id)
    if UI.reportToast then
        if visible then
            UI.reportToast:Show()
        else
            UI.reportToast:Hide()
        end
        put(UI.reportToast.label, A.T("Run report ready"))
    end
    if pending and not visible then
        A.pendingReport = nil
    end
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
        math.max(0.45, (UIParent:GetHeight() - 40) / 780)
    )
    UI.effectiveScale = fit
    rescale(A.window, fit, "windowPos")
    if A.barEditor then
        rescale(A.barEditor, fit, "barEditorPos")
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
    A.db.settings.barEditorPos = nil
    A.db.settings.miniAngle = 0.785398
    place(A.window, "windowPos", "CENTER", 0, 0)
    place(A.bar, "barPos", "TOP", 0, -38)
    if A.barEditor then
        place(A.barEditor, "barEditorPos", "CENTER", 0, 0, true)
    end
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
    put(UI.hudSettingsTitle, A.T("Top bar"))
    put(UI.hudSettingsHint, A.T("Bar scope hint"))
    put(UI.behaviour, A.T("Behaviour"))
    put(UI.storage, A.T("Storage"))
    put(UI.saveNote, A.T("Saved on normal game exit"))
end

--- Paint the active model and local top bar; skip expensive page building while the window is hidden.
--- Render a reusable row with separate text/value/action areas and an optional
--- thin contribution track. It never changes the row's underlying data or tooltip.
local function paintRow(frame, d, model)
    show(frame.leftCell, model.comparison)
    show(frame.rightCell, model.comparison)
    show(frame.leftValue, model.comparison)
    show(frame.rightValue, model.comparison)
    if model.comparison then
        show(frame.icon, false)
        show(frame.thumbnail, false)
        show(frame.rank, false)
        show(frame.share, false)
        show(frame.extra, false)
        frame.fill:SetAlpha(0)
        frame.label:ClearAllPoints()
        frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -6)
        frame.label.fontWidth = 154
        frame.label:SetWidth(154)
        frame.label.baseSize = 12
        frame.label.titleFont = false
        frame.detail:ClearAllPoints()
        frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -29)
        frame.detail.fontWidth = 154
        frame.detail:SetWidth(154)
        frame.detail:SetHeight(18)
        frame.value:ClearAllPoints()
        frame.value:SetPoint("TOPLEFT", frame, "TOPLEFT", 550, -7)
        frame.value.fontWidth = 158
        frame.value:SetWidth(158)
        frame.value.baseSize = 12
        frame.value:SetTextColor(unpack(COLORS.text))
        frame.label.accessible = true
        put(frame.label, d.label)
        put(frame.detail, d.detail)
        put(frame.value, d.value)
        frame.leftValue:SetJustifyH(d.leftItem and "LEFT" or "RIGHT")
        frame.rightValue:SetJustifyH(d.rightItem and "LEFT" or "RIGHT")
        put(frame.leftValue, d.left)
        put(frame.rightValue, d.right)
        frame.leftCell.item = d.leftItem
            or { label = "A · " .. d.label, value = d.left, exact = d.exact }
        frame.rightCell.item = d.rightItem
            or { label = "B · " .. d.label, value = d.right, exact = d.exact }
        return
    end
    local photo = model.layout == "dashboard" or model.photoRows
    local hero = model.layout == "dashboard"
    local ranking = model.ranking
    local compact = model.layout == "overview"
    local left = hero and 198 or (photo and 160 or (ranking and 72 or 56))
    local width = hero and 256 or (photo and 350 or (ranking and 340 or 390))
    frame.label:ClearAllPoints()
    frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -7)
    frame.label:SetWidth(width)
    frame.label.fontWidth = width
    frame.label:SetHeight(23)
    frame.label.baseSize = photo and 14 or 13
    frame.label.titleFont = photo
    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -31)
    frame.detail:SetWidth(hero and 256 or (photo and 510 or 615))
    frame.detail.fontWidth = hero and 256 or (photo and 510 or 615)
    frame.detail:SetHeight(20)
    frame.detail.baseSize = 11
    frame.extra:ClearAllPoints()
    frame.extra:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -51)
    frame.extra:SetWidth(510)
    frame.extra.fontWidth = 510
    put(frame.extra, d.extra or "")
    show(frame.extra, model.photoRows and d.extra ~= nil)
    frame.value:ClearAllPoints()
    frame.value:SetPoint("TOPLEFT", frame, "TOPLEFT", photo and 520 or (ranking and 520 or 480), -8)
    frame.value.fontWidth = (photo or ranking) and 152 or 192
    frame.value:SetWidth(frame.value.fontWidth)
    frame.value:SetHeight(23)
    frame.value.baseSize = compact and 16 or 14
    frame.value:SetTextColor(
        unpack(
            photo
                    and (d.result == "victory" and COLORS.green or (d.result == "defeat" and COLORS.red or COLORS.gold))
                or COLORS.gold
        )
    )
    frame.favorite:ClearAllPoints()
    frame.favorite:SetPoint("TOPLEFT", frame, "TOPLEFT", 687, -7)
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("LEFT", frame, "LEFT", ranking and 32 or 12, 0)
    frame.icon:SetWidth(compact and 24 or 30)
    frame.icon:SetHeight(compact and 24 or 30)
    if d.icon or d.class then
        icon(frame.icon, d.icon, d.class)
    else
        A.ThemeIcon(frame.icon, A.view.tab)
    end
    show(frame.icon, not photo)
    show(frame.thumbnail, photo)
    if photo then
        frame.thumbnail:ClearAllPoints()
        frame.thumbnail:SetPoint("LEFT", frame, "LEFT", 5, 0)
        frame.thumbnail:SetWidth(hero and 178 or 138)
        frame.thumbnail:SetHeight((hero and 178 or 138) * 66 / 178)
        A.ZoneIllustration(frame.thumbnail, d.zone)
    end
    show(frame.rank, ranking)
    show(frame.share, ranking)
    put(frame.rank, d.rank or "")
    put(frame.share, d.share or "")
    frame.label.accessible = true
    put(frame.label, d.label)
    put(frame.detail, compact and "" or d.detail)
    put(frame.value, photo and (A.Status(d.result) .. " · " .. d.value) or d.value)
    frame.fill:ClearAllPoints()
    frame.fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 3)
    frame.fill:SetHeight(3)
    frame.fill:SetWidth(
        math.max(1, 698 * math.max(0, math.min(1, d.fraction or (d.focused and 1) or 0)))
    )
    frame.fill:SetAlpha(d.fraction and 0.7 or (d.focused and 0.35) or 0)
    if compact then
        frame.label:ClearAllPoints()
        frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -6)
    end
end

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
        difficulty = A.view.difficulty,
        historySection = A.view.historySection,
        reportSection = A.view.reportSection,
        compareSection = A.view.compareSection,
        compareA = A.view.compareA,
        compareB = A.view.compareB,
        reportRun = A.view.historySection == "Run report" and A.view.selected or nil,
    }
    local live = A.run
    local r
    if A.view.tab == 3 and A.view.historySection == "Run report" and A.view.selected then
        r = A.FindRun(A.view.selected)
    else
        r = A.Selected()
    end
    A.RefreshBar()
    A.RefreshReportNotice()
    if not A.window:IsShown() then
        return
    end
    local model = A.PageModel()
    UI.model = model
    put(UI.title, "AZEROTH STATS")
    put(UI.version, A.version)
    local _, heroClass = A.Identity()
    put(UI.profileName, A.Text(A.Call(UnitName, "player"), 80) or "?")
    put(UI.profileClass, A.ClassName(heroClass))
    put(UI.breadcrumb, A.ViewScope(model, r))
    if UI.dataDialog and UI.dataDialog:IsShown() then
        A.RefreshDataDialog()
    end
    if UI.retentionDialog and UI.retentionDialog:IsShown() and A.pendingRetention then
        A.ShowRetentionConfirmation()
    end
    put(UI.sectionTitle, model.title)
    put(UI.subtitle, model.subtitle)
    put(UI.sidebarNote, A.T("Collected since installation"))
    put(UI.explore, A.T("Explore"))
    put(UI.progression, A.T("Progression"))
    for i, b in ipairs(UI.nav) do
        put(b.label, A.T(i == 9 and "Trends" or A.tabs[i]))
        selected(b, i == A.view.tab)
    end
    local tab = A.view.tab
    local selectedLive = r and live and r.id == live.id and live.status == "active"
    local selectorLabel = selectedLive and A.T("Current run")
        or (
            A.view.selected and (A.T("History") .. " · " .. A.Date(r and r.startedAt))
            or A.T("Latest run")
        )
    UI.favoriteRun.favorite = (tab == 4 or tab == 5 or tab == 9 or model.report)
            and not A.view.cumulative
            and A.RunFavorite(r)
        or nil
    show(UI.favoriteRun, UI.favoriteRun.favorite ~= nil)
    if UI.favoriteRun.favorite then
        paintFavorite(UI.favoriteRun)
    end
    show(
        UI.classButton,
        tab == 1
            or tab == 2
            or (tab == 3 and not model.report and not model.comparison)
            or tab == 6
            or tab == 10
            or tab == 11
    )
    put(UI.classButton.label, (A.view.class and A.ClassName(A.view.class) or A.T("All classes")))
    show(UI.difficultyButton, tab == 3 and not model.report and not model.comparison)
    put(
        UI.difficultyButton.label,
        A.view.difficulty == nil and A.T("All difficulties")
            or A.HeroicLabel({
                heroic = A.view.difficulty ~= "unknown" and A.view.difficulty or nil,
            })
    )
    local browsingHistory = tab == 3 and not model.report and not model.comparison
    for _, widget in ipairs(UI.historyFilters or {}) do
        show(widget, browsingHistory)
    end
    if UI.historySearch and UI.historySearch:GetText() ~= (A.view.historySearch or "") then
        UI.historySearch.syncing = true
        UI.historySearch:SetText(A.view.historySearch or "")
        UI.historySearch.syncing = nil
    end
    UI.historySearch:SetFont(A.Font(false), settings.textSize, "")
    put(UI.historySearchCaption, A.T("Search runs"))
    put(
        UI.historyResult.label,
        A.view.historyResult and A.Status(A.view.historyResult) or A.T("All results")
    )
    put(
        UI.historyKind.label,
        A.T(
            A.view.historyKind == "coop" and "Co-op"
                or A.view.historyKind == "favorite" and "Favorites"
                or "All runs"
        )
    )
    put(UI.historyReset.label, A.T("Reset filters"))
    local journal = model.report and A.view.reportSection == "Build journal"
    show(UI.journalFilter, journal)
    put(
        UI.journalFilter.label,
        A.T(
            ({ ranks = "Rank changes", stats = "Stat changes", gear = "Equipment changes" })[A.view.journalKind]
                or "All changes"
        )
    )
    local detailed = model.report
        and (A.view.reportSection == "Combat" or A.view.reportSection == "Character")
    show(UI.reportDetails, detailed)
    put(UI.reportDetails.label, A.T("Click to inspect"))
    show(UI.latest, tab == 5 or model.report)
    put(UI.latest.label, selectorLabel)
    for _, b in ipairs(UI.modeButtons) do
        show(b, tab == 4)
        put(b.label, b.mode and A.ModeName(b.mode) or A.T("Activity"))
        local active = (b.mode and b.mode == A.view.mode and A.view.combatTab ~= "Activity")
            or (not b.mode and A.view.combatTab == "Activity")
        selected(b, active)
    end
    for _, b in ipairs(UI.historySections) do
        show(b, tab == 3)
        selected(b, b.key == (A.view.historySection or "History"))
    end
    for _, b in ipairs(UI.reportSections) do
        show(b, model.report)
        selected(b, b.key == (A.view.reportSection or "Overview"))
    end
    for _, b in ipairs(UI.compareSections) do
        show(b, model.comparison)
        selected(b, b.key == (A.view.compareSection or "Overview"))
    end
    show(UI.reportCompare, model.report)
    show(UI.swapRuns, model.comparison)
    for i = 1, 2 do
        local band = UI.compareHeaders[i]
        local data = model.compareRuns and model.compareRuns[i]
        show(band, model.comparison)
        show(UI.compareSelectors[i], model.comparison)
        show(UI.compareColumns[i], model.comparison)
        if model.comparison then
            put(
                UI.compareSelectors[i].label,
                (i == 1 and "A" or "B")
                    .. " · "
                    .. (data and A.Date(data.startedAt) or A.T("Select another run"))
            )
            put(band.label, data and A.ZoneName(data) or A.T("Select another run"))
            put(
                band.detail,
                data
                        and (A.ClassName(data.class) .. " · " .. A.HeroicLabel(data) .. "\n" .. A.Status(
                            data.status == "active" and "active" or data.result or data.status
                        ) .. " · " .. A.Duration(data.values.duration))
                    or ""
            )
            A.ZoneIllustration(band.icon, data and data.zone)
            band.item = {
                label = data and (data.hero or "?") or A.T("Unavailable"),
                value = data and data.id or "",
                detail = band.detail.fullText,
            }
            band.favorite.favorite = A.RunFavorite(data)
            show(band.favorite, data ~= nil)
            if data then
                paintFavorite(band.favorite)
            end
        end
    end
    UI.columnValue.columnX = model.comparison and 768 or 738
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
        tab == 9 and A.view.usageTab == "Co-op" and A.T("Run report") or selectorLabel
    )
    put(UI.scopeAll.label, A.T("All runs"))
    selected(UI.scopeRun, not A.view.cumulative)
    selected(UI.scopeAll, A.view.cumulative)
    local dashboard = model.layout == "dashboard"
    show(UI.context, model.banner ~= nil)
    show(UI.subtitle, model.banner == nil)
    if model.banner then
        local band, data = UI.context, model.banner
        band.item = data
        band.icon:SetWidth(data.photo and 110 or 32)
        band.icon:SetHeight(data.photo and (110 * 66 / 178) or 32)
        if data.photo then
            A.ZoneIllustration(band.icon, data.zone)
        else
            A.ThemeIcon(band.icon, tab)
        end
        local left = data.photo and 136 or 56
        band.label:ClearAllPoints()
        band.label:SetPoint("TOPLEFT", band, "TOPLEFT", left, -6)
        band.detail:ClearAllPoints()
        band.detail:SetPoint("TOPLEFT", band, "TOPLEFT", left, -33)
        band.label.fontWidth = 500 - left
        band.label:SetWidth(band.label.fontWidth)
        band.detail.fontWidth = 690 - left
        band.detail:SetWidth(band.detail.fontWidth)
        put(band.label, data.label)
        put(band.detail, data.detail)
        put(band.value, data.value)
    end
    show(UI.columnLabel, model.columnLabel ~= nil)
    show(UI.columnValue, model.columnLabel ~= nil)
    show(UI.columnShare, model.ranking)
    for _, label in ipairs({ UI.columnLabel, UI.columnValue, UI.columnShare }) do
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", A.window, "TOPLEFT", label.columnX, -model.rowY + 28)
    end
    put(UI.columnLabel, model.columnLabel or "")
    put(UI.columnValue, model.columnValue or "")
    put(UI.columnShare, A.T("Share"))
    show(UI.note, not dashboard)
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
    -- Shared body geometry extends to the footer; translated two-line rows keep
    -- dedicated space instead of the old fixed 580-unit content cutoff.
    if
        model.layout ~= "overview"
        and model.layout ~= "dashboard"
        and model.layout ~= "classes"
        and model.layout ~= "settings"
    then
        model.capacity = math.max(1, math.min(12, math.floor((700 - model.rowY) / model.rowHeight)))
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
            local top = model.cardsTop or (model.layout == "combat" and 195 or 181)
            local h = tall and 156 or 104
            c:SetPoint(
                "TOPLEFT",
                A.window,
                "TOPLEFT",
                218 + math.mod(i - 1, 3) * 238,
                -top - math.floor((i - 1) / 3) * (h + 12)
            )
            local dashboard = model.layout == "dashboard"
            if dashboard then
                c:SetWidth(178.5)
                c:SetPoint("TOPLEFT", A.window, "TOPLEFT", 218 + (i - 1) * 178.5, -181)
                h = 128
            else
                c:SetWidth(224)
            end
            c:SetHeight(h)
            A.UpdateThemeFrame(c)
            c.label.fontWidth = dashboard and 154 or 176
            c.label:SetWidth(c.label.fontWidth)
            c.value.fontWidth = dashboard and 154 or 199
            c.value:SetWidth(c.value.fontWidth)
            c.detail.fontWidth = dashboard and 144 or 199
            c.detail:SetWidth(c.detail.fontWidth)
            c.detail:ClearAllPoints()
            c.detail:SetPoint("TOPLEFT", c, "TOPLEFT", 13, tall and -82 or -72)
            c.label:ClearAllPoints()
            c.value:ClearAllPoints()
            c.icon:ClearAllPoints()
            c.label:SetPoint("TOPLEFT", c, "TOPLEFT", 13, dashboard and -47 or -9)
            c.value:SetPoint("TOPLEFT", c, "TOPLEFT", 13, dashboard and -71 or -32)
            c.label:SetJustifyH(dashboard and "CENTER" or "LEFT")
            c.label.baseSize = dashboard and 14 or 12
            c.label.titleFont = dashboard
            c.value:SetJustifyH(dashboard and "CENTER" or "LEFT")
            c.value.baseSize = dashboard and 31 or 27
            c.value:SetTextColor(
                unpack(dashboard and (i == 2 and COLORS.green or COLORS.text) or COLORS.text)
            )
            c.value:SetHeight(38)
            c.detail:SetHeight(tall and 58 or 22)
            c.detail.baseSize = 11
            c.icon:SetWidth(dashboard and 38 or (tall and 36 or 28))
            c.icon:SetHeight(dashboard and 38 or (tall and 36 or 28))
            if model.layout == "dashboard" then
                c.icon:SetPoint("TOP", c, "TOP", 0, -9)
                A.PaintedGlyph(c.icon, i + 1)
            else
                c.icon:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -12)
                if d.glyph then
                    A.PaintedGlyph(c.icon, d.glyph)
                else
                    icon(c.icon, d.icon, d.class)
                end
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
            paintRow(frame, d, model)
            frame:Show()
        else
            frame.item = nil
            frame:Hide()
        end
    end
    UI.empty:ClearAllPoints()
    UI.empty:SetPoint("TOPLEFT", A.window, "TOPLEFT", 248, -math.min(540, model.rowY + 64))
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
        if UI.retentionDialog then
            UI.retentionDialog:Hide()
            A.pendingRetention = nil
        end
        if UI.menu then
            UI.menu:Hide()
        end
    end
    A.db.settings.open = A.window:IsShown() and true or false
end

--- Create own setting sliders, checks and menus with validated ranges and deferred scale updates.
local function buildSettings(frame)
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -184)
    p:SetWidth(712)
    p:SetHeight(580)
    UI.settings = p
    for _, rect in ipairs({
        { -12, -12, 736, 241 },
        { -12, 232, 356, 180 },
        { 358, 232, 356, 180 },
        { -12, 457, 736, 116 },
    }) do
        for _, texture in ipairs(A.ThemePanel(p, unpack(rect))) do
            table.insert(UI.solids, { texture = texture, multiplier = 0.65 })
        end
    end
    UI.appearance = font(p, 0, 0, 690, 24, 16, COLORS.gold, true)
    UI.behaviour = font(p, 0, 232, 320, 24, 16, COLORS.gold, true)
    UI.storage = font(p, 370, 232, 320, 24, 16, COLORS.gold, true)
    UI.saveNote = font(p, 0, 415, 710, 30, 11, COLORS.muted)
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
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -264 - (i - 1) * 39)
        b:SetWidth(24)
        b:SetHeight(24)
        b.setting = def[1]
        b.key = def[2]
        b.caption = font(p, 32, 264 + (i - 1) * 39, 310, 24, 12, COLORS.text)
        b:SetScript("OnClick", function()
            A.db.settings[this.setting] = not A.db.settings[this.setting]
            A.ApplyUI()
            A.RefreshUI()
        end)
        table.insert(UI.checks, b)
    end
    UI.retentionCaption = font(p, 370, 262, 330, 22, 12, COLORS.text)
    UI.retention = button(p, 370, 290, 330, 28, "", function(self)
        local options = {}
        for _, n in ipairs({ 50, 100, 200, 500, 1000 }) do
            local value = n
            table.insert(options, {
                label = A.Format(value),
                action = function()
                    A.RequestRetention(value)
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    dropdown(UI.language)
    dropdown(UI.retention)
    UI.hudSettingsTitle = font(p, 0, 465, 690, 26, 18, COLORS.gold, true)
    UI.hudSettingsHint = font(p, 0, 504, 340, 48, 12, COLORS.muted)
    button(p, 370, 506, 330, 32, "Customize bar", function()
        A.OpenBarEditor()
    end)
    button(p, 370, 326, 330, 28, "Reset position", function()
        A.ResetPosition()
    end)
    button(p, 370, 364, 330, 28, "Manage local data", function()
        A.OpenDataManagement()
    end)
end

--- Create all addon-owned frames once, then initialize local positioning and presentation.
function A.BuildUI()
    local frame = CreateFrame("Frame", "AzerothStatsWindow", UIParent)
    A.window = frame
    frame:SetWidth(960)
    frame:SetHeight(780)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    surface(frame, "main")
    drag(frame, "windowPos")
    place(frame, "windowPos", "CENTER", 0, 0)
    frame:SetScript("OnHide", function()
        if UI.retentionDialog then
            UI.retentionDialog:Hide()
        end
        if UI.retentionBlocker then
            UI.retentionBlocker:Hide()
        end
        A.pendingRetention = nil
        if UI.dataDialog then
            UI.dataDialog:Hide()
        end
        if UI.dataBlocker then
            UI.dataBlocker:Hide()
        end
        A.pendingDataPlan = nil
        if A.barEditor then
            A.barEditor:Hide()
        end
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
    emblem:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -6)
    emblem:SetWidth(90)
    emblem:SetHeight(90)
    A.PaintedGlyph(emblem, 1)
    UI.title = font(frame, 126, 14, 540, 48, 36, COLORS.gold, true)
    UI.version = font(frame, 730, 42, 150, 20, 11, COLORS.muted)
    UI.breadcrumb = font(frame, 130, 65, 750, 20, 12, COLORS.muted)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -6)
    close:SetWidth(30)
    close:SetHeight(30)
    close:SetScript("OnClick", function()
        A.ToggleUI(false)
    end)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -98)
    divider:SetWidth(914)
    divider:SetHeight(1)
    divider:SetTexture(0.42, 0.32, 0.16)
    local profile = frame:CreateTexture(nil, "ARTWORK")
    profile:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -127)
    profile:SetWidth(48)
    profile:SetHeight(48)
    A.PaintedGlyph(profile, 7)
    UI.profileName = font(frame, 90, 129, 112, 23, 16, COLORS.text)
    UI.profileClass = font(frame, 90, 153, 112, 20, 11, COLORS.muted)
    UI.sidebarNote = font(frame, 29, 738, 160, 17, 10, COLORS.muted)
    UI.sidebarNote:Hide()
    UI.explore = font(frame, 29, 198, 160, 18, 10, COLORS.muted)
    UI.progression = font(frame, 29, 406, 160, 18, 10, COLORS.muted)
    local navY = { 221, 429, 264, 307, 350, 472, 709, 666, 558, 611, 515 }
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
        b.label.baseSize = 14
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.icon:SetWidth(26)
        b.icon:SetHeight(26)
        A.ThemeIcon(b.icon, i == 7 and 12 or i)
        b.navigation = true
        UI.nav[i] = b
    end
    UI.sectionTitle = font(frame, 218, 109, 285, 32, 24, COLORS.gold, true)
    UI.subtitle = font(frame, 218, 143, 710, 16, 11, COLORS.muted)
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
                A.view.cumulative = true
            end
            A.view.page = 1
            A.RefreshUI()
        end)
        b.key = key
        table.insert(UI.usageButtons, b)
    end
    UI.difficultyButton = button(frame, 518, 100, 198, 26, "", function(self)
        local choices = {
            {
                label = A.T("All difficulties"),
                action = function()
                    A.view.difficulty, A.view.page = nil, 1
                end,
            },
        }
        for level = 0, 5 do
            local value = level
            table.insert(choices, {
                label = A.HeroicLabel({ heroic = value }),
                action = function()
                    A.view.difficulty, A.view.page = value, 1
                end,
            })
        end
        table.insert(choices, {
            label = A.T("Difficulty unknown"),
            action = function()
                A.view.difficulty, A.view.page = "unknown", 1
            end,
        })
        A.ShowMenu(self, choices)
    end)
    dropdown(UI.difficultyButton)
    UI.scopeRun = button(frame, 518, 100, 198, 26, "", function(self)
        if A.view.tab == 9 and A.view.usageTab == "Co-op" then
            A.SelectCoopRun(nil)
            A.RefreshUI()
        else
            A.RunMenu(self)
        end
    end)
    dropdown(UI.scopeRun)
    UI.scopeAll = button(frame, 724, 100, 208, 26, "", function()
        A.view.cumulative = true
        A.view.coopPartner = nil
        A.view.combatTab = "Spells"
        A.view.page = 1
        A.RefreshUI()
    end)
    UI.historyFilters = {}
    local searchPanel = CreateFrame("Frame", nil, frame)
    searchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -194)
    searchPanel:SetWidth(228)
    searchPanel:SetHeight(32)
    surface(searchPanel, "card")
    UI.historySearchCaption = font(searchPanel, 6, 0, 215, 12, 11, COLORS.muted)
    UI.historySearchCaption.fixedSize = true
    UI.historySearch = CreateFrame("EditBox", nil, searchPanel)
    UI.historySearch:SetPoint("TOPLEFT", searchPanel, "TOPLEFT", 6, -13)
    UI.historySearch:SetWidth(215)
    UI.historySearch:SetHeight(18)
    UI.historySearch:SetFont(A.Font(false), 12, "")
    UI.historySearch:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    if UI.historySearch.SetAutoFocus then
        UI.historySearch:SetAutoFocus(false)
    end
    if UI.historySearch.SetMaxLetters then
        UI.historySearch:SetMaxLetters(80)
    end
    UI.historySearch:SetScript("OnTextChanged", function()
        if not this.syncing then
            A.view.historySearch = A.Text(this:GetText() or "", 80)
            A.view.page = 1
            A.RefreshUI()
        end
    end)
    UI.historySearch:SetScript("OnEscapePressed", function()
        if this.ClearFocus then
            this:ClearFocus()
        end
    end)
    table.insert(UI.historyFilters, searchPanel)
    UI.historyResult = button(frame, 454, 194, 148, 32, "", function(self)
        local options = {
            {
                label = A.T("All results"),
                action = function()
                    A.view.historyResult = nil
                    A.view.page = 1
                end,
            },
        }
        for _, result in ipairs({ "active", "victory", "defeat", "left", "interrupted" }) do
            local key = result
            table.insert(options, {
                label = A.Status(key),
                action = function()
                    A.view.historyResult = key
                    A.view.page = 1
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    UI.historyKind = button(frame, 610, 194, 148, 32, "", function(self)
        local options = {}
        for _, pair in ipairs({
            { "all", "All runs" },
            { "coop", "Co-op" },
            {
                "favorite",
                "Favorites",
            },
        }) do
            local key = pair[1]
            table.insert(options, {
                label = A.T(pair[2]),
                action = function()
                    A.view.historyKind = key
                    A.view.page = 1
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    UI.historyReset = button(frame, 766, 194, 166, 32, "", function()
        A.ClearHistoryFilters()
        A.RefreshUI()
    end)
    for _, b in ipairs({ UI.historyResult, UI.historyKind, UI.historyReset }) do
        b.label.fixedSize = true -- Compact toolbar; body rows honor the user's text size.
        table.insert(UI.historyFilters, b)
    end
    dropdown(UI.historyResult)
    dropdown(UI.historyKind)
    UI.journalFilter = button(frame, 714, 318, 218, 26, "", function(self)
        local options = {
            {
                label = A.T("All changes"),
                action = function()
                    A.view.journalKind = nil
                    A.view.page = 1
                end,
            },
        }
        for _, pair in ipairs({
            { "ranks", "Rank changes" },
            { "stats", "Stat changes" },
            { "gear", "Equipment changes" },
        }) do
            local key = pair[1]
            table.insert(options, {
                label = A.T(pair[2]),
                action = function()
                    A.view.journalKind = key
                    A.view.page = 1
                end,
            })
        end
        A.ShowMenu(self, options)
    end)
    dropdown(UI.journalFilter)
    UI.reportDetails = button(frame, 714, 318, 218, 26, "", function()
        local id = A.view.selected or (A.Selected() and A.Selected().id)
        if A.view.reportSection == "Combat" then
            A.SelectRun(id)
        else
            A.view.tab = 5
            A.view.selected = id
            A.view.cumulative = false
            A.view.page = 1
        end
        A.RefreshUI()
    end)
    UI.historySections, UI.reportSections, UI.compareSections = {}, {}, {}
    for i, key in ipairs({ "History", "Run report", "Compare runs" }) do
        local section = key
        local b = button(frame, 218 + (i - 1) * 240, 160, 232, 26, key, function()
            if section == "Compare runs" then
                A.OpenCompare(A.Selected() and A.Selected().id)
            elseif section == "Run report" then
                A.OpenReport(A.Selected() and A.Selected().id)
            else
                A.view.historySection, A.view.page = "History", 1
            end
            A.RefreshUI()
        end)
        table.insert(UI.historySections, b)
    end
    for i, key in ipairs({ "Overview", "Combat", "Character", "Co-op", "Records", "Build journal" }) do
        local section = key
        local b = button(frame, 218 + (i - 1) * 120, 274, 112, 26, key, function()
            A.view.reportSection, A.view.page = section, 1
            A.RefreshUI()
        end)
        table.insert(UI.reportSections, b)
    end
    for i, key in ipairs({ "Overview", "Combat", "Spells", "Equipment" }) do
        local section = key
        local b = button(frame, 218 + (i - 1) * 180, 330, 172, 26, key, function()
            A.view.compareSection, A.view.page = section, 1
            A.RefreshUI()
        end)
        table.insert(UI.compareSections, b)
    end
    UI.reportCompare = button(frame, 518, 100, 198, 26, "Compare runs", function()
        A.OpenCompare(A.Selected() and A.Selected().id)
        A.RefreshUI()
    end)
    UI.swapRuns = button(frame, 724, 100, 208, 26, "Swap runs", function()
        A.view.compareA, A.view.compareB, A.view.page = A.view.compareB, A.view.compareA, 1
        A.RefreshUI()
    end)
    UI.compareHeaders, UI.compareSelectors, UI.compareColumns = {}, {}, {}
    for i = 1, 2 do
        local side = i == 1 and "A" or "B"
        UI.compareSelectors[i] = button(frame, 218 + (i - 1) * 360, 198, 354, 26, "", function(self)
            A.ComparisonRunMenu(self, side)
        end)
        dropdown(UI.compareSelectors[i])
        local band = CreateFrame("Button", nil, frame)
        band:SetPoint("TOPLEFT", frame, "TOPLEFT", 218 + (i - 1) * 360, -232)
        band:SetWidth(354)
        band:SetHeight(83)
        surface(band, "card")
        band.icon = band:CreateTexture(nil, "ARTWORK")
        band.icon:SetPoint("LEFT", band, "LEFT", 8, 0)
        band.icon:SetWidth(100)
        band.icon:SetHeight(100 * 66 / 178)
        band.label = font(band, 119, 7, 207, 23, 14, COLORS.gold, true)
        band.detail = font(band, 119, 33, 203, 43, 11, COLORS.muted)
        band.favorite = favoriteButton(band, 328, 52)
        band:SetScript("OnEnter", function()
            tooltip(this)
        end)
        band:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        UI.compareHeaders[i] = band
        UI.compareColumns[i] = font(frame, 398 + (i - 1) * 185, 392, 170, 22, 12, COLORS.gold)
        UI.compareColumns[i]:SetJustifyH("RIGHT")
        put(UI.compareColumns[i], side)
    end
    UI.reportToast = button(UIParent, 0, 0, 360, 42, "", function()
        if A.pendingReport and A.FindRun(A.pendingReport.id) then
            A.OpenReport(A.pendingReport.id)
            A.ToggleUI(true)
        end
        A.pendingReport = nil
        UI.reportToast:Hide()
    end)
    UI.reportToast:ClearAllPoints()
    UI.reportToast:SetPoint("TOP", UIParent, "TOP", 0, -170)
    UI.reportToast:SetFrameStrata("DIALOG")
    UI.reportToast.label.fontWidth = 316
    UI.reportToast.label:SetWidth(316)
    UI.reportToast.dismiss = button(UI.reportToast, 330, 8, 22, 24, "X", function()
        A.pendingReport = nil
        UI.reportToast:Hide()
    end)
    UI.reportToast:Hide()
    UI.context = CreateFrame("Button", nil, frame)
    UI.context:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -199)
    UI.context:SetWidth(714)
    UI.context:SetHeight(62)
    surface(UI.context, "card")
    UI.context.icon = UI.context:CreateTexture(nil, "ARTWORK")
    UI.context.icon:SetPoint("LEFT", UI.context, "LEFT", 12, 0)
    UI.context.label = font(UI.context, 56, 6, 444, 24, 14, COLORS.text, true)
    UI.context.detail = font(UI.context, 56, 33, 634, 20, 11, COLORS.muted)
    UI.context.value = font(UI.context, 520, 6, 170, 24, 13, COLORS.gold)
    UI.context.value:SetJustifyH("RIGHT")
    UI.context:SetScript("OnEnter", function()
        tooltip(this)
    end)
    UI.context:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    UI.columnLabel = font(frame, 218, 270, 410, 22, 11, COLORS.muted)
    UI.columnLabel.columnX = 218
    UI.columnValue = font(frame, 738, 270, 152, 22, 11, COLORS.muted)
    UI.columnValue.columnX = 738
    UI.columnValue:SetJustifyH("RIGHT")
    UI.columnShare = font(frame, 653, 270, 70, 22, 11, COLORS.muted)
    UI.columnShare.columnX = 653
    UI.columnShare:SetJustifyH("RIGHT")
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
        r.thumbnail = r:CreateTexture(nil, "ARTWORK")
        r.thumbnail:SetPoint("TOPLEFT", r, "TOPLEFT", 5, -8)
        r.thumbnail:SetWidth(178)
        r.thumbnail:SetHeight(66)
        r.thumbnail:Hide()
        r.label = font(r, 35, 1, 412, 22, 12, COLORS.text)
        r.value = font(r, 455, 0, 225, 23, 13, COLORS.gold)
        r.value:SetJustifyH("RIGHT")
        r.favorite = favoriteButton(r, 687, 1)
        r.detail = font(r, 35, 19, 670, 15, 9, COLORS.muted)
        r.extra = font(r, 160, 51, 510, 18, 11, COLORS.muted)
        r.rank = font(r, 4, 10, 22, 24, 11, COLORS.gold)
        r.rank:SetJustifyH("CENTER")
        r.share = font(r, 435, 8, 70, 23, 12, COLORS.muted)
        r.share:SetJustifyH("RIGHT")
        r.leftValue = font(r, 180, 5, 170, 38, 12, COLORS.text)
        r.rightValue = font(r, 365, 5, 170, 38, 12, COLORS.text)
        for _, side in ipairs({ "left", "right" }) do
            local cell = CreateFrame("Button", nil, r)
            cell:SetPoint("TOPLEFT", r, "TOPLEFT", side == "left" and 180 or 365, -2)
            cell:SetWidth(170)
            cell:SetHeight(44)
            cell:SetScript("OnEnter", function()
                tooltip(this)
            end)
            cell:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            r[side .. "Cell"] = cell
        end
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
    UI.recentTitle = font(frame, 218, 322, 430, 30, 22, COLORS.gold, true)
    UI.recentEmpty = font(frame, 240, 370, 650, 55, 14, COLORS.muted)
    UI.historyLink = button(frame, 772, 322, 160, 30, "History", function()
        selectTab(3)
    end)
    UI.recordsTitle = font(frame, 218, 612, 430, 30, 22, COLORS.gold, true)
    UI.recordsLink = button(frame, 772, 612, 160, 30, "Records", function()
        selectTab(6)
    end)
    UI.recordPanel = CreateFrame("Frame", nil, frame)
    UI.recordPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 218, -649)
    UI.recordPanel:SetWidth(714)
    UI.recordPanel:SetHeight(60)
    surface(UI.recordPanel, "card")
    UI.recordItems = {}
    for index = 1, 3 do
        local record = CreateFrame("Button", nil, UI.recordPanel)
        record:SetPoint("TOPLEFT", UI.recordPanel, "TOPLEFT", 10 + (index - 1) * 238, 0)
        record:SetWidth(218)
        record:SetHeight(60)
        local glyph = record:CreateTexture(nil, "ARTWORK")
        glyph:SetPoint("LEFT", record, "LEFT", 2, 0)
        glyph:SetWidth(30)
        glyph:SetHeight(30)
        A.PaintedGlyph(glyph, ({ 4, 5, 2 })[index])
        record.label = font(record, 42, 5, 166, 18, 11, COLORS.muted)
        record.value = font(record, 42, 25, 166, 28, 21, COLORS.text)
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
    UI.note = font(frame, 218, 738, 714, 19, 10, COLORS.muted)
    UI.previous = button(frame, 218, 714, 38, 24, "<", function()
        A.view.page = math.max(1, A.view.page - 1)
        A.RefreshUI()
    end)
    UI.next = button(frame, 265, 714, 38, 24, ">", function()
        local model = A.PageModel()
        A.view.page = math.min(math.ceil(table.getn(model.rows) / model.capacity), A.view.page + 1)
        A.RefreshUI()
    end)
    UI.paging = font(frame, 320, 715, 400, 23, 11, COLORS.muted)
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function()
            A.view.page = A.view.page - (arg1 or 0)
            A.RefreshUI()
        end)
    end
    UI.retentionBlocker = CreateFrame("Frame", nil, frame)
    UI.retentionBlocker:SetAllPoints(frame)
    UI.retentionBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
    UI.retentionBlocker:SetFrameLevel(frame:GetFrameLevel() + 49)
    UI.retentionBlocker:EnableMouse(true)
    UI.retentionBlocker:SetScript("OnMouseDown", function() end)
    solid(UI.retentionBlocker, 0, 0, 0, 0.65)
    UI.retentionBlocker:Hide()
    UI.retentionDialog = CreateFrame("Frame", "AzerothStatsRetentionConfirmation", frame)
    local dialog = UI.retentionDialog
    dialog:SetPoint("CENTER", frame, "CENTER", 0, 0)
    dialog:SetWidth(480)
    dialog:SetHeight(250)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(frame:GetFrameLevel() + 50)
    dialog:EnableMouse(true)
    surface(dialog, "main")
    dialog.heading = font(dialog, 20, 20, 440, 52, 18, COLORS.gold, true)
    dialog.message = font(dialog, 20, 78, 440, 100, 13, COLORS.text)
    dialog.cancel = button(dialog, 20, 200, 210, 30, "Cancel", function()
        A.pendingRetention = nil
        UI.retentionBlocker:Hide()
        dialog:Hide()
    end)
    dialog.confirm = button(dialog, 250, 200, 210, 30, "Apply", function()
        local pending = A.pendingRetention
        if pending and A.RequestRetention(pending.limit, true) then
            UI.retentionBlocker:Hide()
            dialog:Hide()
            A.RefreshUI()
        end
    end)
    dialog:SetScript("OnHide", function()
        UI.retentionBlocker:Hide()
        A.pendingRetention = nil
    end)
    dialog:Hide()
    function A.ShowRetentionConfirmation()
        local pending = A.pendingRetention
        if not pending then
            return
        end
        if not A.window:IsShown() then
            A.window:Show()
            A.db.settings.open = true
        end
        put(dialog.heading, A.T("Confirm history pruning"))
        put(
            dialog.message,
            A.T("Run details to remove")
                .. ": "
                .. pending.count
                .. "\n\n"
                .. A.T("Cumulative statistics and favorites are kept")
        )
        put(dialog.cancel.label, A.T("Cancel"))
        put(dialog.confirm.label, A.T("Apply"))
        UI.retentionBlocker:Show()
        dialog:Show()
    end
    if UISpecialFrames then
        table.insert(UISpecialFrames, "AzerothStatsRetentionConfirmation")
    end

    UI.dataBlocker = CreateFrame("Frame", nil, frame)
    UI.dataBlocker:SetAllPoints(frame)
    UI.dataBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
    UI.dataBlocker:SetFrameLevel(frame:GetFrameLevel() + 59)
    UI.dataBlocker:EnableMouse(true)
    UI.dataBlocker:SetScript("OnMouseDown", function() end)
    solid(UI.dataBlocker, 0, 0, 0, 0.65)
    UI.dataBlocker:Hide()
    UI.dataDialog = CreateFrame("Frame", "AzerothStatsDataManagement", frame)
    local data = UI.dataDialog
    data:SetPoint("CENTER", frame, "CENTER", 0, 0)
    data:SetWidth(920)
    data:SetHeight(660)
    data:SetFrameStrata("FULLSCREEN_DIALOG")
    data:SetFrameLevel(frame:GetFrameLevel() + 60)
    data:EnableMouse(true)
    surface(data, "main")
    data.title = font(data, 22, 18, 876, 40, 22, COLORS.gold, true)
    data.reviewHeading = font(data, 22, 66, 616, 42, 18, COLORS.gold, true)
    data.reviewHint = font(data, 22, 112, 616, 68, 13, COLORS.text)
    data.selectionHint = font(data, 22, 584, 616, 24, 11, COLORS.muted)
    -- Selection and review are separate stages. Only the review stage can mutate data.
    data.actions = {}
    for index, kind in ipairs({
        "run",
        "history",
        "reset",
        "nemesis",
        "records",
        "trends",
        "favorites",
    }) do
        local choice = kind
        local x = index <= 3 and (22 + (index - 1) * 208) or (22 + (index - 4) * 156)
        local y = index <= 3 and 66 or 108
        data.actions[index] = button(data, x, y, index <= 3 and 200 or 148, 34, "", function()
            data.kind, data.stage, data.previewPage = choice, "select", 1
            data.status = nil
            data.token:SetText("")
            A.PrepareDataAction(choice, choice == "history" and data.class or nil, data.id)
            A.RefreshDataDialog()
        end)
    end
    data.scopeButton = button(data, 22, 156, 616, 32, "", function(self)
        local choices = {}
        table.insert(choices, {
            label = A.T("All classes"),
            action = function()
                data.class, data.status, data.previewPage = nil, nil, 1
                A.PrepareDataAction("history", nil)
                A.RefreshDataDialog()
            end,
        })
        local keys, seen = {}, {}
        for _, run in ipairs(A.db.runs) do
            if A.knownClasses[run.class] and not seen[run.class] then
                seen[run.class] = true
                table.insert(keys, run.class)
            end
        end
        table.sort(keys)
        for _, value in ipairs(keys) do
            local class = value
            local plan = A.DataPlan("history", class)
            table.insert(choices, {
                label = A.ClassName(class) .. " (" .. (plan and plan.count or 0) .. ")",
                action = function()
                    data.class, data.status, data.previewPage = class, nil, 1
                    A.PrepareDataAction("history", class)
                    A.RefreshDataDialog()
                end,
            })
        end
        if table.getn(choices) > 0 then
            A.ShowMenu(self, choices)
        end
    end)
    dropdown(data.scopeButton)
    data.context = font(data, 22, 198, 616, 42, 12, COLORS.muted)
    data.message = font(data, 22, 464, 616, 76, 14, COLORS.text)
    data.warning = font(data, 22, 544, 616, 40, 12, COLORS.gold)
    data.tokenCaption = font(data, 22, 584, 360, 24, 12, COLORS.text)
    data.token = CreateFrame("EditBox", nil, data)
    data.token:SetPoint("TOPLEFT", data, "TOPLEFT", 442, -584)
    data.token:SetWidth(196)
    data.token:SetHeight(26)
    if data.token.SetAutoFocus then
        data.token:SetAutoFocus(false)
    end
    if data.token.SetMaxLetters then
        data.token:SetMaxLetters(5)
    end
    data.token:SetFont(A.Font(false), 14, "")
    data.token:SetTextColor(1, 1, 1)
    surface(data.token, "card")
    data.token:SetScript("OnTextChanged", function()
        if A.RefreshDataDialog and data:IsShown() then
            A.RefreshDataDialog()
        end
    end)
    data.token:SetScript("OnEscapePressed", function()
        if this.ClearFocus then
            this:ClearFocus()
        end
    end)
    data.cancel = button(data, 22, 618, 140, 28, "Cancel", function()
        A.pendingDataPlan = nil
        UI.dataBlocker:Hide()
        data:Hide()
    end)
    data.confirm = button(data, 338, 618, 300, 28, "", function()
        if data.stage ~= "review" then
            local plan = A.PrepareDataAction(
                data.kind,
                data.kind == "history" and data.class or nil,
                data.id
            )
            if not plan or not plan.allowed then
                A.RefreshDataDialog()
                return
            end
            data.stage, data.previewPage = "review", 1
            A.RefreshDataDialog()
            return
        end
        local ok, message = A.ConfirmDataAction(data.token:GetText() or "")
        if ok then
            UI.dataBlocker:Hide()
            data:Hide()
            A.ApplyUI()
            A.RefreshUI()
            A.Say(A.T(message))
        else
            data.status = message
            data.stage = "select"
            data.token:SetText("")
            A.RefreshDataDialog()
        end
    end)
    data:SetScript("OnHide", function()
        A.pendingDataPlan = nil
        UI.dataBlocker:Hide()
        if UI.menu and UI.menu.owner == data then
            UI.menu:Hide()
        end
        if data.token.ClearFocus then
            data.token:ClearFocus()
        end
    end)
    data:Hide()
    data.back = button(data, 174, 618, 152, 28, "Back", function()
        data.stage, data.status = "select", nil
        data.token:SetText("")
        A.RefreshDataDialog()
    end)
    data.rows = {}
    for index = 1, 4 do
        local row = CreateFrame("Button", nil, data)
        row:SetPoint("TOPLEFT", data, "TOPLEFT", 22, -244 - (index - 1) * 44)
        row:SetWidth(616)
        row:SetHeight(42)
        row.base = solid(row, 0.12, 0.16, 0.17, 0.7)
        row.callback = function()
            if not row.runId then
                return
            end
            data.previewId = row.runId
            if data.stage == "select" and data.kind == "run" then
                data.id, data.status = row.runId, nil
                A.PrepareDataAction("run", nil, data.id)
            end
            A.RefreshDataDialog()
        end
        row:SetScript("OnClick", row.callback)
        row.name = font(row, 8, 3, 600, 19, 12, COLORS.text)
        row.detail = font(row, 8, 23, 600, 17, 11, COLORS.muted)
        data.rows[index] = row
    end
    data.previous = button(data, 22, 428, 40, 26, "<", function()
        data.previewPage = math.max(1, (data.previewPage or 1) - 1)
        A.RefreshDataDialog()
    end)
    data.next = button(data, 70, 428, 40, 26, ">", function()
        data.previewPage = (data.previewPage or 1) + 1
        A.RefreshDataDialog()
    end)
    data.page = font(data, 122, 432, 516, 22, 12, COLORS.muted)
    data.preview = CreateFrame("Frame", nil, data)
    local preview = data.preview
    preview:SetPoint("TOPLEFT", data, "TOPLEFT", 658, -66)
    preview:SetWidth(240)
    preview:SetHeight(540)
    surface(preview, "card")
    preview.title = font(preview, 12, 10, 216, 30, 16, COLORS.gold, true)
    preview.image = preview:CreateTexture(nil, "ARTWORK")
    preview.image:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, -48)
    preview.image:SetWidth(216)
    preview.image:SetHeight(88)
    preview.identity = font(preview, 12, 144, 216, 88, 12, COLORS.text)
    preview.values = font(preview, 12, 240, 216, 170, 12, COLORS.text)
    preview.note = font(preview, 12, 418, 216, 110, 11, COLORS.muted)
    function A.RefreshDataPreview(run, category, plan)
        preview.identity:ClearAllPoints()
        preview.identity:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, category and -52 or -144)
        preview.values:ClearAllPoints()
        preview.values:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, category and -140 or -240)
        preview.note:ClearAllPoints()
        preview.note:SetPoint("TOPLEFT", preview, "TOPLEFT", 12, category and -330 or -418)
        put(preview.title, A.T(category or "Run report"))
        show(preview.image, run ~= nil and not category)
        if category then
            put(preview.identity, A.T("All classes"))
            put(
                preview.values,
                A.T("Global")
                    .. " · "
                    .. A.T("Details")
                    .. ": "
                    .. (plan and plan.count or 0)
                    .. "\n\n"
                    .. A.T("Classes")
                    .. " · "
                    .. A.T("Details")
                    .. ": "
                    .. (plan and plan.classEntries or 0)
                    .. "\n\n"
                    .. A.T("History")
                    .. " · "
                    .. A.T("Details")
                    .. ": "
                    .. (plan and plan.details or 0)
            )
            put(
                preview.note,
                A.T("History")
                    .. " · "
                    .. A.T("Combat")
                    .. "\n"
                    .. A.T("Character")
                    .. " · "
                    .. A.T("Coop")
                    .. "\n\n"
                    .. A.T("Other categories")
                    .. " · "
                    .. A.T("Settings")
            )
        elseif run then
            A.ZoneIllustration(preview.image, run.zone)
            put(
                preview.identity,
                A.ZoneName(run)
                    .. "\n"
                    .. A.RunContext(run)
                    .. "\n"
                    .. (run.hero or "?")
                    .. " · "
                    .. A.Status(run.result or run.status)
            )
            local lines = {}
            for _, key in ipairs({ "duration", "level", "kills", "gold", "damage", "bosses" }) do
                local value = run.values[key]
                local display = key == "duration" and A.Duration(value) or A.Short(value)
                table.insert(lines, A.Metric(key) .. ": " .. display)
            end
            put(preview.values, table.concat(lines, "\n\n"))
            put(
                preview.note,
                (A.CoopLabel(run) or A.T("Unavailable"))
                    .. "\n"
                    .. run.id
                    .. "\n"
                    .. A.T("Values from available samples")
            )
        else
            put(preview.identity, A.T("Select a run to preview"))
            put(preview.values, "")
            put(preview.note, "")
        end
    end
    function A.RefreshDataDialog()
        local plan = A.pendingDataPlan
        local review = data.stage == "review"
        local category = A.dataCategories[data.kind]
        local labels = {
            "One run",
            "History cleanup",
            "Full reset",
            "Nemesis",
            "Records",
            "Trends",
            "Favorites",
        }
        local kinds = { "run", "history", "reset", "nemesis", "records", "trends", "favorites" }
        put(
            data.title,
            A.T(review and "Confirm deletion" or "Manage local data")
                .. " · "
                .. (review and "2/2" or "1/2")
        )
        local actions = {
            run = "Delete run details",
            history = "Clear retained history",
            reset = "Reset all statistics",
            records = "Clear records",
            nemesis = "Clear nemesis",
            trends = "Clear trends",
            favorites = "Clear favorites",
        }
        local action = A.T(actions[data.kind] or "Delete data")
        put(data.reviewHeading, action)
        put(data.reviewHint, A.T("This click permanently deletes the selected data"))
        put(data.selectionHint, A.T("Nothing is deleted at this step"))
        show(data.reviewHeading, review)
        show(data.reviewHint, review)
        show(data.selectionHint, not review)
        for index, control in ipairs(data.actions) do
            put(control.label, A.T(labels[index]))
            selected(control, data.kind == kinds[index])
            show(control, not review)
        end
        show(data.scopeButton, not review and data.kind == "history")
        local run = data.id and A.FindRun(data.id)
        put(
            data.scopeButton.label,
            data.kind == "run" and (run and A.RunContext(run) or A.T("Unavailable"))
                or (data.class and A.ClassName(data.class) or A.T("All classes"))
        )
        put(
            data.context,
            A.T(review and "Review before deleting" or "Choose what to remove")
                .. "\n"
                .. A.T(
                    category and "Category cleanup applies to all classes"
                        or data.kind == "reset" and "Reset all statistics"
                        or "History only; totals stay unchanged"
                )
        )
        local count = plan and plan.count or 0
        local choosingRun = not review and data.kind == "run"
        local candidates = {}
        if choosingRun then
            for _, item in ipairs(A.db.runs) do
                table.insert(candidates, item.id)
            end
        else
            candidates = plan and plan.ids or {}
        end
        local listed = table.getn(candidates)
        local pages = math.max(1, math.ceil(listed / 4))
        data.previewPage = math.max(1, math.min(data.previewPage or 1, pages))
        for index, row in ipairs(data.rows) do
            local id = candidates[listed - (data.previewPage - 1) * 4 - index + 1]
            local item = id and A.FindRun(id)
            if not choosingRun and data.kind == "run" and index == 1 then
                item = run
            end
            row.runId = item and item.id
            local active = choosingRun and item and item.id == data.id
            row.base:SetTexture(
                active and 0.26 or 0.12,
                active and 0.21 or 0.16,
                active and 0.12 or 0.17
            )
            show(row, item ~= nil)
            if item then
                put(row.name, A.RunLabel(item))
                put(row.detail, A.RunContext(item) .. " · " .. item.id)
            end
        end
        local previewRun = data.kind == "run" and run
            or (data.previewId and A.FindRun(data.previewId))
        if not previewRun and listed > 0 then
            previewRun = A.FindRun(candidates[listed])
        end
        A.RefreshDataPreview(previewRun, category, plan)
        show(data.previous, pages > 1)
        show(data.next, pages > 1)
        put(
            data.page,
            A.T(category and "Historical entries" or "Run details to remove")
                .. ": "
                .. (category and (plan and plan.details or 0) or count)
                .. " · "
                .. A.T("Page")
                .. " "
                .. data.previewPage
                .. "/"
                .. pages
        )
        local removed = A.T("History")
            .. " ("
            .. count
            .. ") · "
            .. A.T("Combat")
            .. ", "
            .. A.T("Character")
            .. ", "
            .. A.T("Coop")
            .. ", "
            .. A.T("Build journal")
        local kept = A.T("All statistics")
            .. ", "
            .. A.T("Records")
            .. ", "
            .. A.T("Trends")
            .. ", "
            .. A.T("Favorites")
            .. ", "
            .. A.T("Settings")
        if category then
            removed = A.T(category)
                .. " · "
                .. A.T("Details")
                .. ": "
                .. count
                .. " · "
                .. A.T("Historical entries")
                .. ": "
                .. (plan and plan.details or 0)
            if data.kind == "nemesis" then
                removed = removed
                    .. " · "
                    .. A.T("Observed deaths")
                    .. ": "
                    .. (plan and plan.observed or 0)
            end
            kept = A.T("Historical combat and builds are kept")
                .. " · "
                .. A.T("Settings")
                .. ", "
                .. A.T("Other categories")
        elseif data.kind == "reset" then
            removed = A.T("All statistics")
                .. ", "
                .. A.T("History")
                .. " ("
                .. count
                .. "), "
                .. A.T("Favorites")
                .. " ("
                .. (plan and plan.favorites or 0)
                .. ")"
            kept = A.T("Settings")
        else
            kept = kept .. " · " .. A.T("Protected runs") .. ": " .. (plan and plan.protected or 0)
        end
        put(
            data.message,
            A.T("Will be deleted")
                .. ": "
                .. removed
                .. "\n\n"
                .. A.T("Will be kept")
                .. ": "
                .. kept
        )
        put(
            data.warning,
            data.status and A.T(data.status)
                or plan and plan.reason and A.T(plan.reason)
                or A.T(
                    data.kind == "favorites"
                            and "Removing favorites unprotects runs from future history cleanup"
                        or "This cannot be undone"
                )
        )
        put(data.tokenCaption, A.T("Type RESET to confirm"))
        data.token:SetFont(A.Font(false), 14, "")
        show(data.token, review and data.kind == "reset")
        show(data.tokenCaption, review and data.kind == "reset")
        show(data.back, review)
        put(data.back.label, A.T("Back"))
        put(data.cancel.label, A.T("Cancel"))
        put(data.confirm.label, review and action or A.T("Review deletion"))
        local color = review and { 1, 0.4, 0.32 } or COLORS.gold
        data.confirm.label:SetTextColor(color[1], color[2], color[3])
        local enabled = plan
            and plan.allowed
            and (not review or data.kind ~= "reset" or data.token:GetText() == "RESET")
        data.confirm:SetAlpha(enabled and 1 or 0.45)
    end
    function A.OpenDataManagement()
        A.ToggleUI(true)
        if A.barEditor then
            A.barEditor:Hide()
        end
        if UI.retentionDialog then
            UI.retentionDialog:Hide()
        end
        A.pendingRetention = nil
        if UI.menu then
            UI.menu:Hide()
        end
        data.kind, data.class = "history", A.view.class
        data.stage, data.previewPage, data.previewId = "select", 1, nil
        local run = A.Selected()
        data.id = run and run.id
        data.status = nil
        data.token:SetText("")
        A.PrepareDataAction(data.kind, data.class, data.id)
        A.RefreshDataDialog()
        UI.dataBlocker:Show()
        data:Show()
    end
    if UISpecialFrames then
        table.insert(UISpecialFrames, "AzerothStatsDataManagement")
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
    A.PaintedGlyph(mini.icon, 1)
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
    rescale = rescale,
}

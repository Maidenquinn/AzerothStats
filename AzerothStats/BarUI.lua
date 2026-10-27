-- Native HUD/editor widgets. Changes stay in an editor draft until Apply.
-- The HUD reads Bar.lua models; no combat/accounting state is modified here.
local A = AzerothStats
local W = A.widgets
local editor

--- Ellipsize plain HUD text at the readable floor; full model text stays available in its tooltip.
local function barText(font, value)
    W.put(font, value)
    if font.GetStringWidth then
        local prefix = value
        while string.len(prefix) > 0 and font:GetStringWidth() > font.fontWidth do
            prefix = A.PrefixText(prefix, string.len(prefix) - 1)
            font:SetText(prefix .. "...")
        end
    end
end

--- Start moving only the owned HUD when both relevant position locks permit it.
local function startDrag()
    if not A.db.settings.locked and not A.db.settings.hud.locked then
        A.bar:StartMoving()
    end
end

--- Store only the HUD anchor after a native drag, never screen/game settings.
local function stopDrag()
    A.bar:StopMovingOrSizing()
    local point, _, relative, x, y = A.bar:GetPoint()
    A.db.settings.barPos = A.FramePosition({ point, relative, x, y })
end

--- Show the exact value, scope and coverage semantics without cluttering every HUD segment.
local function blockTooltip()
    local model = this.model
    if not model then
        return
    end
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(model.label, 0.85, 0.71, 0.42)
    GameTooltip:AddLine(model.exact, 0.94, 0.91, 0.83)
    GameTooltip:AddLine(model.scope, 0.72, 0.78, 0.78)
    GameTooltip:AddLine(model.detail, 0.65, 0.70, 0.70, true)
    if model.partial then
        GameTooltip:AddLine(A.T("Partial"), 0.95, 0.7, 0.4)
    end
    GameTooltip:Show()
end

--- Allocate a fixed set of eight reusable segments and source-defined native handlers.
local function barFrame(parent, preview)
    local frame =
        CreateFrame("Button", preview and "AzerothStatsBarPreview" or "AzerothStatsBar", parent)
    frame.preview = preview
    frame:SetFrameStrata("DIALOG")
    W.surface(frame, "main")
    frame.cells = {}
    frame.seal = frame:CreateTexture(nil, "ARTWORK")
    frame.seal:SetTexture(A.theme.seal)
    frame.seal:SetPoint("LEFT", frame, "LEFT", 5, 0)
    frame.seal:SetWidth(30)
    frame.seal:SetHeight(30)
    frame.gear = W.button(frame, 0, 0, 27, 24, "", function()
        if not preview then
            A.OpenBarEditor()
        end
    end)
    frame.gear.icon = frame.gear:CreateTexture(nil, "ARTWORK")
    frame.gear.icon:SetAllPoints(frame.gear)
    A.ThemeIcon(frame.gear.icon, 8)
    frame.overflow = W.button(frame, 0, 0, 32, 24, "+", function()
        if not preview then
            A.OpenBarEditor()
        end
    end)
    frame.overflow:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(A.T("More statistics"), 0.85, 0.71, 0.42)
        for _, model in ipairs(frame.models or {}) do
            GameTooltip:AddLine(
                model.label .. " · " .. model.scope .. ": " .. model.value,
                0.94,
                0.91,
                0.83,
                true
            )
        end
        GameTooltip:Show()
    end)
    for index = 1, 8 do
        local cell = CreateFrame("Button", nil, frame)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetWidth(18)
        cell.icon:SetHeight(18)
        cell.caption = W.font(cell, 0, 0, 130, 16, 11, A.theme.muted)
        cell.value = W.font(cell, 0, 16, 130, 20, 13, A.theme.text)
        cell.caption.fixedSize = true
        cell.value.fixedSize = true
        cell.line = W.solid(cell, 0.54, 0.44, 0.27, 0.5, "ARTWORK")
        cell.line:ClearAllPoints()
        cell.line:SetPoint("LEFT", cell, "LEFT", 0, 0)
        cell.line:SetWidth(1)
        cell:SetScript("OnEnter", blockTooltip)
        cell:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        cell:SetScript("OnClick", function()
            if not preview and this.model then
                A.OpenBarBlock(this.model.block)
            end
        end)
        if not preview then
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", startDrag)
            cell:SetScript("OnDragStop", stopDrag)
        end
        frame.cells[index] = cell
    end
    if not preview then
        W.drag(frame, "barPos")
        frame:SetScript("OnDragStart", startDrag)
        frame:SetScript("OnDragStop", stopDrag)
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        frame:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                A.OpenBarEditor()
            else
                A.ToggleUI()
            end
        end)
    end
    return frame
end

--- Render a bounded layout; extra segments stay accessible in an explicit overflow tooltip.
local function paintBar(frame, config)
    local layout = A.BarLayout(config, UIParent:GetWidth())
    frame.layout = layout
    frame.models = {}
    frame:SetWidth(layout.width)
    frame:SetHeight(layout.height)
    frame.base:SetAlpha(config.opacity)
    if frame.grain then
        frame.grain:SetAlpha(config.opacity * 0.16)
    end
    frame.gear:ClearAllPoints()
    frame.gear:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    frame.overflow:ClearAllPoints()
    frame.overflow:SetPoint("RIGHT", frame.gear, "LEFT", -2, 0)
    if layout.overflow > 0 then
        frame.overflow:Show()
    else
        frame.overflow:Hide()
    end
    local width = (layout.width - (layout.overflow > 0 and 100 or 68)) / layout.columns
    local height = (layout.height - 6) / layout.rows
    for index, block in ipairs(config.blocks) do
        frame.models[index] = A.BarBlockModel(block)
    end
    for index, cell in ipairs(frame.cells) do
        local model = index <= layout.capacity and frame.models[index] or nil
        cell.model = model
        if model then
            local col, row =
                math.mod(index - 1, layout.columns), math.floor((index - 1) / layout.columns)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", frame, "TOPLEFT", 38 + col * width, -3 - row * height)
            cell:SetWidth(width)
            cell:SetHeight(height)
            cell.line:SetHeight(math.max(12, height - 10))
            local x = config.icons and 30 or 9
            cell.icon:ClearAllPoints()
            cell.icon:SetPoint("LEFT", cell, "LEFT", 7, 0)
            local glyph = { runs = 1, wins = 6, duration = 3, kills = 11 }
            if glyph[model.block.metric] then
                A.ThemeIcon(cell.icon, glyph[model.block.metric])
            else
                W.icon(cell.icon, model.icon)
            end
            if config.icons then
                cell.icon:Show()
            else
                cell.icon:Hide()
            end
            cell.value:SetJustifyH("LEFT")
            local twoLines = height >= 35
            local shortScope = model.block.scope == "all" and A.T("Global")
                or (
                    model.block.scope == "run" and A.T("Current run")
                    or A.ClassName(A.BarClass(model.block))
                )
            local caption = shortScope .. (config.labels and (" · " .. model.label) or "")
            cell.caption:ClearAllPoints()
            cell.caption:SetPoint("TOPLEFT", cell, "TOPLEFT", x, twoLines and -1 or 0)
            cell.caption.fontWidth = width - x - 7
            cell.caption:SetWidth(cell.caption.fontWidth)
            cell.caption:SetHeight(twoLines and 15 or height)
            cell.value:ClearAllPoints()
            cell.value:SetPoint("TOPLEFT", cell, "TOPLEFT", x, twoLines and -17 or 0)
            cell.value.fontWidth = width - x - 7
            cell.value:SetWidth(cell.value.fontWidth)
            cell.value:SetHeight(twoLines and height - 17 or height)
            cell.value.baseSize = config.textSize + (twoLines and 1 or 0)
            barText(cell.caption, caption)
            barText(cell.value, (model.partial and "* " or "") .. model.value)
            if twoLines then
                cell.caption:Show()
            else
                local remaining = width - x - 7
                local captionWidth = math.max(20, remaining * 0.46)
                cell.caption.fontWidth = captionWidth
                cell.caption:SetWidth(captionWidth)
                cell.value.fontWidth = remaining - captionWidth - 3
                cell.value:SetWidth(cell.value.fontWidth)
                cell.value:ClearAllPoints()
                cell.value:SetPoint("TOPLEFT", cell, "TOPLEFT", x + captionWidth + 3, 0)
                cell.value:SetJustifyH("RIGHT")
                cell.caption:Show()
                barText(cell.caption, caption)
                barText(cell.value, (model.partial and "* " or "") .. model.value)
            end
            cell:Show()
        else
            cell:Hide()
        end
    end
end

--- Repaint the live HUD and, when visible, its draft preview without rebuilding widgets.
function A.RefreshBar()
    if not A.bar or not A.db then
        return
    end
    paintBar(A.bar, A.db.settings.hud)
    if editor and editor:IsShown() then
        editor.base:SetAlpha(1)
        editor.grain:SetAlpha(0.16)
        paintBar(editor.preview, editor.draft)
        editor.preview:SetScale(
            math.min(1, 814 / editor.preview.layout.width, 62 / editor.preview.layout.height)
        )
    end
end

--- Build the HUD once and restore only its own persisted anchor.
function A.BuildBar()
    A.bar = barFrame(UIParent, false)
    A.bar:SetFrameStrata("MEDIUM")
    W.place(A.bar, "barPos", "TOP", 0, -38)
end

--- Synchronize editor labels/controls from the draft without recursively changing slider values.
local function refreshEditor()
    local draft = editor.draft
    W.put(editor.title, A.T("My bar"))
    W.put(editor.hint, A.T("Bar scope hint"))
    W.put(editor.appearance, A.T("Appearance"))
    for index, row in ipairs(editor.rows) do
        local block = draft.blocks[index]
        if block then
            W.put(row.metric.label, A.BarLabel(A.BarMetric(block.metric)))
            W.put(row.scope.label, A.BarScope(block))
            W.put(row.remove.label, A.T("Remove"))
            row:Show()
        else
            row:Hide()
        end
    end
    for _, slider in ipairs(editor.sliders) do
        slider.syncing = true
        slider:SetValue(draft[slider.setting])
        slider.syncing = nil
        W.put(slider.caption, A.T(slider.key))
        W.put(
            slider.number,
            slider.setting == "opacity" and (math.floor(draft.opacity * 100) .. "%")
                or tostring(math.floor(draft[slider.setting]))
        )
    end
    for _, check in ipairs(editor.checks) do
        check:SetChecked(draft[check.setting])
        W.put(check.caption, A.T(check.key))
    end
    for _, control in ipairs(editor.translated) do
        W.put(control.label, A.T(control.key))
    end
    W.put(editor.add.label, A.T("Add statistic") .. " (" .. table.getn(draft.blocks) .. "/8)")
    A.RefreshBar()
end

--- Change draft metric only; incompatible current-run scopes revert visibly to all classes.
local function metricMenu(anchor, index)
    local options = {}
    for _, metric in ipairs(A.barMetrics) do
        local id = metric[1]
        table.insert(options, {
            label = A.BarLabel(metric),
            action = function()
                local block = editor.draft.blocks[index]
                block.metric = id
                if block.scope == "run" and not A.BarMetric(id)[5] then
                    block.scope = "all"
                end
                refreshEditor()
            end,
        })
    end
    A.ShowMenu(anchor, options)
end

--- Offer explicit global/current/fixed class scopes; never conflate a mixed bar with one global filter.
local function scopeMenu(anchor, index)
    local options = {}
    local function add(label, scope, class)
        table.insert(options, {
            label = label,
            action = function()
                local block = editor.draft.blocks[index]
                block.scope = scope
                block.class = class
                refreshEditor()
            end,
        })
    end
    add(A.T("All classes"), "all")
    add(A.T("Current class"), "current")
    if A.BarMetric(editor.draft.blocks[index].metric)[5] then
        add(A.T("Current run"), "run")
    end
    for _, class in ipairs({
        "warrior",
        "paladin",
        "hunter",
        "rogue",
        "priest",
        "shaman",
        "mage",
        "warlock",
        "druid",
    }) do
        add(A.ClassName(class), "class", class)
    end
    A.ShowMenu(anchor, options)
end

--- Allocate the draft editor and fixed controls once; all handlers are source-defined closures.
local function buildEditor()
    editor = CreateFrame("Frame", "AzerothStatsBarEditor", A.window)
    A.barEditor = editor
    editor:SetWidth(870)
    editor:SetHeight(650)
    editor:SetFrameStrata("DIALOG")
    editor:SetFrameLevel(A.window:GetFrameLevel() + 10)
    editor:SetPoint("CENTER", A.window, "CENTER", 0, 0)
    editor:EnableMouse(true)
    W.surface(editor, "main")
    editor.title = W.font(editor, 24, 14, 720, 30, 23, A.theme.gold, true)
    editor.hint = W.font(editor, 24, 120, 814, 22, 11, A.theme.muted)
    editor.preview = barFrame(editor, true)
    editor.preview:SetPoint("TOPLEFT", editor, "TOPLEFT", 24, -54)
    local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -6, -5)
    close:SetScript("OnClick", function()
        editor:Hide()
    end)
    editor:SetScript("OnHide", function()
        if A.ui.menu then
            A.ui.menu:Hide()
        end
    end)
    editor.rows = {}
    editor.sliders = {}
    editor.checks = {}
    editor.translated = {}
    for index = 1, 8 do
        local position = index
        local row = CreateFrame("Frame", nil, editor)
        row:SetPoint("TOPLEFT", editor, "TOPLEFT", 24, -150 - (index - 1) * 29)
        row:SetWidth(814)
        row:SetHeight(28)
        row.metric = W.button(row, 0, 0, 255, 27, "", function(anchor)
            metricMenu(anchor, position)
        end)
        row.scope = W.button(row, 265, 0, 300, 27, "", function(anchor)
            scopeMenu(anchor, position)
        end)
        W.dropdown(row.metric)
        W.dropdown(row.scope)
        for direction = -1, 1, 2 do
            local delta = direction
            local arrow = W.button(row, direction == -1 and 576 or 616, 0, 34, 27, "", function()
                local target = position + delta
                if target >= 1 and target <= table.getn(editor.draft.blocks) then
                    local blocks = editor.draft.blocks
                    blocks[position], blocks[target] = blocks[target], blocks[position]
                    refreshEditor()
                end
            end)
            arrow.glyph = arrow:CreateTexture(nil, "ARTWORK")
            arrow.glyph:SetAllPoints(arrow)
            arrow.glyph:SetTexture(
                direction == -1 and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"
                    or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
            )
        end
        row.remove = W.button(row, 662, 0, 152, 27, "", function()
            if table.getn(editor.draft.blocks) > 1 then
                table.remove(editor.draft.blocks, position)
                refreshEditor()
            end
        end)
        editor.rows[index] = row
    end
    editor.add = W.button(editor, 24, 387, 814, 27, "", function(anchor)
        if table.getn(editor.draft.blocks) < 8 then
            table.insert(editor.draft.blocks, { metric = "kills", scope = "all" })
            refreshEditor()
            metricMenu(anchor, table.getn(editor.draft.blocks))
        end
    end)
    editor.appearance = W.font(editor, 24, 425, 814, 24, 17, A.theme.gold, true)
    for index, def in ipairs({
        { "width", "Width", 240, 1600, 10 },
        { "height", "Height", 28, 96, 1 },
        { "textSize", "Font size", 11, 16, 1 },
        { "opacity", "Background opacity", 0.45, 1, 0.05 },
    }) do
        local x, y = 24 + math.mod(index - 1, 3) * 280, index <= 3 and 463 or 529
        local slider = CreateFrame(
            "Slider",
            "AzerothStatsHUDSlider" .. def[1],
            editor,
            "OptionsSliderTemplate"
        )
        slider.setting = def[1]
        slider.key = def[2]
        slider:SetPoint("TOPLEFT", editor, "TOPLEFT", x + 8, -y - 22)
        slider:SetWidth(240)
        slider:SetHeight(18)
        slider:SetMinMaxValues(def[3], def[4])
        slider:SetValueStep(def[5])
        for _, suffix in ipairs({ "Text", "Low", "High" }) do
            local label = getglobal(slider:GetName() .. suffix)
            if label then
                label:Hide()
            end
        end
        slider.caption = W.font(editor, x, y, 200, 20, 12, A.theme.text)
        slider.number = W.font(editor, x + 200, y, 55, 20, 12, A.theme.gold)
        slider.number:SetJustifyH("RIGHT")
        slider:SetScript("OnValueChanged", function()
            if not this.syncing then
                editor.draft[this.setting] = this:GetValue()
                refreshEditor()
            end
        end)
        editor.sliders[index] = slider
    end
    for index, def in ipairs({
        { "icons", "Show icons" },
        { "labels", "Show labels" },
        { "locked", "Lock position" },
    }) do
        local check = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
        local x, y = index == 3 and 584 or 304, index == 2 and 557 or 525
        check.setting = def[1]
        check.key = def[2]
        check:SetPoint("TOPLEFT", editor, "TOPLEFT", x, -y)
        check:SetWidth(24)
        check:SetHeight(24)
        check.caption = W.font(editor, x + 29, y, 230, 24, 12, A.theme.text)
        check:SetScript("OnClick", function()
            editor.draft[this.setting] = not editor.draft[this.setting]
            refreshEditor()
        end)
        editor.checks[index] = check
    end
    for index, preset in ipairs({
        { "compact", "Discreet" },
        { "class", "My class" },
        { "journey", "My journey" },
    }) do
        local id = preset[1]
        local control = W.button(editor, 24 + (index - 1) * 136, 602, 128, 30, preset[2], function()
            editor.draft = A.BarPreset(id)
            refreshEditor()
        end)
        table.insert(editor.translated, control)
    end
    editor.cancel = W.button(editor, 580, 602, 122, 30, "Cancel", function()
        editor:Hide()
    end)
    editor.apply = W.button(editor, 714, 602, 124, 30, "Apply", function()
        A.db.settings.hud = A.NormalizeBar(editor.draft)
        editor:Hide()
        A.RefreshBar()
    end)
    table.insert(editor.translated, editor.cancel)
    table.insert(editor.translated, editor.apply)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "AzerothStatsBarEditor")
    end
end

--- Open a fresh editing transaction; close/cancel never mutates persisted HUD preferences.
function A.OpenBarEditor()
    A.ToggleUI(true)
    if A.ui.menu then
        A.ui.menu:Hide()
    end
    if not editor then
        buildEditor()
    end
    editor.draft = A.NormalizeBar(A.db.settings.hud)
    editor:Show()
    refreshEditor()
end

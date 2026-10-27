local A = AzerothStats
local function check(ok, message)
    assert(ok, message)
    TEST_COUNT = TEST_COUNT + 1
end
local runCount, sequence = A.db.totals.runs, A.db.sequence
local keys = {}
for key in pairs(A.uiText.en) do
    table.insert(keys, key)
end
for _, language in ipairs(A.languages) do
    local lg = language[1]
    if lg ~= "auto" then
        for _, key in ipairs(keys) do
            check(
                type(A.uiText[lg][key]) == "string" and A.uiText[lg][key] ~= "",
                lg .. " : " .. key
            )
        end
        check(A.SetLanguage(lg) and A.Locale() == lg, "manual locale " .. lg)
        for tab = 1, table.getn(A.tabs) do
            A.view.tab = tab
            A.view.page = 1
            A.ToggleUI(true)
            A.RefreshUI()
            check(A.PageModel().title == A.T(A.tabs[tab]), "localized page " .. lg .. tab)
        end
        for _, mode in ipairs({ "damage", "healing", "taken", "boss" }) do
            A.view.tab = 4
            A.view.mode = mode
            A.view.combatTab = "Spells"
            A.RefreshUI()
            check(A.PageModel().subtitle ~= mode, "translated mode " .. lg .. mode)
        end
        for _, section in ipairs({ "Spells", "Equipment", "Attributes", "Timeline" }) do
            A.view.tab = 5
            A.view.characterTab = section
            A.RefreshUI()
            check(A.ui.model ~= nil, "character section " .. lg .. section)
        end
    end
end
check(A.db.totals.runs == runCount and A.db.sequence == sequence, "localization preserves history")
-- Locale inference uses actual localized game terms, even when GetLocale says enUS.
local oldClass, oldLocale = UnitClass, GetLocale
local target = "fr"
GetLocale = function()
    return "enUS"
end
UnitClass = function()
    return A.gameText[target]["class.rogue.name"], "ROGUE"
end
A.localeTip =
    CreateFrame("GameTooltip", "AzerothStatsLocaleTooltip", UIParent, "GameTooltipTemplate")
AzerothStatsLocaleTooltipTextLeft1 = CreateFrame("FontString", "AzerothStatsLocaleTooltipTextLeft1")
A.localeTip.ClearLines = function() end
A.localeTip.SetHyperlink = function(self, link)
    local map = {
        ["enchant:133"] = "fireball",
        ["enchant:116"] = "frostbolt",
        ["enchant:686"] = "shadow_bolt",
    }
    AzerothStatsLocaleTooltipTextLeft1:SetText(
        A.gameText[target]["ability." .. map[link] .. ".name"]
    )
end
for _, lang in ipairs(A.languages) do
    if lang[1] ~= "auto" then
        target = lang[1]
        A.db.settings.language = "auto"
        check(A.DetectLocale() == target, "auto detection " .. target)
    end
end
UnitClass = oldClass
GetLocale = oldLocale
A.SetLanguage("fr")
A.view.tab = 8
A.ToggleUI(true)
local opacity = A.ui.sliders[1]
opacity:SetValue(0.6)
this = opacity
opacity:GetScript("OnValueChanged")()
check(
    A.db.settings.opacity == 0.6 and A.window.base.alpha == 0.6,
    "opacity changes background only"
)
opacity:SetValue(1)
this = opacity
opacity:GetScript("OnValueChanged")()
check(A.window.base.alpha == 1, "opaque background at 100 percent")
for _, control in ipairs(A.ui.checks) do
    local old = A.db.settings[control.setting]
    click(control)
    check(A.db.settings[control.setting] ~= old, "checkbox " .. control.setting)
    click(control)
end
click(A.ui.language)
check(
    A.ui.menu:IsShown() and table.getn(A.ui.menu.items) >= 15,
    "all 14 language choices plus auto"
)
local pt
for _, button in ipairs(A.ui.menu.items) do
    if button.option.locale == "pt" then
        pt = button
    end
end
click(pt)
check(A.Locale() == "pt" and not A.ui.menu:IsShown(), "dropdown applies locale without reload")
SlashCmdList.AZEROTHSTATS("lang fr")
SlashCmdList.AZEROTHSTATS("opacity 0.1")
check(A.db.settings.opacity == 0.45 and A.Locale() == "fr", "opacity bounds and language command")
SlashCmdList.AZEROTHSTATS("opacity 1")
A.view.tab = 4
A.view.combatTab = "Activity"
A.RefreshUI()
local activity = A.PageModel()
check(
    activity.rowY == 191 and table.getn(activity.cards) == 0,
    "activity separated from spell ranking"
)
A.view.combatTab = "Spells"
A.view.mode = "damage"
A.RefreshUI()
check(A.ui.model.capacity >= 1 and A.ui.model.rowY == 301, "combat layout has a dedicated ranking")
A.view.tab = 1
A.RefreshUI()
check(
    table.getn(A.ui.model.cards) == 4 and table.getn(A.ui.model.records) == 3,
    "curated dashboard prioritizes four totals and three records"
)
A.view.tab = 8
A.RefreshUI()
check(A.ui.settings:IsShown(), "real settings controls shown")
A.view.tab = 1
A.RefreshUI()
check(not A.ui.settings:IsShown(), "settings hidden on other pages")
check(
    A.db.totals.runs == runCount and A.db.sequence == sequence,
    "all UX interactions preserve run identities"
)
print("INTERFACE AND LOCALES PASSED", TEST_COUNT)

-- Regression: selected colors survive pointer leave, and current/cumulative scopes are explicit.
A.view.tab = 4
A.view.mode = "damage"
A.view.combatTab = "Spells"
A.RefreshUI()
check(A.ui.nav[4].selected and not A.ui.nav[1].selected, "active sidebar selection")
this = A.ui.nav[4]
this:GetScript("OnLeave")()
check(this.selected, "hover preserves selected state")
click(A.ui.scopeAll)
check(A.ui.scopeAll.selected and not A.ui.scopeRun.selected, "cumulative scope selection")
check(
    string.find(A.ui.breadcrumb.fullText, A.T("All runs"), 1, true) ~= nil,
    "cumulative header names its scope"
)
click(A.ui.modeButtons[5])
check(
    not A.view.cumulative and A.view.combatTab == "Activity",
    "journal always refers to a single run"
)
-- The parent must remain stationary during a scale drag, including a one-second UI refresh.
A.view.tab = 8
A.RefreshUI()
local scale = A.ui.sliders[2]
local original = A.window:GetScale()
this = scale
scale:SetValue(0.8)
scale:GetScript("OnValueChanged")()
check(A.window:GetScale() == original, "native value callback before mouse-down cannot resize")
NOW = NOW + 0.3
this = scale
scale:GetScript("OnUpdate")()
check(A.window:GetScale() == 0.8, "non-drag input commits after settling")
original = A.window:GetScale()
this = scale
scale:GetScript("OnMouseDown")()
scale:SetValue(0.85)
scale:GetScript("OnValueChanged")()
A.RefreshUI()
check(
    A.window:GetScale() == original and scale:GetValue() == 0.85,
    "scale drag does not move its own slider or reset the thumb"
)
this = scale
scale:GetScript("OnMouseUp")()
check(A.window:GetScale() == 0.85 and A.db.settings.scale == 0.85, "scale applied on release")
check(not scale.pending and not scale.dragging, "scale drag state cleared")
-- Simulate synchronous OnValueChanged from SetValue, as the real Slider does.
local methods = getmetatable(scale).__index
local oldSet = methods.SetValue
methods.SetValue = function(self, value)
    oldSet(self, value)
    if self.scripts.OnValueChanged then
        local oldThis = this
        this = self
        self.scripts.OnValueChanged()
        this = oldThis
    end
end
A.RefreshUI()
check(A.db.settings.scale == 0.85, "programmatic slider sync cannot recurse")
methods.SetValue = oldSet
-- Direct historical selection must not change any run totals or identities.
A.view.tab = 4
A.RefreshUI()
click(A.ui.scopeRun)
check(A.ui.menu:IsShown(), "combat run dropdown opens")
local entry = A.ui.menu.items[2]
local chosenId = A.db.runs[table.getn(A.db.runs) - 1].id
click(entry)
check(
    A.view.selected == chosenId and not A.view.cumulative,
    "combat dropdown selects a retained run"
)
local options = {}
local count = 0
for i = 1, 80 do
    local n = i
    table.insert(options, {
        label = tostring(i),
        action = function()
            count = n
        end,
    })
end
A.ShowMenu(A.ui.scopeRun, options)
check(A.ui.menu:GetHeight() <= 372, "large run menu stays bounded")
local last = A.ui.menu.items[13]
click(last)
check(A.ui.menu:IsShown() and A.ui.menu.items[1].option.label ~= "1", "history menu pagination")
click(A.ui.menu.items[2])
check(count == 13, "second history menu page selects correct item")
A.ui.menu:Hide()
A.view.selected = "retired-run"
A.Selected()
check(A.view.selected == nil, "retention clears stale detail selection")
for _, size in ipairs({ 11, 12, 16 }) do
    A.db.settings.textSize = size
    A.ApplyUI()
    for _, tab in ipairs({ 3, 4, 6, 7 }) do
        A.view.tab = tab
        A.RefreshUI()
        check(
            A.ui.model.rowY + A.ui.model.capacity * A.ui.model.rowHeight <= 580,
            "rows remain above footer at text size " .. size
        )
        for _, row in ipairs(A.ui.rows) do
            if row.item and row.item.detail ~= "" then
                check(
                    -row.detail.point[5] >= 23 and row:GetHeight() >= 43,
                    "two-line rows have separate text areas"
                )
            end
        end
    end
end
A.db.settings.textSize = 12
A.ApplyUI()
check(
    A.db.totals.runs == runCount and A.db.sequence == sequence,
    "regressions preserve run identities"
)
print("UX REGRESSIONS PASSED", TEST_COUNT)

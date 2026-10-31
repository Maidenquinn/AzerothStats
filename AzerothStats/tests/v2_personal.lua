-- Notes/goals use synthetic data. These checks never touch player saves.
local A = AzerothStats
local saved = { db = A.db, globals = AzerothStatsDB, run = A.run, view = A.view, locale = A.locale }
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "V2 personal: " .. label)
end
-- Native screen overlay registration never promotes foreign/native roots.
local nativeOverlay, registrations = AZS_SetOnTopOfScreens, {}
AZS_SetOnTopOfScreens = nil
check(not A.RegisterScreenOverlay(A.window), "old clients keep standard strata")
AZS_SetOnTopOfScreens = function(name, enabled)
    registrations[name] = enabled
end
check(A.RegisterScreenOverlay(A.window), "owned main window registered")
check(registrations.AzerothStatsWindow == true, "native API receives exact owned name")
local overlayCalls = 0
local setter = AZS_SetOnTopOfScreens
AZS_SetOnTopOfScreens = function(name, enabled)
    overlayCalls = overlayCalls + 1
    setter(name, enabled)
end
A.window:Hide()
A.SyncScreenOverlays()
check(registrations.AzerothStatsWindow == false, "hidden main root leaves native foreground")
local child = CreateFrame("Frame", "AzerothStatsV2Goal", A.window)
child:Show()
A.RegisterScreenOverlay(child)
check(
    registrations.AzerothStatsV2Goal == false,
    "visible flag with hidden ancestor does not promote"
)
A.window:Show()
A.SyncScreenOverlays()
check(
    registrations.AzerothStatsWindow == true and registrations.AzerothStatsV2Goal == true,
    "visible roots return to native foreground"
)
local callsBefore = overlayCalls
A.SyncScreenOverlays()
check(overlayCalls == callsBefore, "unchanged visibility does not rewrite native registrations")
child:Hide()
A.SyncScreenOverlays()
check(registrations.AzerothStatsV2Goal == false, "closed dialog is unregistered")
check(not A.RegisterScreenOverlay(UIParent), "UIParent never promoted")
check(not A.RegisterScreenOverlay(GameTooltip), "shared tooltip never promoted")
check(
    not A.RegisterScreenOverlay(CreateFrame("Frame", "ForeignSynthetic", UIParent)),
    "foreign frame never promoted"
)
check(not A.RegisterScreenOverlay(CreateFrame("Frame", nil, UIParent)), "anonymous root rejected")
AZS_SetOnTopOfScreens = function()
    error("unsupported client")
end
check(not A.RegisterScreenOverlay(A.window), "native registration failure remains nonfatal")
AZS_SetOnTopOfScreens = setter
registrations.ForeignSynthetic = true
A.window:Show()
A.RegisterScreenOverlay(A.window)
check(
    A.SetScreenOverlayMode("off") and registrations.AzerothStatsWindow == false,
    "overlay off immediately removes own foreground registration"
)
check(registrations.ForeignSynthetic == true, "overlay off preserves other addons")
check(
    A.SetScreenOverlayMode("bar") and registrations.AzerothStatsWindow == false,
    "bar-only diagnostic excludes main window"
)
check(
    A.SetScreenOverlayMode("window") and registrations.AzerothStatsWindow == true,
    "window-only diagnostic includes visible main window"
)
check(not A.SetScreenOverlayMode("invalid"), "unknown overlay mode rejected")
A.SetScreenOverlayMode("on")
AZS_SetOnTopOfScreens = nativeOverlay
AzerothStatsDB = nil
A.InitDB()
A.locale = "en"
local run = {
    id = "azstats-1",
    class = "warrior",
    zone = "elwynn",
    heroic = 3,
    status = "ended",
    result = "victory",
    startedAt = 100,
    values = { duration = 60, kills = 5 },
    accounted = {},
    events = {},
    meters = {},
}
A.db.runs[1], A.run = run, nil
A.view = { tab = 6, page = 1, selected = run.id, v2Goals = true }
local before = A.Sign(run)
local id = A.V2AddGoal(run, 3)
check(
    id and A.V2GoalProgress(A.V2Store(false).preferences.goals[id]) == 1,
    "goal uses retained matching victories"
)
check(not A.V2AddGoal(run, 0) and not A.V2AddGoal(run, 1.5), "invalid goal targets rejected")
-- A custom goal uses explicit scopes, a caller-supplied title and a numeric
-- target; missing values, duplicate retained IDs and live runs never inflate it.
local custom = {
    class = "all",
    zone = "all",
    heroic = "all",
    metric = "kills",
    title = "My first thousand",
    target = 1000,
}
local customId = A.V2CreateGoal(custom)
check(customId and A.V2GoalProgress(custom) == 5, "custom metric and unrestricted scopes")
check(A.V2GoalLabel(custom) == custom.title, "personal title retained")
local known = A.Copy(run)
known.id = "azstats-2"
known.values = { kills = 7, level = 12 }
known.class = "mage"
local missing = A.Copy(run)
missing.id = "azstats-3"
missing.values = {}
local live = A.Copy(run)
live.id = "azstats-4"
live.status = "active"
live.values = { kills = 999 }
table.insert(A.db.runs, known)
table.insert(A.db.runs, missing)
table.insert(A.db.runs, live)
table.insert(A.db.runs, known)
local count, coverage, matching = A.V2GoalProgress(custom)
check(
    count == 12 and coverage == 2 and matching == 3,
    "deduplication, missing coverage and live exclusion"
)
custom.metric = "level"
check(A.V2GoalProgress(custom) == 12, "level objective uses best rather than sum")
custom.metric = "execute"
check(not A.V2CreateGoal(custom), "arbitrary metric rejected")
custom.metric = "kills"
custom.target = 1 / 0
check(not A.V2CreateGoal(custom), "infinite target rejected")
custom.target = 2.5
check(not A.V2CreateGoal(custom), "fractional target rejected")
custom.target = 10
custom.title = string.rep("x", 81)
check(not A.V2CreateGoal(custom), "oversized title rejected")
A.db.runs = { run }
A.V2Store(false).preferences.goals[customId] = nil
A.V2Invalidate()
-- UI starts from the visible filter, never the previously selected run's class.
A.view.class = "mage"
A.V2OpenGoal()
local goalWindow = A.v2GoalWindow
check(
    goalWindow:IsShown() and goalWindow.draft.class == "mage" and goalWindow.draft.zone == "all",
    "custom goal editor reflects visible class"
)
local beforeGoals = A.Sign(A.V2Store(false).preferences.goals)
goalWindow.name:SetText("Cancelled draft")
goalWindow.cancel.callback()
check(
    A.Sign(A.V2Store(false).preferences.goals) == beforeGoals,
    "cancel preserves stored objectives"
)
A.V2OpenGoal()
-- Use the native OnClick chain, not only direct model creation. A reused
-- main-window menu must become a child of this independent higher-level dialog.
local function clickGoal(control)
    local previous = this
    this = control
    control:GetScript("OnClick")()
    this = previous
end
A.ShowMenu(A.ui.classButton, { { label = "Synthetic menu", action = function() end } })
A.ui.menu:Hide()
local mainLevel = A.window:GetFrameLevel()
local baseGoals = A.Sign(A.V2Store(false).preferences.goals)
for _, choice in ipairs({
    { "metric", "gold" },
    { "class", "mage" },
    { "zone", "arena" },
    {
        "heroic",
        3,
    },
}) do
    local key, wanted = choice[1], choice[2]
    clickGoal(goalWindow.fields[key])
    local popup = A.ui.menu
    check(
        popup:IsShown() and popup:GetParent() == goalWindow and popup.owner == goalWindow,
        "goal dropdown belongs to dialog: " .. key
    )
    check(popup:GetFrameLevel() > goalWindow:GetFrameLevel(), "goal dropdown above dialog: " .. key)
    for _, item in ipairs(popup.items) do
        if item:IsShown() then
            check(
                item:GetFrameLevel() > popup:GetFrameLevel(),
                "popup option above surface: " .. key
            )
        end
    end
    local selected
    for _, item in ipairs(popup.items) do
        if item:IsShown() and item.option and item.option.value == wanted then
            selected = item
        end
    end
    check(selected ~= nil, "requested goal choice exists: " .. key)
    clickGoal(selected)
    check(
        goalWindow:IsShown() and goalWindow.draft[key] == wanted and not popup:IsShown(),
        "selection updates draft and leaves dialog open: " .. key
    )
    A.ApplyUI()
    check(
        goalWindow.apply.key == "Add goal" and goalWindow.apply.label.fullText == A.T("Add goal"),
        "goal action remains explicit after a global UI refresh"
    )
    check(A.window:GetFrameLevel() == mainLevel, "goal choice does not promote main window")
    check(
        A.Sign(A.V2Store(false).preferences.goals) == baseGoals,
        "dropdown never saves prematurely"
    )
end
goalWindow.name:SetText("Scoped gold")
goalWindow.target:SetText("123")
goalWindow.apply.callback()
local scopedId
for key, g in pairs(A.V2Store(false).preferences.goals) do
    if g.title == "Scoped gold" then
        scopedId = key
        check(
            g.metric == "gold"
                and g.class == "mage"
                and g.zone == "arena"
                and g.heroic == 3
                and g.target == 123,
            "all four dropdown selections persist in saved objective"
        )
    end
end
check(scopedId and not goalWindow:IsShown(), "selected objective saved and editor closed")
A.V2Store(false).preferences.goals[scopedId] = nil
A.V2Invalidate()
A.V2OpenGoal()
-- Closing the editor closes its owned popup too; stale menus cannot cover the next editor.
clickGoal(goalWindow.fields.metric)
goalWindow.cancel.callback()
goalWindow:GetScript("OnHide")()
check(not A.ui.menu:IsShown(), "closing goal editor closes its dropdown")
check(A.Sign(A.V2Store(false).preferences.goals) == baseGoals, "cancel discards all scope choices")
A.ShowMenu(A.ui.classButton, { { label = "Synthetic main menu", action = function() end } })
check(
    A.ui.menu.owner == A.window and A.ui.menu:GetParent() == A.window,
    "ordinary menu regains main-window owner after goal dialog"
)
check(
    A.ui.menu.items[1]:GetFrameLevel() > A.ui.menu:GetFrameLevel(),
    "reused ordinary option remains above its surface"
)
A.ui.menu:Hide()

A.V2OpenGoal()
goalWindow.name:SetText("Mage victories")
goalWindow.target:SetText("17")
goalWindow.apply.callback()
check(not goalWindow:IsShown(), "custom goal apply succeeds")
local created
for key, g in pairs(A.V2Store(false).preferences.goals) do
    if g.title == "Mage victories" then
        created = key
    end
end
check(created and A.V2Store(false).preferences.goals[created].target == 17, "custom target saved")
A.V2Store(false).preferences.goals[created] = nil
A.V2Invalidate()
A.view.class = nil
check(
    A.NemesisPortrait("Kobold Vermin") ~= A.metricIcons.bosses,
    "native kobold appearance available"
)
check(
    A.NemesisPortrait("Vermine kobold") == A.NemesisPortrait("Kobold Vermin"),
    "French alias resolves exact same creature"
)
check(
    A.NemesisPortrait("Unknown synthetic monster") == A.metricIcons.bosses,
    "unknown name never guesses portrait"
)
check(A.V2SetNote(run.id, "Synthetic note"), "local note stored")
check(not A.V2SetNote(run.id, string.rep("x", 501)), "over-budget note rejected, not truncated")
check(
    A.V2RunData(run).note == "Synthetic note" and A.Sign(run) == before,
    "common V1 ledger untouched"
)
check(not A.V2SetNote("missing", "text"), "deleted run cannot be recreated by note editor")
A.ToggleUI(true)
A.RefreshUI()
check(
    A.ui.v2AddGoal:IsShown() and A.ui.model.rows[1].value == "1 / 3",
    "goal page reachable and explicit"
)
A.editMode = true
A.RefreshUI()
check(
    not A.ui.v2AddGoal:IsShown(),
    "objective creation leaves room for restore actions in edit mode"
)
A.editMode = nil
A.RefreshUI()
A.pendingEntryPlan = A.EntryPlan(A.ui.model.rows[1].entryAction)
check(
    A.ConfirmEntryAction() and not A.V2Store(false).preferences.goals[id],
    "one personal objective reset independently"
)
A.OpenReport(run.id)
A.RefreshUI()
A.ui.reportSections[6].callback(A.ui.reportSections[6])
A.ui.menu.items[5].option.action()
local frame = A.v2NoteWindow
check(
    frame:IsShown() and frame.input:GetText() == "Synthetic note",
    "note editor opens retained run note"
)
check(
    frame:GetParent() == UIParent and frame:GetFrameLevel() > A.window:GetFrameLevel(),
    "note dialog is independent and above main window"
)
frame.input:SetText("Edited note")
check(
    frame.apply:GetFrameLevel() > frame:GetFrameLevel()
        and frame.input:GetFrameLevel() > frame:GetFrameLevel(),
    "native controls stay above the dialog material"
)
frame.apply.callback()
check(not frame:IsShown() and A.V2RunData(run).note == "Edited note", "apply saves note and closes")
-- Rendering every existing route in all five themes preserves legacy access.
for _, theme in ipairs(A.themeOrder) do
    A.UseTheme(theme)
    for _, tab in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
        A.view.tab, A.view.v2Goals = tab, false
        A.RefreshUI()
        check(A.ui.model ~= nil, "render route " .. tab .. " in " .. theme)
    end
end
check(A.ValidateDatabase(A.db), "personal data passes shared database validation")
run.status, A.run, A.view.tab = "active", run, 1
A.view.overviewStats = false
A.RefreshUI()
check(
    A.ui.model.liveHero == run and A.ui.model.rowY == 382,
    "live hero keeps recent rows below the summary cards"
)
local _, _, _, _, y = A.ui.recordPanel:GetPoint()
check(not A.ui.recordPanel:IsShown(), "home insights replace the legacy records strip")
A.db, AzerothStatsDB, A.run, A.view, A.locale =
    saved.db, saved.globals, saved.run, saved.view, saved.locale
A.UseTheme(A.db.settings.theme)
A.RefreshUI()
print("V2 PERSONAL DATA AND ROUTES PASSED", TEST_COUNT)

-- HUD contracts and native editor interactions in the isolated mock client.
local A = AzerothStats
local function check(condition, message)
    assert(condition, message)
    TEST_COUNT = TEST_COUNT + 1
end
local savedDatabase, savedRun, savedView = AzerothStatsDB, A.run, A.view
A.view = A.Copy(savedView)
AzerothStatsDB = nil
A.db = nil
A.run = nil
check(A.InitDB(), "HUD preferences initialize with a new schema-1 database")
A.view.tab = 1
A.view.overviewStats = false
A.RefreshUI()
local photo = A.ui.rows[1].thumbnail
for _, zone in ipairs({
    "ab",
    "aq",
    "arena",
    "av",
    "brm",
    "duskwood",
    "elwynn",
    "feralas",
    "naxx",
    "sm",
    "ungoro",
    "wsg",
}) do
    A.ZoneIllustration(photo, zone)
    check(
        photo.texture == A.theme.media .. "RunZone-" .. zone .. ".tga",
        "recent run selects the exact zone photo: " .. zone
    )
end
A.ZoneIllustration(photo, "naxxramas")
check(
    photo.texture == A.theme.media .. "RunZone-naxx.tga",
    "historical Naxxramas alias keeps the correct photo"
)
A.ZoneIllustration(photo, "unavailable-zone")
check(
    photo.texture == A.theme.media .. "ChroniclePlate4.tga",
    "unknown zones use a neutral placeholder instead of another map"
)
check(
    A.ui.recentEmpty:IsShown(),
    "a fresh dashboard explains missing retained runs instead of leaving a blank panel"
)
check(
    A.window:GetHeight() > A.window:GetWidth() * 0.8,
    "landing window keeps the approved taller proportions"
)
for i = 1, 4 do
    local card = A.ui.cards[i]
    check(table.getn(card.materialParts) == 9, "card uses explicit owned material slices")
    check(card.icon:GetWidth() >= 32, "hero metric icons remain legible")
    for _, texture in ipairs(card.materialParts) do
        check(
            texture:GetWidth() > 0 and texture:GetHeight() > 0,
            "material slices have explicit native dimensions"
        )
    end
end
check(
    A.ui.model.rowY + A.ui.model.rowHeight * 3 <= A.ui.model.plotTop,
    "recent runs fit above the home chart without overlap"
)
local original = A.Sign(A.db.totals)
local defaults = A.db.settings.hud
for _, block in ipairs(defaults.blocks) do
    check(block.scope ~= "run", "no redundant run timer in the default HUD")
end
local normalized = A.NormalizeBar({
    version = 1,
    width = math.huge,
    height = -8,
    textSize = 500,
    icons = false,
    labels = false,
    locked = true,
    blocks = {
        { metric = "runs", scope = "run" },
        { metric = "injected", scope = "all" },
        { metric = "kills", scope = "class", class = "not-a-class" },
        { metric = "kills", scope = "all" },
    },
})
check(
    normalized.width == defaults.width
        and normalized.height == defaults.height
        and normalized.textSize == 16,
    "invalid dimensions normalize and font size is clamped"
)
check(
    normalized.icons == false and normalized.labels == false and normalized.locked,
    "explicit false HUD preferences survive normalization"
)
check(
    table.getn(normalized.blocks) == 1,
    "invalid metric/scope combinations never reach native widgets"
)
check(
    A.NormalizeBar({ version = 77 }).version == 1,
    "unknown settings versions use safe defaults without rewriting counters"
)
local many = A.BarPreset("journey")
many.blocks = {}
for i = 1, 40 do
    table.insert(many.blocks, { metric = "kills", scope = "all" })
end
many = A.NormalizeBar(many)
check(table.getn(many.blocks) == 8, "at most eight configured blocks")
many.width = 240
many.height = 28
local layout = A.BarLayout(many, 640)
check(
    layout.overflow > 0 and layout.capacity + layout.overflow == 8,
    "overflow remains explicitly discoverable"
)
many.width = 1600
many.height = 96
layout = A.BarLayout(many, 1024)
check(layout.width <= 1008 and layout.rows == 2, "screen width limits and two-row HUD layout")
A.db.totals = {
    runs = 7,
    wins = 2,
    sum = { kills = 500, duration = 700 },
    coverage = { kills = 6 },
    records = { level = { value = 29 }, peakDps = { value = 100 } },
}
A.db.classes.warrior = { runs = 2, wins = 1, sum = { kills = 150 } }
local total = { metric = "kills", scope = "all" }
local fixed = { metric = "kills", scope = "class", class = "warrior" }
check(A.BarValue(total) == 500 and A.BarValue(fixed) == 150, "class/global counters stay separate")
check(A.BarValue({ metric = "level", scope = "all" }) == 29, "levels read maxima, never sums")
check(
    A.BarValue({ metric = "peakDps", scope = "all" }) == 100,
    "peak run-average DPS is a record, never an additive rate"
)
local value, partial = A.BarValue(total)
check(value == 500 and partial, "incomplete coverage is retained in the model")
check(
    A.BarValue({ metric = "chests", scope = "all" }) == nil,
    "missing chest summary remains unavailable"
)
A.run = {
    id = "hud-test",
    status = "active",
    values = { kills = 23, duration = 10 },
    class = "mage",
    events = {},
    meters = {},
    timeline = {},
}
check(
    A.BarValue({ metric = "kills", scope = "run" }) == 23,
    "current-run counters use only the live run"
)
A.run.status = "closed"
check(
    A.BarValue({ metric = "kills", scope = "run" }) == nil,
    "a finished run cannot masquerade as the current run"
)
A.run.status = "active"
local bossBlock = { metric = "bosses", scope = "run" }
check(A.BarValue(bossBlock) == nil, "missing live boss count is never invented")
check(
    A.BarBlockModel(bossBlock).value == A.T("At run end"),
    "live summary-only count explains when it becomes available"
)
check(
    A.BarBlockModel(bossBlock).detail
        == A.T("This count is supplied by the final run summary, not live."),
    "boss HUD explains final-summary provenance"
)
A.run.status = "ended"
A.run.summary = { result = "victory", bosses = 2 }
A.run.values.bosses = 2
check(A.BarValue(bossBlock) == 2, "just-finished current run exposes its official boss count")
check(A.BarBlockModel(bossBlock).value == A.Short(2), "final boss count replaces pending label")
A.OpenBarBlock(bossBlock)
check(
    A.view.tab == 4 and A.view.combatTab == "Activity",
    "final HUD count opens the tracked run activity"
)
A.run.values.bosses = 0
check(A.BarBlockModel(bossBlock).value == A.Short(0), "official zero bosses is a real count")
A.run.status = "closed"
check(A.BarValue(bossBlock) == nil, "detached/closed count cannot leak into a current run")
local finishedHudRun = A.run
A.run = { status = "active", values = {} }
check(A.BarValue(bossBlock) == nil, "new run does not inherit previous boss count")
A.run = finishedHudRun
local currentClass = A.BarClass({ scope = "current" })
A.view.class = "warrior"
A.view.selected = "historical"
check(
    A.BarClass({ scope = "current" }) == currentClass,
    "current class is independent of the historical view filter"
)
A.OpenBarBlock(total)
check(
    A.view.class == nil and A.view.cumulative,
    "global HUD navigation clears previous class filters"
)
A.OpenBarBlock(fixed)
check(A.view.class == "warrior", "fixed class HUD navigation preserves its scope")
A.run.status = "active"
A.OpenBarBlock({ metric = "kills", scope = "run" })
check(
    A.view.tab == 4 and A.view.combatTab == "Activity" and not A.view.cumulative,
    "live counters open their run context instead of lifetime totals"
)
A.run.status = "closed"
A.OpenBarBlock({ metric = "kills", scope = "run" })
check(
    A.view.tab == 7,
    "inactive current-run blocks explain availability instead of opening an old run"
)
local aggregate = A.Sign(A.db.totals)
A.OpenBarEditor()
local editor = A.barEditor
check(editor:GetParent() == UIParent, "editor is independent of the main window hierarchy")
local _, initialAnchor = editor:GetPoint()
check(initialAnchor == UIParent, "editor uses its own screen anchor")
local _, _, _, mainX, mainY = A.window:GetPoint()
local starts, stops = 0, 0
local start, stop = editor.StartMoving, editor.StopMovingOrSizing
editor.StartMoving = function()
    starts = starts + 1
end
editor.StopMovingOrSizing = function()
    stops = stops + 1
end
editor:ClearAllPoints()
editor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 160, -70)
local wasLocked = A.db.settings.locked
A.db.settings.locked = true
editor.dragHandle:GetScript("OnDragStart")()
check(starts == 0, "global position lock also protects the editor")
A.db.settings.locked = false
editor.dragHandle:GetScript("OnDragStart")()
editor.dragHandle:GetScript("OnDragStop")()
check(
    starts == 1 and stops == 1,
    "title drag moves the editor rather than its handle or main window"
)
check(
    A.db.settings.barEditorPos[3] == 160 and A.db.settings.barEditorPos[4] == -70,
    "editor position has a separate persisted setting"
)
local _, _, _, unchangedX, unchangedY = A.window:GetPoint()
check(mainX == unchangedX and mainY == unchangedY, "editor drag leaves the main window stationary")
editor.StartMoving, editor.StopMovingOrSizing = start, stop
A.db.settings.locked = wasLocked
editor:Hide()
A.OpenBarEditor()
local _, reopenedAnchor, _, reopenedX = editor:GetPoint()
check(reopenedAnchor == UIParent and reopenedX == 160, "reopening does not recenter a moved editor")
local oldScale = editor:GetScale()
A.widgets.rescale(editor, 0.75, "barEditorPos")
local _, _, _, scaledX, scaledY = editor:GetPoint()
check(
    math.abs(scaledX * 0.75 - 160 * oldScale) < 0.0001
        and math.abs(scaledY * 0.75 + 70 * oldScale) < 0.0001,
    "editor scale changes preserve its physical anchor"
)
A.ApplyUI()
check(
    editor:GetScale() == A.window:GetScale(),
    "independent editor follows the accessible UI scale"
)
local screenWidth = UIParent:GetWidth()
UIParent:SetWidth(1920)
A.db.settings.barEditorPos = { "TOPLEFT", "TOPLEFT", 900, -60 }
A.widgets.place(editor, "barEditorPos", "CENTER", 0, 0, true)
local _, _, _, wideX = editor:GetPoint()
check(wideX == 900, "wide-screen editor positions do not use legacy main-window limits")
UIParent:SetWidth(screenWidth)
A.ResetPosition()
local p, target = editor:GetPoint()
check(
    p == "CENTER" and target == UIParent and A.db.settings.barEditorPos == nil,
    "resetpos also restores the independent editor"
)
A.db.settings.barEditorPos = { "UNTRUSTED", "CENTER", 0, 0 }
A.InitDB()
check(A.db.settings.barEditorPos == nil, "malformed saved editor anchors are rejected")
local stored = A.Sign(A.db.settings.hud)
editor.draft.width = 1230
editor.draft.icons = false
A.RefreshBar()
check(
    A.bar:GetWidth() == A.BarLayout(editor.draft, UIParent:GetWidth()).width,
    "real HUD previews the draft at readable native size"
)
editor.cancel.callback(editor.cancel)
check(A.Sign(A.db.settings.hud) == stored, "Cancel never commits the editor draft")
A.RefreshBar()
check(
    A.bar:GetWidth() == A.BarLayout(A.db.settings.hud, UIParent:GetWidth()).width,
    "Cancel restores the stored HUD layout"
)
A.bar:Hide()
A.OpenBarEditor()
check(A.bar:IsShown(), "hidden HUD is temporarily visible while editing")
A.OpenBarEditor()
editor.cancel.callback(editor.cancel)
-- The mock does not fire native OnHide automatically; exercise that real handler.
editor:GetScript("OnHide")()
check(not A.bar:IsShown(), "reopening an editor does not lose the original hidden HUD state")
check(
    A.Sign(A.db.settings.hud) == stored,
    "temporary visibility never changes stored HUD preferences"
)
A.OpenBarEditor()
check(editor.draft.width == A.db.settings.hud.width, "reopening discards the cancelled draft")
editor.draft.width = 1230
editor.draft.icons = false
editor.apply.callback(editor.apply)
check(
    A.db.settings.hud.width == 1230 and not A.db.settings.hud.icons,
    "Apply commits a validated independent configuration"
)
A.OpenBarEditor()
-- Regression: native menu interaction must promote the editor root, never the main root.
local mainLevel = A.window:GetFrameLevel()
A.window:SetFrameLevel(mainLevel + 200)
editor.draft.width = 947
local draftIdentity = editor.draft
A.OpenBarEditor()
check(
    editor.draft == draftIdentity and editor.draft.width == 947,
    "gear refocus preserves an open unsaved draft"
)
check(
    editor:GetFrameLevel() > A.window:GetFrameLevel(),
    "reopening recalculates level above a promoted main window"
)
check(
    editor.toplevel and not A.window.toplevel,
    "native automatic main promotion is disabled only during editing"
)
editor.rows[1].metric.callback(editor.rows[1].metric)
local menu = A.ui.menu
check(
    menu:GetParent() == editor and menu.owner == editor,
    "HUD metric menu belongs to independent editor"
)
check(menu:GetFrameLevel() > editor:GetFrameLevel(), "dropdown renders above the editor")
local root = menu
while root:GetParent() and root:GetParent() ~= UIParent do
    root = root:GetParent()
end
check(root == editor, "native menu click root is editor rather than main")
local selectedMetric = menu.items[2].option
menu.items[2].callback(menu.items[2])
check(
    editor:IsShown() and editor.draft == draftIdentity,
    "real dropdown callback keeps editor and draft alive"
)
check(not menu:IsShown(), "choosing a metric closes only the popup")
A.OpenBarEditor()
check(editor.draft == draftIdentity, "gear remains a usable recovery path after metric selection")
editor.rows[1].scope.callback(editor.rows[1].scope)
check(menu:GetParent() == editor, "scope dropdown also belongs to editor")
menu.items[1].callback(menu.items[1])
check(editor:IsShown(), "scope selection does not hide the editor")
A.ShowMenu(A.ui.classButton, { { label = "Fixture", action = function() end } })
check(
    menu:GetParent() == A.window and menu:GetFrameLevel() > A.window:GetFrameLevel(),
    "reused popup restores its main-window owner for ordinary menus"
)
menu:Hide()
editor.cancel.callback(editor.cancel)
editor:GetScript("OnHide")()
check(A.window.toplevel, "closing editor restores ordinary main-window promotion")
A.window:SetFrameLevel(mainLevel)
A.OpenBarEditor()
local first = editor.draft.blocks[1].metric
-- Scope menus are populated by native button callbacks, not by a second model-only implementation.
editor.rows[1].scope.callback(editor.rows[1].scope)
check(
    A.ui.menu.items[1].option.label == A.T("All classes"),
    "scope menu exposes its exact global meaning"
)
A.ui.menu.items[2].option.action()
check(editor.draft.blocks[1].scope == "current", "scope selection modifies only the draft")
local count = table.getn(editor.draft.blocks)
local compactHeight = editor:GetHeight()
editor.add.callback(editor.add)
check(
    table.getn(editor.draft.blocks) == count + 1,
    "statistic addition is reachable through real editor controls"
)
check(
    editor:GetHeight() == compactHeight + 29,
    "editor grows by one row instead of reserving blank space"
)
editor.rows[2].remove.callback(editor.rows[2].remove)
check(table.getn(editor.draft.blocks) == count, "removal is reachable through real editor controls")
check(editor:GetHeight() == compactHeight, "removing a block collapses the editor again")
for _, language in ipairs(A.languages) do
    if language[1] ~= "auto" then
        A.SetLanguage(language[1])
        A.OpenBarEditor()
        check(editor.title.fullText == A.T("My bar"), "localized HUD editor " .. language[1])
        for _, block in ipairs(editor.draft.blocks) do
            check(type(A.BarBlockModel(block).scope) == "string", "localized block scope")
        end
    end
end
editor:Hide()
local before = table.getn(objects)
for i = 1, 50 do
    A.RefreshBar()
end
check(table.getn(objects) == before, "HUD sampling reuses widgets instead of leaking frames")
check(A.Sign(A.db.totals) == aggregate, "editor and HUD never alter aggregate counters")
AzerothStatsDB = savedDatabase
A.db = savedDatabase
A.run = savedRun
A.view = savedView
A.RefreshUI()
print("CHRONIQUES HUD AND EDITOR PASSED", TEST_COUNT)

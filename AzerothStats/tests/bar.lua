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
check(
    A.ui.recentEmpty:IsShown(),
    "a fresh dashboard explains missing retained runs instead of leaving a blank panel"
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
local stored = A.Sign(A.db.settings.hud)
editor.draft.width = 1230
editor.draft.icons = false
editor.cancel.callback(editor.cancel)
check(A.Sign(A.db.settings.hud) == stored, "Cancel never commits the editor draft")
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
editor.add.callback(editor.add)
check(
    table.getn(editor.draft.blocks) == count + 1,
    "statistic addition is reachable through real editor controls"
)
editor.rows[2].remove.callback(editor.rows[2].remove)
check(table.getn(editor.draft.blocks) == count, "removal is reachable through real editor controls")
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

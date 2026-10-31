-- Regression scenarios for the native screenshot gaps. Synthetic data only.
local A = AzerothStats
local saved = {
    db = A.db,
    global = AzerothStatsDB,
    run = A.run,
    view = A.view,
    phase = AZS_GetPhase,
    locale = A.locale,
}
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "V2 summary: " .. label)
end
AzerothStatsDB = nil
A.InitDB()
A.locale, A.run = "en", nil
A.view = { tab = 1, page = 1 }
AZS_GetPhase = function()
    return "ready"
end
local before = A.Sign(A.db.totals)
A.RefreshUI()
check(A.ui.model.liveHero.prepared and not A.ui.model.liveHero.id, "ready identity is transient")
check(
    A.ui.v2Hero:IsShown() and not A.ui.v2Hero.open:IsShown(),
    "preparation is visible without an invented report"
)
check(
    table.getn(A.db.runs) == 0 and A.Sign(A.db.totals) == before,
    "showing preparation never accounts a run"
)
check(table.getn(A.ui.model.curve) == 0, "no fabricated chart on empty history")
local run = {
    id = "azstats-1",
    class = "warrior",
    hero = "Synthetic",
    zone = "ab",
    heroic = 3,
    status = "ended",
    result = "victory",
    startedAt = 100,
    values = { duration = 60, level = 4, kills = 5, damage = 100, gold = 20 },
    accounted = {},
    meters = {},
    events = {},
    timeline = { { t = 15, kills = 3 }, { t = 60, kills = 5 } },
}
A.db.runs[1] = run
A.view.selected = nil
A.RefreshUI()
check(
    A.ui.model.curveRun == run and table.getn(A.ui.model.curve) == 2,
    "home chart uses actual retained points"
)
check(
    A.ui.v2SummaryPanels.takeaways:IsShown() and A.ui.v2SummaryPanels.goal:IsShown(),
    "home insights and goal are directly visible"
)
local _, _, _, _, chartY = A.ui.v2Graph:GetPoint()
check(chartY == -540 and A.ui.v2Graph:GetWidth() == 440, "home chart fits its own column")
A.ui.historyLink.callback()
A.RefreshUI()
local _, _, _, classX, classY = A.ui.classButton:GetPoint()
local _, _, _, diffX, diffY = A.ui.difficultyButton:GetPoint()
check(
    classY == diffY and classX + A.ui.classButton:GetWidth() < diffX,
    "history filters share one non-overlapping row"
)
A.OpenReport(run.id)
A.view.reportSection = "Overview"
A.RefreshUI()
check(
    A.ui.v2Graph:IsShown() and A.ui.v2SummaryPanels.context:IsShown(),
    "report embeds chart and context"
)
check(
    A.ui.v2SummaryPanels.moments:IsShown() and A.ui.v2SummaryPanels.note:IsShown(),
    "report embeds highlights and note"
)
check(table.getn(A.ui.model.cards) == 4, "report includes level as its fourth summary metric")
check(
    string.find(A.ui.latest.label.fullText, A.T("Choose run"), 1, true),
    "selector has an explicit action label"
)
this = A.ui.context
A.ui.context:GetScript("OnClick")()
check(A.v2RunPicker:IsShown(), "run banner opens the illustrated run chooser")
A.v2RunPicker:Hide()
A.ui.v2SummaryPanels.note.open.callback(A.ui.v2SummaryPanels.note.open)
check(
    A.v2NoteWindow:IsShown() and A.v2NoteWindow.input.focused,
    "note editor explicitly acquires keyboard focus"
)
check(
    A.v2NoteWindow.input:GetFrameLevel() > A.v2NoteWindow.plate:GetFrameLevel(),
    "native text input sits above themed plate"
)
local noteBefore = A.Sign(run)
A.v2NoteWindow.input:SetText("Actual typed note")
A.v2NoteWindow.apply.callback()
check(
    A.V2RunData(run).note == "Actual typed note" and A.Sign(run) == noteBefore,
    "saving note leaves V1 ledger intact"
)
A.editMode = true
A.RefreshUI()
local curveItem
for _, item in ipairs(A.ui.model.rows) do
    if item.summaryPart == "curve" then
        curveItem = item
    end
end
check(
    curveItem ~= nil and curveItem.editIdentity ~= nil,
    "summary chart can be hidden through edit mode"
)
A.ToggleHiddenRow(curveItem)
A.editMode = false
A.RefreshUI()
check(not A.ui.v2Graph:IsShown(), "hidden report chart stays hidden in summary")
A.editMode = true
A.RefreshUI()
for _, item in ipairs(A.ui.model.rows) do
    if item.summaryPart == "curve" then
        A.ToggleHiddenRow(item)
    end
end
A.editMode = false
A.RefreshUI()
check(A.ui.v2Graph:IsShown(), "summary chart restores without deleting observations")
A.view.tab, A.view.class = 1, "mage"
A.RefreshUI()
check(A.ui.model.curveRun == nil, "home history chart respects selected class")
-- Preserve result and duration separately in the compact recent-run row.
A.view.class = nil
A.RefreshUI()
check(A.ui.rows[1].value.fullText == A.T("Victory"), "home recent row keeps explicit outcome")
check(
    string.find(A.ui.rows[1].detail.fullText, "01:00", 1, true),
    "duration stays visible with outcome"
)
local graph = A.ui.v2Graph
check(
    graph.axisMaxT >= 120 and graph.axisMaxY == 10,
    "short runs have a stable time horizon and rounded value axis"
)
check(
    graph.guideCount > 0 and graph.sampleCount == 2,
    "adjacent real samples have readable stair guides"
)
local signature = A.Sign(run)
local samples = { { t = 15, value = 3 }, { t = 60, value = 5, gap = true } }
A.V2DrawChart(graph, { samples }, 416, 72, 120, 10, "kills")
check(
    graph.guideCount == 0 and graph.sampleCount == 2,
    "gaps leave a visible break instead of a fabricated connection"
)
check(A.Sign(run) == signature, "chart geometry never alters retained observations")
local many = {}
for i = 1, 240 do
    table.insert(many, { t = i, value = i })
end
A.V2DrawChart(graph, { many, many }, 416, 72, 240, 250, "kills")
check(
    graph.guideCount <= 714 and graph.sampleCount == 240,
    "chart frame and texture pools stay bounded"
)
local allocated = table.getn(objects)
A.V2DrawChart(graph, { many, many }, 416, 72, 240, 250, "kills")
check(table.getn(objects) == allocated, "repainting a chart reuses native primitives")
-- Picker paging, literal search, exact ID selection and cancellation.
for i = 2, 14 do
    local copy = A.Copy(run)
    copy.id, copy.hero = "azstats-" .. i, "Player" .. i
    table.insert(A.db.runs, copy)
end
local ledger = A.Sign(A.db.totals)
A.OpenReport(run.id)
A.RunMenu(A.ui.latest)
local picker = A.v2RunPicker
check(
    picker:IsShown() and picker.rows[1].runId == "azstats-14",
    "illustrated chooser is newest first"
)
check(picker.rows[1].label:GetHeight() < 30, "picker title and metadata cannot overlap")
check(
    picker.next:IsShown() and table.getn(picker.rows) == 6,
    "long history uses six readable reusable rows"
)
check(
    picker.close.label.fullText == "x" and picker.close.label:GetWidth() >= 18,
    "close glyph is visible on first dialog open"
)
picker.next.callback()
check(picker.page == 2 and picker.rows[1].runId == "azstats-8", "picker pages retain exact run IDs")
picker.search:SetText("Player13")
this = picker.search
picker.search:GetScript("OnTextChanged")()
check(
    picker.page == 1 and picker.rows[1].runId == "azstats-13" and not picker.rows[2]:IsShown(),
    "search filters metadata and resets paging"
)
picker.rows[1].callback(picker.rows[1])
check(
    A.view.selected == "azstats-13" and not picker:IsShown(),
    "choosing a row selects its exact ID and closes"
)
A.RunMenu(A.ui.latest)
picker.search:SetText("[%")
this = picker.search
picker.search:GetScript("OnTextChanged")()
check(picker.empty:IsShown(), "search uses literal text rather than Lua patterns")
picker.close.callback()
check(
    A.view.selected == "azstats-13" and A.Sign(A.db.totals) == ledger,
    "cancel never redirects selection or writes accounting"
)
-- Explicit ready state wins over a lingering A.run and over a detached saved
-- active observation. Never relabel that historical run with today's zone.
local oldZone, oldReady, oldGate, oldBoundary, oldInventory, oldSpells, oldBuild =
    AZS_ZONE,
    A.inReady,
    A.boundaryGate,
    A.newBoundary,
    A.inventoryBaseline,
    A.spellPacket,
    A.buildBaseline
AZS_ZONE = { zone = "arena", class = "warrior", heroic = "1" }
AZS_GetPhase = function()
    return "ready"
end
local stale = A.Copy(A.db.runs[1])
stale.id = "azstats-999"
stale.zone = nil
stale.heroic = nil
stale.status = "active"
A.run = stale
local ready = A.V2LiveContext()
check(
    ready.prepared and ready.zone == "arena" and ready.heroic == 1 and not ready.id,
    "ready identity beats stale active context before timer"
)
A.run = nil
table.insert(A.db.runs, stale)
A.Sample()
check(
    stale.status == "interrupted" and stale.zone == nil and stale.heroic == nil,
    "ready retires detached active record without rewriting its unknown history"
)
check(A.run == nil, "preparation never starts an accounted run")
AZS_ZONE, A.inReady, A.boundaryGate, A.newBoundary, A.inventoryBaseline, A.spellPacket, A.buildBaseline =
    oldZone, oldReady, oldGate, oldBoundary, oldInventory, oldSpells, oldBuild
A.db, AzerothStatsDB, A.run, A.view, A.locale, AZS_GetPhase =
    saved.db, saved.global, saved.run, saved.view, saved.locale, saved.phase
A.RefreshUI()
print("V2 SUMMARY AND NOTES REGRESSIONS PASSED", TEST_COUNT)

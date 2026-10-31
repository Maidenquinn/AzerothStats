local A = AzerothStats
local old = { db = A.db, globals = AzerothStatsDB, run = A.run, view = A.view, locale = A.locale }
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "V2 views: " .. label)
end
AzerothStatsDB = nil
A.InitDB()
A.locale = "en"
local r = {
    id = "azstats-1",
    hero = "Synthetic",
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
    timeline = { { t = 15, level = 2, kills = 3 }, { t = 60, level = 4, kills = 5 } },
    stats = { hp = 500, ghp = 21, pick = 8.2, gpick = 1.26, cm = 3.15, cd = 0.8 },
}
A.db.runs[1], A.run = r, nil
A.view = { tab = 5, characterTab = "Attributes", page = 1 }
local model = A.PageModel()
check(table.getn(model.rows) == 29, "all attributes including unavailable values")
check(model.rows[1].detail == "Equipment : 21.0", "flat health contribution not multiplied by 100")
check(model.rows[5].value == "315.0%", "critical damage uses total multiplier")
check(
    model.rows[12].value == "8.2 yd" and model.rows[12].detail == "Equipment : 126.0%",
    "pickup units are distinct"
)
check(model.rows[9].value == A.T("Unavailable"), "missing echo is not zero")
check(A.V2AttributeValue(0.8, "cooldown") == "20.0%", "native cooldown formula")
check(table.getn(A.V2Curve(r, "damage")) == 0, "no curve fabricated from final damage")
check(table.getn(A.V2Curve(r, "kills")) == 2, "V1 timeline remains usable")
local identity = model.rows[1].editIdentity
A.ToggleHiddenRow(model.rows[1])
check(table.getn(A.PageModel().rows) == 28, "attribute can be hidden independently")
A.editMode = true
model = A.PageModel()
check(
    model.rows[1].editIdentity == identity and model.rows[1].hidden,
    "hidden row remains restorable in edit mode"
)
A.ToggleHiddenRow(model.rows[1])
A.editMode = nil
check(table.getn(A.PageModel().rows) == 29, "unit visibility restored without data changes")
A.V2Update(r, function(d)
    d.encounters = { { id = 42, name = "Synthetic boss", at = 15, lastAt = 20, closedAt = 21 } }
    d.summons = { Imp = { name = "Imp", firstAt = 10, lastAt = 20, maximum = 2, sampled = true } }
end)
A.OpenReport(r.id)
A.view.reportSection = "Encounters"
model = A.PageModel()
check(model.rows[1].entryAction.key == "42:15", "encounter action uses stable identity")
A.pendingEntryPlan = A.EntryPlan(model.rows[1].entryAction)
check(
    A.pendingEntryPlan.allowed and A.pendingEntryPlan.scope ~= "All classes",
    "review names only the retained run"
)
local before = A.Sign(r)
check(A.ConfirmEntryAction(), "single encounter deletion confirmed")
check(
    table.getn(A.V2RunData(r).encounters) == 0 and A.Sign(r) == before,
    "common combat/run values stay intact"
)
A.view.reportSection = "Summons"
model = A.PageModel()
check(model.columnValue == A.T("Maximum observed"), "presence is labelled a sampled maximum")
r.status = "active"
check(not A.EntryPlan(model.rows[1].entryAction).allowed, "active-run destructive action rejected")
r.status = "ended"
A.OpenReport(r.id)
A.view.reportSection = "Timeline"
A.view.v2CurveMetric = "kills"
A.ToggleUI(true)
A.RefreshUI()
check(
    A.ui.v2Graph:IsShown() and A.ui.v2Graph.points[2]:IsShown(),
    "native measured-point plot is reachable"
)
check(
    not A.ui.nav[2]:IsShown() and A.ui.nav[6]:IsShown(),
    "six navigation entries retain progression access"
)
A.ui.nav[4].callback()
check(A.ui.model.report and A.view.selected == r.id, "analysis navigation retains the selected run")
-- Layout regressions from the native screenshot review: model geometry must
-- reserve the selected-run banner, including when widgets are reused.
A.view = { tab = 5, characterTab = "Attributes", page = 1 }
A.RefreshUI()
model = A.ui.model
check(
    model.rowY > model.bannerTop + model.bannerHeight + 50,
    "attribute rows clear banner and tabs"
)
check(A.ui.rows[1].leftValue:GetWidth() == 180, "gear column has its own width")
check(model.rows[1].gearValue ~= nil, "gear contribution is a separate cell")
A.view.v2AttributeGroup = "advanced"
model = A.PageModel()
check(
    table.getn(model.rows) > 0 and table.getn(model.rows) < 29,
    "advanced filter narrows displayed attributes"
)
check(r.stats.hp == 500, "attribute filtering preserves recorded values")
A.view = { tab = 5, characterTab = "Timeline", page = 1 }
model = A.PageModel()
check(
    model.plotTop >= model.bannerTop + model.bannerHeight + 80,
    "plot clears banner and section controls"
)
A.view = { tab = 3, page = 1 }
A.RefreshUI()
model = A.ui.model
check(table.getn(model.cards) == 0 and model.cohort ~= nil, "history uses compact cohort summary")
check(model.rowHeight == 78 and model.rowY == 280, "history reserves five readable run rows")
for _, button in ipairs(A.ui.historySections) do
    check(not button:IsShown(), "legacy history route strip stays hidden")
end
A.view = { tab = 6, page = 1 }
A.RefreshUI()
for _, button in ipairs(A.ui.v2ProgressTabs) do
    check(button:IsShown(), "progress sections are directly visible")
end
check(not A.ui.v2Options:IsShown(), "optional sampling belongs in settings")
A.view = { tab = 4, cumulative = true, page = 1, meter = "damage" }
model = A.PageModel()
check(
    not model.analysis and model.bannerTop == 199,
    "cumulative mode keeps its independent header layout"
)
A.OpenReport(A.db.runs[1].id)
A.view.reportSection = "Attributes"
A.RefreshUI()
local _, _, _, ax, ay = A.ui.v2AttributeGroup:GetPoint()
local _, _, _, cx, cy = A.ui.reportCompare:GetPoint()
check(
    cy ~= ay or cx >= ax + A.ui.v2AttributeGroup:GetWidth(),
    "attribute filter and compare action do not overlap"
)
check(A.ui.reportCompare:GetWidth() >= 198, "compare action retains a readable label width")

-- The native co-op review exposed rankings drawn through the group summary cards.
A.OpenReport(r.id)
A.view.reportSection, A.view.v2BossSample = "Co-op", nil
model = { report = true, cards = { { label = "Synthetic", value = "1" } }, rows = {} }
A.V2Layout(model, r)
check(model.rowY >= model.cardsTop + 130, "co-op rows clear group summary cards")
local emptyCoop = { rows = {}, cards = {} }
A.CoopReport(emptyCoop, r)
check(
    table.getn(emptyCoop.cards) == 0 and emptyCoop.emptyText == A.T("No group snapshot recorded"),
    "missing native co-op samples render one explicit empty state"
)

A.db, AzerothStatsDB, A.run, A.view, A.locale = old.db, old.globals, old.run, old.view, old.locale
A.RefreshUI()
print("V2 NATIVE VIEW AND EDITING PASSED", TEST_COUNT)

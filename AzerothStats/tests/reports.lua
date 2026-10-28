-- Two-run reports are local views. The tests deliberately exercise unequal coverage.
local A = AzerothStats
local function check(ok, text)
    assert(ok, text)
    TEST_COUNT = TEST_COUNT + 1
end
local database, live, view, pending, clock = AzerothStatsDB, A.run, A.view, A.pendingReport, NOW
AzerothStatsDB, A.db, A.run = nil, nil, nil
A.view = { tab = 3, page = 1, mode = "damage", characterTab = "Spells" }
check(A.InitDB(), "report fixture initializes")
local function run(id, damage, class, heroic)
    return {
        id = id,
        hero = "Fixture",
        class = class or "warrior",
        zone = "feralas",
        heroic = heroic,
        startedAt = 100,
        status = "ended",
        result = "victory",
        summary = { result = "victory" },
        values = { damage = damage, duration = 100, kills = 10, healing = 0 },
        accounted = {},
        events = {},
        meters = { damage = { total = damage, rows = { { name = "Whirlwind", dmg = damage } } } },
        spells = { { key = "whirlwind", rank = 2 } },
        equipment = {},
        equipmentTooltips = {},
    }
end
local a, b = run("report-a", 1000, "warrior", 2), run("report-b", 1500, "warrior", 2)
local c, d = run("report-c", 2000, "mage", 2), run("report-d", 4000, "warrior", nil)
A.db.runs = { a, b, c, d }
A.db.classes.warrior = { records = { damage = { value = 900 }, kills = { value = 99 } } }
A.OpenCompare(a.id)
check(
    A.view.compareB == b.id,
    "default prefers same class, known zone and difficulty over newer mismatches"
)
check(
    A.MatchingContext(a, b) and not A.MatchingContext(a, c) and not A.MatchingContext(a, d),
    "unknown and different contexts are not equivalent"
)
check(
    string.find(A.RunDifference("damage", 1000, 1500), "+50.0%", 1, true),
    "difference percentage uses A baseline"
)
check(
    not string.find(A.RunDifference("damage", 0, 100), "%%"),
    "zero baseline never invents percentage growth"
)
check(
    A.RunDifference("damage", nil, 100) == A.T("Unavailable"),
    "missing sample never becomes zero"
)
local totals = A.Sign(A.db.classes)
A.ToggleUI(true)
A.RefreshUI()
check(
    A.ui.model.comparison and A.ui.rows[1].leftCell:IsShown(),
    "comparison uses paired value cells"
)
A.ui.swapRuns.callback()
check(A.view.compareA == b.id and A.view.compareB == a.id, "swap uses exact stored run IDs")
A.ui.swapRuns.callback()
A.view.compareSection = "Combat"
table.insert(b.meters.damage.rows, { name = "Cleave", dmg = 500 })
A.RefreshUI()
local missing
for _, row in ipairs(A.ui.model.rows) do
    if row.label == A.SourceName("Cleave") then
        missing = row
    end
end
check(
    missing and missing.left == A.T("Unavailable") and missing.value == A.T("Unavailable"),
    "unmatched sources retain missing coverage"
)
a.equipment[1] = "|Hitem:104020|h[Fixture armor]|h"
b.equipment[1] = a.equipment[1]
a.equipmentTooltips[1] = { { text = "Armor" }, { text = "+21 Health" } }
b.equipmentTooltips[1] = { { text = "Armor" }, { text = "+42 Health" } }
A.view.compareSection = "Equipment"
A.RefreshUI()
check(
    A.ui.rows[1].leftCell.item.tooltip[2].text == "+21 Health"
        and A.ui.rows[1].rightCell.item.tooltip[2].text == "+42 Health",
    "each equipment column retains its own historical tooltip"
)
local oldLink = GetInventoryItemLink
local methods = getmetatable(GameTooltip).__index
local oldInventory, calls = methods.SetInventoryItem, 0
GetInventoryItemLink = function()
    return a.equipment[1]
end
methods.SetInventoryItem = function()
    calls = calls + 1
    return true
end
A.run = a
A.ItemTooltip(GameTooltip, A.ui.rows[1].leftCell.item)
check(calls == 0, "ended run does not borrow upgraded current inventory despite identical link")
GetInventoryItemLink, methods.SetInventoryItem = oldLink, oldInventory
A.run = nil
A.BeginReport(a)
A.FinishReport(a)
check(
    a.reportRecords.damage == 1000 and a.reportRecords.kills == nil,
    "summary records compare with pre-run class baseline"
)
local expires = A.pendingReport.expires
A.FinishReport(a)
check(A.pendingReport.expires == expires, "repeated summary never replays the notice")
A.RefreshReportNotice()
check(A.ui.reportToast:IsShown(), "one actionable report notice is visible")
NOW = NOW + 31
A.RefreshReportNotice()
check(
    not A.ui.reportToast:IsShown() and A.pendingReport == nil,
    "report notice expires without opening gameplay overlay"
)
A.OpenReport(a.id)
A.RefreshUI()
check(
    A.ui.model.report and A.ui.latest:IsShown() and A.ui.reportCompare:IsShown(),
    "report has run selector and compare action"
)
check(A.ui.model.cards[3].exact == A.Format(1000), "report keeps selected summary values")
A.view.reportSection = "Records"
A.RefreshUI()
check(table.getn(A.ui.model.rows) > 0 and A.ui.model.note, "summary milestones remain available")
A.OpenReport(b.id)
A.RefreshUI()
check(
    A.ui.model.emptyText == A.T("No record baseline"),
    "older run records are not reconstructed from present lifetime bests"
)
local serialized = SNAPSHOT(a)
local restored = assert(loadstring("return " .. serialized))()
check(
    restored.reportNotified
        and restored.recordBaseline.values.damage == 900
        and restored.reportRecords.damage == 1000,
    "milestones and notice deduplication survive serialization"
)
A.OpenReport("pruned-report")
A.RefreshUI()
check(
    A.ui.model.empty and A.view.selected == "pruned-report",
    "pruned report never silently opens the latest unrelated run"
)
A.OpenCompare(a.id)
A.view.compareB = "pruned-run"
A.RefreshUI()
check(
    A.ui.model.empty and not A.ui.model.compareRuns[2],
    "pruned comparison never silently substitutes another run"
)
A.view.compareB = a.id
A.RefreshUI()
check(A.ui.model.subtitle == A.T("Same run"), "identical selections are explicitly labeled")
A.ToggleFavorite(A.RunFavorite(a))
A.OpenFavorite(A.RunFavorite(a))
check(
    A.view.historySection == "Run report" and A.view.selected == a.id,
    "run favorites navigate to exact report"
)
for _, lang in ipairs(A.languages) do
    if lang[1] ~= "auto" then
        A.SetLanguage(lang[1])
        A.OpenReport(a.id)
        for _, section in ipairs({ "Overview", "Combat", "Character", "Co-op", "Records" }) do
            A.view.reportSection = section
            A.RefreshUI()
            check(
                A.ui.model.rowY + A.ui.model.capacity * A.ui.model.rowHeight <= 700,
                "localized report fits footer"
            )
        end
        A.OpenCompare(a.id)
        for _, section in ipairs({ "Overview", "Combat", "Spells", "Equipment" }) do
            A.view.compareSection = section
            A.RefreshUI()
            check(
                A.ui.model.rowY + A.ui.model.capacity * A.ui.model.rowHeight <= 700,
                "localized comparison fits footer"
            )
        end
    end
end
-- Multiplayer context comes only from saved observations, never absence-as-solo.
check(A.CoopLabel(a) == nil, "legacy run without group evidence has unknown mode")
a.coop = {
    peers = {},
    latest = {},
    accounted = {},
    comparison = {
        rows = {
            { name = "Fixture", class = "warrior", damage = 100, dps = 10, isSelf = true },
            {
                name = "Peer",
                class = "mage",
                damage = 300,
                dps = 30,
                top = "Fireball",
                topdps = 20,
            },
        },
        selfIncluded = true,
        observedTime = 100,
    },
}
local savedCoop = A.Sign(a.coop)
for _, language in ipairs({
    "en",
    "fr",
    "pl",
    "cs",
    "de",
    "pt",
    "es",
    "ro",
    "tr",
    "ru",
    "uk",
    "zh",
    "ja",
    "ko",
}) do
    A.db.settings.language = language
    A.DetectLocale()
    check(
        string.find(A.CoopLabel(a), A.T("Co-op"), 1, true),
        "localized multiplayer evidence badge"
    )
    A.OpenReport(a.id)
    A.view.reportSection = "Co-op"
    A.RefreshUI()
    local m = A.ui.model
    check(
        table.getn(m.cards) == 3 and m.cards[1].value == A.Short(400),
        "common group snapshot supplies total cards"
    )
    check(
        m.rows[1].label == "1. Peer" and m.rows[1].fraction == 0.75,
        "rank and contribution use common packet"
    )
    check(
        string.find(m.rows[1].exact, A.SourceName("Fireball"), 1, true),
        "top spell exposed in peer tooltip"
    )
    check(
        string.find(
            m.rows[1].exact,
            A.T("Other players' healing and kills are unavailable"),
            1,
            true
        ),
        "unsupported peer metrics explicit"
    )
    check(
        string.find(m.banner.detail, A.T("Co-op"), 1, true),
        "report banner identifies multiplayer"
    )
    A.view.historySection = "History"
    A.view.difficulty = nil
    A.view.class = nil
    A.RefreshUI()
    local found
    for _, item in ipairs(A.ui.model.rows) do
        if item.exact and string.find(item.exact, a.id, 1, true) then
            found = string.find(item.label, A.T("Co-op"), 1, true)
        end
    end
    check(found, "history marks co-op runs")
end
check(A.Sign(a.coop) == savedCoop, "presentations never mutate persisted samples")
a.coop.comparison.selfIncluded = false
local partial = { rows = {}, cards = {} }
A.CoopReport(partial, a)
check(
    partial.cards[1].value == A.T("Unavailable") and not partial.rows[1].fraction,
    "independent personal sample suppresses totals and shares"
)
a.coop = { peers = { peer = { name = "Peer", class = "mage" } }, latest = {}, accounted = {} }
check(
    A.CoopLabel(a) == A.T("Co-op") .. " · " .. A.T("Partial"),
    "legacy companion evidence gives partial co-op without invented count"
)
a.coop = nil
local empty = { rows = {}, cards = {} }
A.CoopReport(empty, a)
check(
    table.getn(empty.rows) == 0 and empty.emptyText == A.T("No group snapshot recorded"),
    "missing peers produce explicit empty state"
)
local count = table.getn(objects)
for i = 1, 20 do
    A.RefreshUI()
end
check(table.getn(objects) == count, "reports and comparisons reuse frames")
check(
    A.Sign(A.db.classes) == totals,
    "reports and comparisons never change lifetime class statistics"
)
AzerothStatsDB, A.db, A.run, A.view, A.pendingReport, NOW =
    database, database, live, view, pending, clock
A.DetectLocale()
A.RefreshUI()
print("REPORT AND COMPARISON TESTS PASSED", TEST_COUNT)

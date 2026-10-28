-- Audit regressions: provenance, local navigation, non-destructive controls and accessibility.
local A = AzerothStats
local function check(ok, text)
    assert(ok, text)
    TEST_COUNT = TEST_COUNT + 1
end
local database, live, view, pending, phaseRun, phase =
    A.db, A.run, A.view, A.pendingRetention, A.journalPhaseRun, A.journalPhase
local oldStats, oldSpells, oldStatsPacket, oldWindow, oldClock =
    AZS_STATS, AZS_SPELLS, A.statsPacket, A.journalStatsWindow, NOW
AzerothStatsDB, A.db, A.run = nil, nil, nil
A.view = { tab = 3, page = 1, historySection = "History" }
check(A.InitDB(), "UX fixture initializes")
A.SetLanguage("en")
local function fixture(i)
    return {
        id = "ux-" .. i,
        hero = "Fixture",
        class = "warrior",
        zone = "feralas",
        heroic = 0,
        startedAt = i,
        status = "ended",
        result = "victory",
        values = { duration = 100, damage = 1000, kills = 10 },
        summary = { result = "victory", t = 100 },
        accounted = {},
        events = {},
        meters = {},
        equipment = {},
        spells = {},
    }
end
for i = 1, 16 do
    table.insert(A.db.runs, fixture(i))
end
local run = A.db.runs[16]
check(
    A.RunLabel({ values = {}, class = "unknown" }) ~= nil,
    "run selector tolerates an unknown zone"
)
check(
    A.RunValueSource(run, "duration") == A.T("Official summary"),
    "summary time provenance is per-field"
)
check(
    A.RunValueSource(run, "damage") == A.T("Last sample"),
    "missing summary damage keeps sampled provenance"
)
run.summary.dmg = 900
check(
    A.RunValueSource(run, "damage") == A.T("Last sample"),
    "conflicting summary number cannot label sampled value official"
)
run.summary.dmg = 1000
check(
    A.RunValueSource(run, "damage") == A.T("Official summary"),
    "matching final damage is official"
)
check(
    A.RunValueSource(run, "healing") == A.T("Unavailable"),
    "missing metric provenance stays unavailable"
)
A.view.historySearch = "fixture"
check(A.MatchesHistory(run), "plain text search includes hero")
A.view.historySearch = "[.*"
check(not A.MatchesHistory(run), "search input is literal not a Lua pattern")
A.ClearHistoryFilters()
A.view.historyResult = "defeat"
check(not A.MatchesHistory(run), "result filter excludes victories")
A.ClearHistoryFilters()
A.view.historyKind = "coop"
check(not A.MatchesHistory(run), "unknown party evidence is not coop")
run.coop = {
    peers = { peer = { name = "Peer", class = "mage", damage = 10, dps = 1 } },
    latest = {},
    accounted = {},
}
check(A.MatchesHistory(run), "saved companion evidence admits coop")
A.ClearHistoryFilters()
A.view.historyKind = "favorite"
check(not A.MatchesHistory(run), "favorite filter excludes ordinary run")
A.ToggleFavorite(A.RunFavorite(run))
check(A.MatchesHistory(run), "favorite filter admits bookmarked run")
A.ToggleFavorite(A.RunFavorite(run))
A.ClearHistoryFilters()
local totals = A.Sign(A.db.totals)
A.ToggleFavorite(A.RunFavorite(A.db.runs[1]))
A.run = run
run.status = "active"
check(A.RetentionImpact(10) == 5, "impact excludes protected favorites while preserving live run")
A.ToggleUI(false)
check(not A.RequestRetention(10), "destructive reduction requires explicit confirmation")
check(A.window:IsShown(), "CLI retention confirmation opens an otherwise hidden window")
check(
    table.getn(A.db.runs) == 16 and A.db.settings.maxRuns == 200,
    "opening confirmation changes neither retention nor data"
)
A.ui.retentionDialog.cancel.callback()
check(not A.pendingRetention and table.getn(A.db.runs) == 16, "cancel keeps every run")
A.RequestRetention(10)
table.insert(A.db.runs, fixture(17))
check(
    not A.RequestRetention(10, true) and A.pendingRetention.count == 6,
    "changed impact is shown for reconfirmation"
)
check(A.RequestRetention(10, true), "second confirmation applies displayed impact")
check(
    table.getn(A.db.runs) == 11 and A.FindRun("ux-1") and A.FindRun("ux-16"),
    "confirmed pruning preserves favorite/live and selected ordinary limit"
)
check(A.Sign(A.db.totals) == totals, "pruning keeps cumulative totals")
A.view.selected = run.id
SlashCmdList.AZEROTHSTATS("coop")
check(
    A.view.tab == 3 and A.view.reportSection == "Co-op" and A.view.selected == run.id,
    "coop command opens selected run report"
)
A.OpenReport(run.id)
A.view.reportSection = "Combat"
A.RefreshUI()
A.ui.reportDetails.callback()
check(
    A.view.tab == 4 and A.view.selected == run.id and not A.view.cumulative,
    "report drilldown keeps source run"
)
local independent = { rows = {}, cards = {} }
A.CoopReport(independent, run)
check(independent.columnLabel == A.T("Co-op"), "independent peers never get a ranking heading")
check(A.CompactRate(250000) ~= A.Rate(250000), "large rates have compact presentation")
-- Fresh packet ordering: late stats get a bounded checkpoint window, not continuous logging.
A.BeginJournal(run)
run.phase = "playing"
AZS_SPELLS = { { key = "cleave", rank = 1 } }
AZS_STATS = { area = 1 }
A.statsPacket = nil
A.ObserveJournal(run)
AZS_SPELLS[1].rank = 2
A.ObserveJournal(run)
local checkpointCount = table.getn(run.buildJournal.entries)
NOW = NOW + 1
AZS_STATS.area = 1.3
A.statsPacket = true
A.ObserveJournal(run)
check(
    table.getn(run.buildJournal.entries) == checkpointCount + 1,
    "late fresh stats are captured at the checkpoint"
)
local delayedCount = table.getn(run.buildJournal.entries)
NOW = NOW + 10
AZS_STATS.area = 1.5
A.ObserveJournal(run)
check(
    table.getn(run.buildJournal.entries) == delayedCount,
    "late unrelated stat packets do not flood history"
)
A.statsPacket = nil
local source = A.Sign(run.buildJournal)
A.view.journalKind = "ranks"
local filtered = { rows = {} }
A.JournalModel(filtered, run)
check(table.getn(filtered.rows) == 2, "rank filter excludes stat checkpoints")
check(A.Sign(run.buildJournal) == source, "journal filters never change stored observations")
A.view.journalKind = nil
AZS_STATS, AZS_SPELLS, A.statsPacket, A.journalStatsWindow, NOW =
    oldStats, oldSpells, oldStatsPacket, oldWindow, oldClock
for _, lang in ipairs({
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
    A.SetLanguage(lang)
    for _, size in ipairs({ 11, 16 }) do
        A.db.settings.textSize = size
        A.ClearHistoryFilters()
        A.view.tab = 3
        A.view.historySection = "History"
        A.ToggleUI(true)
        A.ApplyUI()
        A.RefreshUI()
        check(
            A.ui.model.rowY + A.ui.model.capacity * A.ui.model.rowHeight <= 700,
            "filtered history fits footer in every locale/text size"
        )
        check(
            A.ui.rows[1].label.activeSize >= size,
            "body labels respect requested text-size floor"
        )
        check(
            A.ui.historySearch:IsShown() and A.ui.historyResult:IsShown(),
            "history controls visible"
        )
        A.view.tab = 4
        A.RefreshUI()
        check(not A.ui.historyResult:IsShown(), "history filters never overlay combat")
        A.OpenReport(run.id)
        A.view.reportSection = "Overview"
        A.RefreshUI()
        check(
            A.ui.model.cards[3].detail == A.T("Official summary"),
            "localized provenance remains explicit"
        )
        A.view.reportSection = "Build journal"
        A.RefreshUI()
        check(A.ui.journalFilter:IsShown(), "journal filter available in every locale")
    end
end
AzerothStatsDB, A.db, A.run, A.view, A.pendingRetention, A.journalPhaseRun, A.journalPhase =
    database, database, live, view, pending, phaseRun, phase
A.DetectLocale()
A.ApplyUI()
A.RefreshUI()
print("UX COHERENCE REGRESSIONS PASSED", TEST_COUNT)

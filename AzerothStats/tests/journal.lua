-- A sampled journal must never fabricate a native card selection or causal bonus.
local A = AzerothStats
local function check(ok, text)
    assert(ok, text)
    TEST_COUNT = TEST_COUNT + 1
end
local db, live, view, spells, stats, packet, spellPacket, locale =
    A.db, A.run, A.view, AZS_SPELLS, AZS_STATS, A.statsPacket, A.spellPacket, A.Locale()
AzerothStatsDB, A.db, A.run = nil, nil, nil
A.view = {
    tab = 3,
    page = 1,
    mode = "damage",
    historySection = "Run report",
    reportSection = "Build journal",
}
check(A.InitDB(), "journal database initializes")
A.SetLanguage("en")
A.statsPacket, A.spellPacket = nil, nil
local run = {
    id = "journal",
    hero = "Fixture",
    class = "warrior",
    zone = "feralas",
    heroic = 0,
    status = "active",
    phase = "playing",
    values = { duration = 0, level = 1 },
    equipment = {},
    snapshotAt = 0,
    meters = {},
    events = {},
    accounted = {},
}
A.db.runs = { run }
A.view.selected = run.id
A.BeginJournal(run)
AZS_SPELLS = { { key = "cleave", rank = 1, cd = 10, cdmax = 10 } }
AZS_STATS = { area = 1, gold = 1, hp = 100 }
A.ObserveJournal(run)
check(
    table.getn(run.buildJournal.entries) == 2 and run.buildJournal.entries[1].initial,
    "first known state is baseline, never an upgrade"
)
local original = A.Sign(A.db.totals)
run.values.duration = 10
run.values.level = 2
run.phase = "choosing"
AZS_SPELLS[1].rank = 2
AZS_STATS.area = 1.32
AZS_STATS.gold = 1.15
A.ObserveJournal(run)
check(
    table.getn(run.buildJournal.entries) == 4,
    "rank and stats remain separate observations without causal merging"
)
local change
for _, item in ipairs(run.buildJournal.entries[4].changes) do
    if item.key == "area" then
        change = item
    end
end
check(change.before == 1 and change.after == 1.32, "raw global stats preserved before and after")
check(
    string.find(A.JournalChange("stats", change), "+32.00 pp", 1, true),
    "global multiplier delta is labeled percentage points"
)
AZS_SPELLS[1].cd = 3
A.ObserveJournal(run)
check(
    table.getn(run.buildJournal.entries) == 4,
    "cooldown progression never looks like a chosen upgrade"
)
AZS_STATS = {}
A.ObserveJournal(run)
check(table.getn(run.buildJournal.entries) == 4, "missing stats never become a reset to zero")
AZS_STATS = { area = 1.32, gold = 1.15, hp = 100 }
local restored = assert(loadstring("return " .. SNAPSHOT(run)))()
A.ObserveJournal(restored)
check(
    table.getn(restored.buildJournal.entries) == 4,
    "reload duplicate state creates no replayed journal entry"
)
AZS_SPELLS[1].rank = 5
A.ObserveJournal(run)
local batch = run.buildJournal.entries[5]
check(
    table.getn(batch.changes) == 1 and batch.changes[1].before == 2 and batch.changes[1].after == 5,
    "multiple missed rank gains stay one observation, not three invented cards"
)
run.values.duration = 16
run.snapshotAt = 16
run.equipment[13] = "|Hitem:123|h[Accessory II]|h"
A.ObserveJournal(run)
check(
    run.buildJournal.entries[6].kind == "gear",
    "gear uses the existing periodic inventory snapshot"
)
A.RefreshUI()
check(
    A.ui.model.report
        and string.find(A.ui.model.note, A.T("Observed changes, not card effects"), 1, true),
    "journal UI always carries its attribution limit"
)
check(
    A.ui.model.rows[1].exact and A.ui.model.capacity >= 1,
    "journal full changes are available on hover"
)
local late = A.Copy(run)
late.buildJournal = nil
A.ObserveJournal(late)
check(late.buildJournal.partial, "enabling the logger mid-run is explicitly partial")
local gate = A.Copy(run)
A.BeginJournal(gate)
gate.spellsBaseline = A.Sign(A.Copy(AZS_SPELLS))
gate.statsBaseline = A.Sign(A.Copy(AZS_STATS))
A.ObserveJournal(gate)
check(
    table.getn(gate.buildJournal.entries) <= 1 and gate.buildJournal.last.stats == nil,
    "old run baselines gate stale build globals"
)
A.Packet("AZS", "bounded-native-stats-notification")
A.ObserveJournal(gate)
A.statsPacket = nil
check(
    gate.buildJournal.last.stats.area == 1.32,
    "verified AZS stats notification establishes a fresh numeric baseline"
)
local beforeNoise = table.getn(run.buildJournal.entries)
run.phase = "playing"
A.ObserveJournal(run) -- one checkpoint when leaving the choice screen
local beforeIdle = table.getn(run.buildJournal.entries)
for i = 1, 200 do
    AZS_STATS.area = 1 + i / 1000
    A.ObserveJournal(run)
end
check(
    table.getn(run.buildJournal.entries) == beforeIdle,
    "stat-only fluctuations never flood the journal"
)
for i = 1, 200 do
    AZS_SPELLS[1].rank = 100 + i
    AZS_STATS.area = 1 + i / 1000
    A.ObserveJournal(run)
end
check(
    table.getn(run.buildJournal.entries) <= 128 and run.buildJournal.truncated,
    "build observations obey both entry and field budgets"
)
check(A.ValidateJournal(run.buildJournal), "full journal remains valid saved data")
local bad = A.Copy(run.buildJournal)
bad.entries[1].changes[1].after = "not a rank"
check(not A.ValidateJournal(bad), "malformed saved change cannot reach numeric formatting")
bad = A.Copy(run.buildJournal)
bad.last.stats.area = {}
check(not A.ValidateJournal(bad), "malformed last-state dictionary is rejected")
bad = A.Copy(run.buildJournal)
bad.entries.extra = {}
check(not A.ValidateJournal(bad), "non-sequence journal entries cannot bypass bounds")
bad = A.Copy(run.buildJournal)
bad.entries[1].changes.extra = {}
check(not A.ValidateJournal(bad), "non-sequence change arrays cannot bypass bounds")
local invoked = 0
AZS_SPELLS = {
    setmetatable({}, {
        __index = function()
            invoked = invoked + 1
            return 1
        end,
    }),
}
local guarded = A.Copy(run)
A.BeginJournal(guarded)
A.ObserveJournal(guarded)
check(
    invoked == 0 and guarded.buildJournal.partial,
    "metatable-backed native rows are rejected before reading their fields"
)
for _, lang in ipairs(A.languages) do
    if lang[1] ~= "auto" then
        A.SetLanguage(lang[1])
        A.RefreshUI()
        check(
            A.ui.model.rowY + A.ui.model.capacity * A.ui.model.rowHeight <= 700,
            "localized journal fits body"
        )
    end
end
check(A.Sign(A.db.totals) == original, "observation journal never changes lifetime totals")
AzerothStatsDB, A.db, A.run, A.view, AZS_SPELLS, AZS_STATS, A.statsPacket, A.spellPacket =
    db, db, live, view, spells, stats, packet, spellPacket
A.SetLanguage(locale)
A.RefreshUI()
print("BUILD JOURNAL TESTS PASSED", TEST_COUNT)

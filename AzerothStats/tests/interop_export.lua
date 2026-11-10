-- Synthetic privacy, absence and non-mutation regression tests.
local A = AzerothStats
local function check(ok, label)
    assert(ok, "InteropExport: " .. label)
end
local original = {
    id = "azstats-17",
    class = "hunter",
    hero = "PrivateHero",
    zone = "naxx",
    heroic = 3,
    status = "ended",
    result = "victory",
    startedAt = 123456,
    endedAt = 123500,
    partial = false,
    values = { duration = 44, kills = 0, damage = 1234, healing = 0 },
    coop = { latest = { { name = "PrivatePartner" } } },
    equipmentTooltips = { "Private item" },
    events = { { name = "Private event" } },
}
local before = original.values.damage
local result = A.ExportRunV1(original)
check(result and result.schemaVersion == "1.0.0", "schema version")
check(result.run.localId == "azstats-17", "local identity")
check(result.run.nativeRunId == nil, "native identity unverified")
check(result.run.partial == false, "explicit complete coverage preserved")
check(result.run.status == "ended" and result.run.outcome == "victory", "known lifecycle retained")
local unknownLifecycle =
    A.ExportRunV1({ id = "opaque", status = "PrivateStatus", result = "PrivateResult" })
check(
    unknownLifecycle.run.status == nil and unknownLifecycle.run.outcome == nil,
    "unknown lifecycle omitted"
)
check(A.ExportRunV1({ id = "unknown" }).run.partial == nil, "missing coverage remains unknown")
check(
    A.ExportRunV1({ id = "partial", partial = true }).run.partial == true,
    "partial coverage preserved"
)
check(result.metrics.kills.value == 0, "observed zero is retained")
check(result.metrics.healing.value == 0, "healing zero is retained")
check(result.metrics.gold.availability == "unavailable", "missing not zero")
check(result.metrics.damage.value == 1234, "retained metric")
for _, key in ipairs({ "elites", "guardians", "chests", "magnets" }) do
    check(result.metrics[key].availability == "unavailable", "missing aggregate " .. key)
end
check(result.run.hero == nil and result.coop == nil, "private roster omitted")
check(result.events == nil and result.equipmentTooltips == nil, "private detail omitted")
check(result.metrics ~= original.values, "isolated metric table")
result.metrics.damage.value = 9
result.run.zone = "other"
check(original.values.damage == before and original.zone == "naxx", "no internal mutation")
check(A.ExportRunV1({}) == nil, "missing local ID rejected")
check(A.ExportRunV1({ id = "" }) == nil, "empty local ID rejected")
check(A.ExportRunV1(setmetatable({ id = "bad" }, {})) == nil, "metatable rejected")
local bad = A.ExportRunV1({ id = "x", values = { kills = 0 / 0, gold = math.huge }, heroic = 999 })
check(bad.metrics.kills.availability == "unavailable", "NaN rejected")
check(bad.metrics.gold.availability == "unavailable", "infinity rejected")
check(bad.run.heroic == nil, "invalid heroic rejected")
check(
    A.ExportRunV1({ id = "x", values = { damage = -10 } }).metrics.damage.availability
        == "unavailable",
    "negative aggregate rejected"
)

-- Public lookup is explicitly invoked, bounded to retained history, and
-- never creates another SavedVariables root or leaks a database reference.
local previousDb = A.db
A.db = { runs = { original } }
local found = A.ExportRetainedRunV1("azstats-17")
check(found and found.run.localId == "azstats-17", "retained run lookup")
check(found ~= original and found.metrics ~= original.values, "lookup isolated")
check(A.ExportRetainedRunV1("missing") == nil, "missing retained run")
check(A.ExportRetainedRunV1(17) == nil, "non-string lookup rejected")
check(A.ExportRetainedRunV1("azstats-17").run.hero == nil, "lookup omits character name")
A.db.runs[2] = { id = "azstats-17", values = { damage = 999 } }
check(A.ExportRetainedRunV1("azstats-17") == nil, "duplicate local IDs are ambiguous")
A.db.runs[2] = nil
A.db.runs[3] = { id = "azstats-17" }
check(A.ExportRetainedRunV1("azstats-17") == nil, "sparse duplicate local IDs rejected")
A.db.runs[3] = nil
check(A.ExportRetainedRunV1("") == nil, "empty lookup rejected")
check(A.ExportRetainedRunV1(string.rep("x", 81)) == nil, "oversized lookup rejected")
A.db = { runs = setmetatable({ original }, {}) }
check(A.ExportRetainedRunV1("azstats-17") == nil, "metatable run list rejected")
A.db = nil
check(A.ExportRetainedRunV1("azstats-17") == nil, "disabled DB yields no export")
A.db = previousDb

-- Native candidate observation is intentionally separate from historical
-- exports and never creates an identity claim or modifies the input packet.
local previousZone = AZS_ZONE
AZS_ZONE = { run = 42 }
check(A.InteropNativeRunCandidate() == "42", "numeric native run candidate")
AZS_ZONE.run = "session-abc"
check(A.InteropNativeRunCandidate() == "session-abc", "string native run candidate")
AZS_ZONE.run = ""
check(A.InteropNativeRunCandidate() == nil, "empty native run candidate")
AZS_ZONE.run = 0 / 0
check(A.InteropNativeRunCandidate() == nil, "invalid numeric candidate")
AZS_ZONE = setmetatable({ run = "hidden" }, {})
check(A.InteropNativeRunCandidate() == nil, "metatable native packet rejected")
AZS_ZONE = nil
check(A.InteropNativeRunCandidate() == nil, "missing native packet")
AZS_ZONE = previousZone
check(A.ExportRunV1(original).run.nativeRunId == nil, "no retroactive native attribution")

-- AZST1 paste contract: deterministic, bounded, explicit and private.
local code = A.ExportCodeV1(original)
check(type(code) == "string" and string.sub(code, 1, 6) == "AZST1:", "AZST1 prefix")
check(string.find(code, '"v":1', 1, true) ~= nil, "versioned envelope")
check(
    string.find(code, '"kills":{"availability":"available","value":0', 1, true) ~= nil,
    "zero encoded"
)
check(string.find(code, '"gold":{"availability":"unavailable"}', 1, true) ~= nil, "missing encoded")
check(string.find(code, '"nativeRunId":null', 1, true) ~= nil, "unverified native ID null")
check(string.find(code, "PrivateHero", 1, true) == nil, "hero excluded")
check(string.find(code, "PrivatePartner", 1, true) == nil, "roster excluded")
check(string.find(code, "Private item", 1, true) == nil, "equipment excluded")
check(string.find(code, "Private event", 1, true) == nil, "events excluded")
check(A.ExportCodeV1(original) == code, "deterministic code")
local escaped = A.ExportCodeV1({ id = 'quoted"\\id' })
check(escaped and string.find(escaped, '\\"', 1, true), "quote escaped")
check(escaped and string.find(escaped, "\\\\", 1, true), "backslash escaped")
check(A.ExportCodeV1({ id = string.rep("x", 81) }) == nil, "oversized ID rejected")
check(A.ExportCodeV1({}) == nil, "missing ID rejected for code")
A.db = { runs = { original } }
check(A.ExportRetainedCodeV1("azstats-17") == code, "retained code equivalent")
A.db.runs[3] = { id = "azstats-17" }
check(A.ExportRetainedCodeV1("azstats-17") == nil, "ambiguous code rejected")
A.db = previousDb

-- JSON controls must remain escaped and no retained root may be mutated.
local controls = A.ExportCodeV1({ id = "line\nnext\t" .. string.char(1) })
check(controls and string.find(controls, "\\n", 1, true) ~= nil, "newline JSON escaped")
check(controls and string.find(controls, "\\t", 1, true) ~= nil, "tab JSON escaped")
check(controls and string.find(controls, "\\u0001", 1, true) ~= nil, "control JSON escaped")
check(controls and string.find(controls, string.char(1), 1, true) == nil, "no raw control")
local oversized = A.ExportCodeV1({
    id = "azstats-big",
    zone = string.rep("z", 80),
    class = string.rep("c", 40),
    values = { damage = 1e300, healing = 1e300 },
})
check(oversized ~= nil and string.len(oversized) <= 8192, "bounded scalar export")
check(A.ExportCodeV1({ id = "nan", values = { damage = 0 / 0 } }) ~= nil, "invalid metric safe")
local beforeZone = original.zone
local beforeDamage = original.values.damage
A.ExportCodeV1(original)
check(original.zone == beforeZone and original.values.damage == beforeDamage, "export read only")

-- Desktop importer compatibility: exporting must never rewrite existing
-- SavedVariables structures consumed by WoW Logs (Rakesh, 2026-11-09).
local legacyRun = {
    id = "azstats-legacy-1",
    status = "ended",
    result = "victory",
    values = { kills = 12, duration = 180 },
    summary = { result = "victory", t = 180 },
    stats = { crit = 42 },
    equipment = { [1] = "synthetic-item" },
    timeline = { { t = 10, kills = 1 } },
    deaths = { { t = 20, cause = "synthetic" } },
}
local legacyDb = {
    runs = { legacyRun },
    stats = { total = 42 },
    equipment = { slot = "synthetic" },
    timeline = { { t = 1 } },
    deaths = { { t = 2 } },
}
local savedDb, savedManual, savedAuto = A.db, AzerothStatsBackup, AzerothStatsAutoBackup
A.db = legacyDb
local manualMarker, autoMarker = {}, {}
AzerothStatsBackup, AzerothStatsAutoBackup = manualMarker, autoMarker
local legacyCode = A.ExportRetainedCodeV1("azstats-legacy-1")
check(legacyCode ~= nil, "legacy retained run exports")
check(legacyDb.runs[1] == legacyRun, "run identity preserved")
check(legacyRun.summary.result == "victory", "summary preserved")
check(legacyRun.stats.crit == 42, "stats preserved")
check(legacyRun.equipment[1] == "synthetic-item", "equipment preserved")
check(legacyRun.timeline[1].kills == 1, "timeline preserved")
check(legacyRun.deaths[1].cause == "synthetic", "deaths preserved")
check(legacyDb.stats.total == 42, "top-level stats preserved")
check(legacyDb.equipment.slot == "synthetic", "top-level equipment preserved")
check(legacyDb.timeline[1].t == 1, "top-level timeline preserved")
check(legacyDb.deaths[1].t == 2, "top-level deaths preserved")
check(AzerothStatsBackup == manualMarker, "manual backup root untouched")
check(AzerothStatsAutoBackup == autoMarker, "automatic backup root untouched")
check(string.find(legacyCode, "synthetic-item", 1, true) == nil, "equipment not exported")
check(string.find(legacyCode, "synthetic", 1, true) == nil, "private details not exported")
A.db, AzerothStatsBackup, AzerothStatsAutoBackup = savedDb, savedManual, savedAuto

-- Contract matrix for direct SavedVariables readers: synthetic v2.0.2,
-- interrupted, missing, restored and malformed runs. No migration is invoked.
local contractDb = A.db
local cases = {
    { id = "old", summary = { t = 15 }, stats = {}, equipment = {}, timeline = {}, deaths = {} },
    { id = "new", summary = { t = 20 }, stats = {}, equipment = {}, timeline = {}, deaths = {} },
    {
        id = "partial",
        partial = true,
        summary = nil,
        stats = {},
        equipment = {},
        timeline = {},
        deaths = {},
    },
    { id = "missing", values = nil },
    {
        id = "restored",
        summary = { t = 35 },
        stats = {},
        equipment = {},
        timeline = {},
        deaths = {},
    },
    {
        id = "malformed",
        summary = "bad",
        stats = false,
        equipment = 123,
        timeline = {},
        deaths = {},
    },
}
A.db = { runs = cases }
for _, retained in ipairs(cases) do
    local oldSummary, oldStats, oldEquipment = retained.summary, retained.stats, retained.equipment
    local oldTimeline, oldDeaths = retained.timeline, retained.deaths
    local output = A.ExportRetainedCodeV1(retained.id)
    check(type(output) == "string" and string.sub(output, 1, 6) == "AZST1:", "contract export")
    check(
        retained.summary == oldSummary and retained.stats == oldStats,
        "summary and stats unchanged"
    )
    check(retained.equipment == oldEquipment, "equipment unchanged")
    check(
        retained.timeline == oldTimeline and retained.deaths == oldDeaths,
        "timeline and deaths unchanged"
    )
end
check(
    string.find(A.ExportRetainedCodeV1("partial"), '"partial":true', 1, true) ~= nil,
    "partial status"
)
check(
    string.find(
        A.ExportRetainedCodeV1("missing"),
        '"kills":{"availability":"unavailable"}',
        1,
        true
    ) ~= nil,
    "missing metrics"
)
A.db = contractDb

-- Latest-run selector must tolerate sparse arrays and invalid history rows.
local previousSelectionDb = A.db
A.db = {
    runs = {
        [1] = { id = "oldest", startedAt = 100 },
        [4] = { id = "newest", startedAt = 300 },
        [7] = { id = "", startedAt = 999 },
        [9] = false,
        [12] = { id = "middle", startedAt = 200 },
    },
}
check(A.LatestRetainedRunId() == "newest", "latest retained run selection")
A.db.runs[15] = { id = "tie", startedAt = 300 }
check(A.LatestRetainedRunId() == "tie", "latest selection deterministic on timestamp tie")
A.db = { runs = { false, { startedAt = 1 } } }
check(A.LatestRetainedRunId() == nil, "no valid retained run")
A.db = nil
check(A.LatestRetainedRunId() == nil, "selector handles unavailable database")
A.db = previousSelectionDb

-- Bounded 1,000-run synthetic workload. This is a regression smoke test,
-- not a substitute for measured native-client performance.
local perfDb = { runs = {} }
for index = 1, 1000 do
    perfDb.runs[index] = {
        id = "azstats-perf-" .. index,
        status = "ended",
        startedAt = index,
        values = { kills = index, duration = 120, damage = index * 100 },
    }
end
A.db = perfDb
check(A.LatestRetainedRunId() == "azstats-perf-1000", "latest selector handles 1000 runs")
check(A.ExportRetainedRunV1("azstats-perf-1") ~= nil, "first run lookup in 1000")
check(A.ExportRetainedRunV1("azstats-perf-500") ~= nil, "middle run lookup in 1000")
check(A.ExportRetainedRunV1("azstats-perf-1000") ~= nil, "last run lookup in 1000")
local largeCode = A.ExportRetainedCodeV1("azstats-perf-500")
check(largeCode and string.len(largeCode) <= 8192, "1000-run export remains bounded")
check(A.ExportRetainedRunV1("not-present") == nil, "missing run lookup in 1000")
A.db = previousSelectionDb

-- UTF-8 bytes are preserved in JSON strings; byte size is measured on output.
local unicodeCode = A.ExportCodeV1({ id = "azstats-é-雪", zone = "Scholomance-é" })
check(unicodeCode ~= nil, "unicode metadata exports")
check(string.find(unicodeCode, "Scholomance-é", 1, true) ~= nil, "UTF-8 zone preserved")
check(string.len(unicodeCode) <= 8192, "UTF-8 output byte limit")

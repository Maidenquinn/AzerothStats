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
    A.ExportRunV1({ id = "x", values = { damage = -10 } }).metrics.damage.value == -10,
    "negative retained values are not silently rewritten"
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
check(string.find(code, '"kills":{"availability":"available","value":0', 1, true) ~= nil, "zero encoded")
check(string.find(code, '"gold":{"availability":"unavailable"}', 1, true) ~= nil, "missing encoded")
check(string.find(code, '"nativeRunId":null', 1, true) ~= nil, "unverified native ID null")
check(string.find(code, "PrivateHero", 1, true) == nil, "hero excluded")
check(string.find(code, "PrivatePartner", 1, true) == nil, "roster excluded")
check(string.find(code, "Private item", 1, true) == nil, "equipment excluded")
check(string.find(code, "Private event", 1, true) == nil, "events excluded")
check(A.ExportCodeV1(original) == code, "deterministic code")
local escaped = A.ExportCodeV1({ id = 'quoted"\\id' })
check(escaped and string.find(escaped, '\\"', 1, true), "quote escaped")
check(escaped and string.find(escaped, '\\\\', 1, true), "backslash escaped")
check(A.ExportCodeV1({ id = string.rep("x", 81) }) == nil, "oversized ID rejected")
check(A.ExportCodeV1({}) == nil, "missing ID rejected for code")
A.db = { runs = { original } }
check(A.ExportRetainedCodeV1("azstats-17") == code, "retained code equivalent")
A.db.runs[3] = { id = "azstats-17" }
check(A.ExportRetainedCodeV1("azstats-17") == nil, "ambiguous code rejected")
A.db = previousDb

-- Synthetic privacy, absence and non-mutation regression tests.
local A = AzerothStats
local function check(ok, label)
    assert(ok, "InteropExport: " .. label)
end
local original = {
    id = "azstats-17", class = "hunter", hero = "PrivateHero",
    zone = "naxx", heroic = 3, status = "ended", result = "victory",
    startedAt = 123456, endedAt = 123500, partial = false,
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
check(result.metrics.kills.value == 0, "observed zero is retained")
check(result.metrics.healing.value == 0, "healing zero is retained")
check(result.metrics.gold.availability == "unavailable", "missing not zero")
check(result.metrics.damage.value == 1234, "retained metric")
check(result.run.hero == nil and result.coop == nil, "private roster omitted")
check(result.events == nil and result.equipmentTooltips == nil, "private detail omitted")
check(result.metrics ~= original.values, "isolated metric table")
result.metrics.damage.value = 9
result.run.zone = "other"
check(original.values.damage == before and original.zone == "naxx", "no internal mutation")
check(A.ExportRunV1({}) == nil, "missing local ID rejected")
check(A.ExportRunV1(setmetatable({id="bad"}, {})) == nil, "metatable rejected")
local bad = A.ExportRunV1({id="x", values={kills=0/0, gold=math.huge}, heroic=999})
check(bad.metrics.kills.availability == "unavailable", "NaN rejected")
check(bad.metrics.gold.availability == "unavailable", "infinity rejected")
check(bad.run.heroic == nil, "invalid heroic rejected")
check(A.ExportRunV1({id="x", values={damage=-10}}).metrics.damage.value == -10,
    "negative retained values are not silently rewritten")

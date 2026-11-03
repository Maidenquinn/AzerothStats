-- LOT 1: capability isolation, passive defaults and schema compatibility.
local A = AzerothStats
local savedDB, savedRun, savedGlobal = A.db, A.run, AzerothStatsDB
local names = {
    "AZS_GetCombatTextCapabilities",
    "AZS_GetCombatTextEvents",
    "AZS_GetDownedPartyMembers",
    "AZS_GetWorldAnchorCapabilities",
    "AZS_GetWorldAnchors",
    "AZS_GetPlayerPosition",
}
local saved = {}
for _, name in ipairs(names) do
    saved[name] = getglobal(name)
    setglobal(name, nil)
end
local function check(value, description)
    TEST_COUNT = TEST_COUNT + 1
    assert(value, "V2 foundations: " .. description)
end
local empty = A.V2NativeCapabilities()
check(not empty.combat.available and empty.combat.state == "missing", "combat missing")
check(not empty.coop.available and empty.coop.state == "missing", "coop missing")
check(not empty.encounter.available and empty.encounter.state == "missing", "encounter missing")
check(not empty.playerPosition.available, "position missing")
local calls = 0
setglobal("AZS_GetCombatTextCapabilities", function()
    return { apiVersion = 1, maxEventsPerRead = 256 }
end)
setglobal("AZS_GetWorldAnchorCapabilities", function()
    return { apiVersion = 1, maxEntriesPerCall = 256 }
end)
setglobal("AZS_GetCombatTextEvents", function()
    calls = calls + 1
    error("must not subscribe in LOT 1")
end)
setglobal("AZS_GetWorldAnchors", function()
    calls = calls + 1
    error("must not scan in LOT 1")
end)
setglobal("AZS_GetDownedPartyMembers", function()
    calls = calls + 1
    error("must not poll in LOT 1")
end)
setglobal("AZS_GetPlayerPosition", function()
    calls = calls + 1
    error("must not poll in LOT 1")
end)
local caps = A.V2NativeCapabilities()
check(caps.combat.available and caps.coop.available, "independent combat and coop detection")
check(caps.encounter.available and caps.playerPosition.available, "encounter and position detected")
check(calls == 0, "capability probes never invoke collection readers")
setglobal("AZS_GetCombatTextCapabilities", function()
    return nil, "NOT_READY"
end)
check(A.V2NativeCapabilities().combat.state == "notReady", "not ready is nonfatal")
setglobal("AZS_GetCombatTextCapabilities", function()
    return { apiVersion = 2 }
end)
check(A.V2NativeCapabilities().combat.state == "invalid", "unknown API version rejected")
setglobal("AZS_GetCombatTextCapabilities", function()
    error("client capability failure")
end)
check(A.V2NativeCapabilities().combat.state == "error", "native exception isolated")
setglobal("AZS_GetCombatTextCapabilities", nil)
check(A.V2NativeCapabilities().encounter.available, "failure does not disable other features")
A.db, A.run, AzerothStatsDB = nil, nil, nil
local defaults = A.V2FeaturePreferences()
check(
    defaults.combatIntelligence == false
        and defaults.coopIntelligence == true
        and defaults.encounterIntelligence == false
        and defaults.reportDetail == "balanced",
    "new settings default without creating storage"
)
check(AzerothStatsDB == nil, "read-only preferences do not initialize SavedVariables")
check(A.InitDB(), "fresh legacy schema initialized")
local store = A.V2Store(true)
local before = A.Sign(A.db.totals)
local settings = A.V2FeaturePreferences()
check(settings.reportDetail == "balanced", "schema-1 preferences compatible")
check(store.schema == 1 and A.Sign(A.db.totals) == before, "existing ledger unchanged")
store.preferences.combatIntelligence = true
store.preferences.coopIntelligence = false
store.preferences.encounterIntelligence = true
store.preferences.reportDetail = "advanced"
check(
    A.V2FeaturePreferences().combatIntelligence
        and not A.V2FeaturePreferences().coopIntelligence
        and A.V2FeaturePreferences().encounterIntelligence
        and A.V2FeaturePreferences().reportDetail == "advanced",
    "supported overrides resolved"
)
check(A.V2Store(false) == store, "new scalar preferences fit existing schema")
store.schema = 99
check(A.V2Store(false) == nil, "future schema remains inaccessible")
check(A.V2FeaturePreferences().reportDetail == "balanced", "future schema not rewritten")
check(store.schema == 99, "future schema preserved")
A.db, A.run, AzerothStatsDB = savedDB, savedRun, savedGlobal
A.V2Invalidate()
for _, name in ipairs(names) do
    setglobal(name, saved[name])
end
print("V2 LOT 1 FOUNDATIONS PASSED")

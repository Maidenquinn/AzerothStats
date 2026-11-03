-- V2 LOT 1: read-only capability and preference contracts.
-- No events, world catalogs or downed-party lists are polled here.
-- Existing schema-1 SavedVariables stay unchanged until feature lots ship.
local A = AzerothStats

local function exported(name)
    return type(getglobal(name)) == "function"
end

local function probe(name)
    local fn = getglobal(name)
    if type(fn) ~= "function" then
        return "missing"
    end
    local ok, capabilities, reason = pcall(fn)
    if not ok then
        return "error"
    end
    if capabilities == nil then
        if reason == "NOT_READY" or reason == "NOT_IN_WORLD" or reason == "NO_WORLD" then
            return "notReady"
        end
        return "unavailable"
    end
    if
        type(capabilities) ~= "table"
        or getmetatable(capabilities)
        or capabilities.apiVersion ~= 1
    then
        return "invalid"
    end
    return "ready"
end

--- Capability snapshot only on explicit request; never subscribe to an event stream.
--- A missing function on an older client is normal and affects only its feature.
function A.V2NativeCapabilities()
    local combat = probe("AZS_GetCombatTextCapabilities")
    local encounter = probe("AZS_GetWorldAnchorCapabilities")
    local downed = exported("AZS_GetDownedPartyMembers")
    return {
        combat = {
            state = combat,
            available = combat == "ready" and exported("AZS_GetCombatTextEvents"),
        },
        coop = {
            state = downed and "present" or "missing",
            available = downed,
        },
        encounter = {
            state = encounter,
            available = encounter == "ready" and exported("AZS_GetWorldAnchors"),
        },
        playerPosition = {
            state = exported("AZS_GetPlayerPosition") and "present" or "missing",
            available = exported("AZS_GetPlayerPosition"),
        },
    }
end

--- Resolve defaults without creating, migrating or rewriting a saved namespace.
--- Collectors in later lots must also check runtime context before reading natives.
function A.V2FeaturePreferences()
    local store = A.V2Store and A.V2Store(false)
    local prefs = store and store.preferences or {}
    local detail = prefs.reportDetail
    if detail ~= "simple" and detail ~= "balanced" and detail ~= "advanced" then
        detail = "balanced"
    end
    return {
        combatIntelligence = prefs.combatIntelligence == true,
        coopIntelligence = prefs.coopIntelligence ~= false,
        encounterIntelligence = prefs.encounterIntelligence == true,
        reportDetail = detail,
    }
end

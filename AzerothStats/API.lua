-- Read-only adapters over the verified native client API.
-- Function names come from the fixed sources table, never from a received payload.
-- Freshness is heuristic; neither names nor packets are authenticated identities.

local A = AzerothStats
A.sources = {
    damage = { fn = "AZS_GetMeter", raw = "AZS_METER", scope = "partie" },
    healing = { fn = "AZS_GetHealing", raw = "AZS_HEALING", scope = "soins effectifs de la partie" },
    boss = { fn = "AZS_GetBossMeter", raw = "AZS_BOSSMETER", scope = "DERNIER combat de boss" },
    taken = { raw = "AZS_TAKEN", scope = "partie, par source" },
}
-- Copy only flat scalar API fields; nested/callback values never enter run data.

--- Read a bounded flat scalar snapshot; nested tables/functions never enter progress/summary metadata.
function A.ReadFields(value)
    if type(value) ~= "table" or getmetatable(value) then
        return {}
    end
    local result, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 256 then
            A.inputLimited = true
            break
        end
        if type(key) == "string" and string.len(key) <= 80 then
            if type(item) == "number" then
                result[key] = A.Number(item)
            elseif type(item) == "string" then
                result[key] = A.Text(item)
            elseif type(item) == "boolean" then
                result[key] = item
            else
                A.inputLimited = true
            end
        end
    end
    return result
end

--- Match only exact known names across the fourteen game catalogs. No fuzzy map inference.
local function recognizedZone(name)
    name = A.Text(name, 140)
    if not name then
        return nil
    end
    if not A.zoneNames then
        A.zoneNames = {}
        for _, dictionary in pairs(A.gameText) do
            for key, label in pairs(dictionary) do
                local _, _, id = string.find(key, "^zone%.([%w_%-]+)%.name$")
                if id then
                    local folded = string.gsub(label, "[A-Z]", function(c)
                        return string.char(string.byte(c) + 32)
                    end)
                    A.zoneNames[folded] = id
                end
            end
        end
    end
    local folded = string.gsub(name, "[A-Z]", function(c)
        return string.char(string.byte(c) + 32)
    end)
    return A.zoneNames[folded]
end

--- Read client-exported zone labels when a one-shot AZS_ZONE packet was missed on reload.
--- These functions are present in the audited client. A missing function is harmless;
--- unrecognized labels never become a guessed map ID.
local function nativeZone()
    for _, api in ipairs({
        "GetMinimapZoneText",
        "GetSubZoneText",
        "GetRealZoneText",
        "GetZoneText",
    }) do
        local label = A.Text(A.Call(getglobal(api)), 140)
        local id = recognizedZone(label)
        if id then
            return id, label, api
        end
    end
end

--- Resolve sanitized hero/class/map metadata; packet identity remains authoritative.
function A.Identity()
    local _, nativeClass = A.Call(UnitClass, "player")
    local zone = A.ReadFields(AZS_ZONE)
    local class = type(zone.class) == "string" and string.lower(zone.class) or ""
    if not A.knownClasses[class] then
        class = type(nativeClass) == "string" and string.lower(nativeClass) or "unknown"
    end
    if not A.knownClasses[class] then
        class = "unknown"
    end
    local hero = A.Text(A.Call(UnitName, "player"), 80) or "?"
    local id = A.Text(zone.zone, 80)
    if id and not string.find(id, "^[%w_%-]+$") then
        id = nil
    end
    local label, source = A.Text(zone.zname, 140), "AZS_ZONE"
    if not id or id == "unknown" or id == "?" then
        id = recognizedZone(label)
        if not id then
            id, label, source = nativeZone()
        end
    end
    return hero .. ":" .. class .. ":" .. tostring(id or "?"), class, hero, id, label, source
end

--- The 0.121 server's AZSZONE payload explicitly exports heroic (0=Normal, 1..5).
--- Absence never means Normal, and zone.diff is a separate base-zone multiplier.
function A.HeroicLevel(value)
    local level = A.Number(value)
    if level and level <= 5 and level == math.floor(level) then
        return level
    end
end

function A.ReadHeroic()
    return A.HeroicLevel(A.ReadFields(AZS_ZONE).heroic)
end

--- Keep unknown historical difficulty distinct from explicitly observed Normal.
function A.HeroicLabel(run)
    local level = run and A.HeroicLevel(run.heroic)
    if level == nil then
        return A.T("Difficulty unknown")
    end
    return level == 0 and A.T("Normal")
        or (A.T("Heroic") .. " " .. ({ "I", "II", "III", "IV", "V" })[level])
end

--- Only the retained History list is filtered; lifetime ledgers stay unchanged.
function A.MatchesDifficulty(run, filter)
    local level = A.HeroicLevel(run.heroic)
    return filter == nil or (filter == "unknown" and level == nil) or level == filter
end

--- Read server counters and recognize only audited run phases; missing fields stay missing.
function A.ReadProgress()
    local raw = A.ReadFields(AZS_RUN)
    for _, key in ipairs({ "t", "kills", "gold", "lvl", "dealt", "taken", "hp", "hpm", "sh" }) do
        if raw[key] ~= nil then
            raw[key] = A.Number(raw[key])
        end
    end
    local phase = A.Call(AZS_GetPhase) or raw.ph
    raw.ph = A.knownPhases[phase] and phase or nil
    return raw
end
-- Reject conflicting character/map metadata when the client supplies it. Older
-- packets omit these fields: freshness remains heuristic, not authentication.

--- Reject explicitly conflicting character/map metadata; absent legacy metadata stays heuristic.
function A.SummaryMatches(run, summary)
    return summary
        and (summary.hero == nil or summary.hero == run.hero)
        and (summary.zone == nil or not run.zone or summary.zone == run.zone)
end

--- Record native signatures/update stamps at a boundary to exclude counters left over from an old run.
function A.Gate()
    local gate = {}
    for key, src in pairs(A.sources) do
        gate[key] =
            { sig = A.Sign(A.Copy(getglobal(src.raw))), stamp = getglobal(src.raw .. "_UPDATED") }
    end
    gate.summary = A.Sign(A.Copy(AZS_END))
    gate.summaryStamp = AZS_END_UPDATED
    return gate
end
-- Validate row bounds BEFORE calling a native totals helper: those helpers
-- iterate the shared raw table and are not themselves an input validation layer.

--- Validate bounded source rows before calling a native totals helper; return a meter or a reason.
function A.ReadMeter(key, gate)
    local source = A.sources[key]
    if not source then
        return nil, "API absente"
    end
    local raw = getglobal(source.raw)
    local boundary = gate and gate[key]
    if
        boundary
        and boundary.sig == A.Sign(A.Copy(raw))
        and boundary.stamp == getglobal(source.raw .. "_UPDATED")
    then
        return nil, "attente d'un paquet frais"
    end
    if type(raw) ~= "table" then
        return nil, "API absente"
    end
    local count = table.getn(raw)
    if count > A.limits.meterRows or getmetatable(raw) then
        return nil, "paquet invalide"
    end
    if count == 0 and getglobal(source.raw .. "_UPDATED") == nil then
        return nil, "aucun paquet recu"
    end
    local meter =
        { rows = {}, total = 0, scope = source.scope, source = source.raw, sampledAt = A.Wall() }
    for i = 1, count do
        local row = raw[i]
        if type(row) ~= "table" or getmetatable(row) or not A.Number(row.dmg) then
            return nil, "paquet invalide"
        end
        local name = row.name or row.source
        if type(name) ~= "string" or string.len(name) > 500 then
            return nil, "paquet invalide"
        end
        local clean = {
            dmg = A.Number(row.dmg),
            dps = A.Number(row.dps),
            proc = row.proc == 1 and 1 or nil,
        }
        if row.name then
            clean.name = A.Text(row.name)
        end
        if row.source then
            clean.source = A.Text(row.source)
        end
        table.insert(meter.rows, clean)
        meter.total = meter.total + clean.dmg
    end
    if source.fn then
        local _, total, rate = A.Call(getglobal(source.fn))
        -- Totals already come from the validated rows; only a finite native rate is accepted.
        if not total or A.Number(total) then
            meter.rate = A.Number(rate)
        end
    end
    return meter
end

--- Read a recognized final result with scalar metadata; reject malformed supplied identity fields.
function A.ReadSummary()
    local source = A.Call(AZS_GetRunSummary)
    if type(source) ~= "table" then
        source = AZS_END
    end
    if type(source) == "table" then
        for _, key in ipairs({ "hero", "zone", "class", "race" }) do
            if source[key] ~= nil and type(source[key]) ~= "string" then
                A.inputLimited = true
                return nil
            end
        end
    end
    local summary = A.ReadFields(source)
    if summary.result ~= "victory" and summary.result ~= "defeat" and summary.result ~= "left" then
        return nil
    end
    for _, key in ipairs({
        "t",
        "lvl",
        "kills",
        "gold",
        "dmg",
        "taken",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        if summary[key] ~= nil then
            summary[key] = A.Number(summary[key])
        end
    end
    return summary
end

--- Turn structured diagnostic rows into local printable lines; no report is uploaded.
function A.Diagnostics()
    local out = {}
    for _, r in ipairs(A.DiagnosticRows()) do
        table.insert(out, r[1] .. " : " .. tostring(r[2]) .. (r[3] and " · " .. r[3] or ""))
    end
    return out
end

--- Describe API presence, provenance and input-limit warnings without calling missing functions.
function A.DiagnosticRows()
    local out = {
        { A.T("Client"), "Interface 11200 / Lua 5.0" },
        { A.T("Schema"), A.schema .. " / " .. A.version },
        {
            A.T("Locale detection"),
            A.Locale(),
            A.localeSource == "Settings" and A.T("Settings") or A.localeSource or "",
        },
        { A.T("Local storage"), A.T("Saved on normal game exit") },
        { A.T("Interpolation"), A.Rate(A.Call(AZS_GetRunTime)), "AZS_GetRunTime" },
    }
    table.insert(out, {
        "AZS_ZONE.heroic",
        A.HeroicLabel({ heroic = A.ReadHeroic() }),
        "0 = Normal; 1..5 = Heroic; absent = unknown",
    })
    table.insert(out, {
        "0.121: marks / stars",
        A.T("Unavailable"),
        "No verified public structured fields; native gear tooltip text only",
    })
    table.insert(out, {
        "V2 extension",
        A.V2Store(false) and "schema 1" or A.T("No data yet"),
        A.v2Limited and A.T("Partial") or A.v2Unavailable and A.T("Unavailable") or A.T(
            "Local storage"
        ),
    })
    table.insert(out, { "AZS_ZONE.affixes", A.T("Last sample"), "raw IDs; no guessed parsing" })
    local enriched, limit = A.V2Retention()
    table.insert(out, {
        "V2 retention",
        enriched .. " / " .. limit,
        "Advanced observations; protected favorites and local notes are kept",
    })
    if A.run and A.run.buildJournal then
        local journal = A.run.buildJournal
        table.insert(out, {
            "buildJournal.entries",
            A.Format(table.getn(journal.entries)),
            A.T("Observed changes, not card effects") .. (journal.partial and (" · " .. A.T(
                "Partial"
            )) or "") .. (journal.truncated and (" · " .. A.T("Journal limit reached")) or ""),
        })
    end
    local _, _, _, id, label, source = A.Identity()
    table.insert(out, {
        "AZS_ZONE.zone",
        id or A.T("Unknown"),
        (source or "AZS_ZONE") .. " · " .. (label or A.T("Unavailable")),
    })
    if A.run and A.run.zoneSource then
        table.insert(out, { "run.zoneSource", A.run.zoneSource })
    end
    table.insert(out, {
        A.T("Nemesis"),
        A.T("Observed deaths"),
        A.T("Last attacker is not proof of a killing blow"),
    })
    table.insert(
        out,
        { A.T("Co-op"), A.T("Observed names only"), A.T("No shared achievement API") }
    )
    for _, n in ipairs({
        "AZS_GetPartyMeter",
        "AZS_PARTY",
        "PlaySoundFile",
        "AZS_GetPhase",
        "AZS_GetRunTime",
        "AZS_GetMeter",
        "AZS_GetHealing",
        "AZS_GetBossMeter",
        "AZS_GetRunSummary",
        "AZS_RUN",
        "AZS_END",
        "AZS_TAKEN",
        "AZS_STATS",
    }) do
        table.insert(
            out,
            { n, getglobal(n) ~= nil and A.T("Available") or A.T("Missing"), type(getglobal(n)) }
        )
    end
    if A.inputLimited or A.signatureLimited then
        table.insert(
            out,
            { A.T("Quality"), A.T("Partial"), "Input bounds reached; see developer review notes" }
        )
    end
    if A.apiError then
        table.insert(out, { A.T("Last error"), A.apiError })
    end
    if A.run then
        for k, reason in pairs(A.run.unavailable or {}) do
            table.insert(out, { A.ModeName(k), A.Reason(reason) })
        end
    end
    return out
end

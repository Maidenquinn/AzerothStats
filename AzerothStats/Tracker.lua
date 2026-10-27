-- Run lifecycle state machine sampled once per second.
-- ready -> observed run -> terminal -> official result; an increasing endless
-- clock may continue that same run. Without a server UUID, resume stays heuristic.
-- Shared native state is only read; copies and accounting belong to this addon.

local A = AzerothStats
local summaryFields = {
    duration = "t",
    level = "lvl",
    kills = "kills",
    gold = "gold",
    damage = "dmg",
    taken = "taken",
    bosses = "bosses",
    elites = "elites",
    guardians = "guardians",
    chests = "chests",
    magnets = "magnets",
}

--- Accept matching supplied identity fields, retain the first official result and update final exact counters.
local function applySummary(run, summary)
    if not A.SummaryMatches(run, summary) then
        run.summaryRejected = true
        return
    end
    local sig = A.Sign(summary)
    if sig == run.summarySignature then
        return
    end
    run.summarySignature = sig
    run.summary = summary
    run.official = run.official or A.Copy(summary)
    if not run.zone and type(summary.zone) == "string" then
        run.zone = summary.zone
    end
    run.result = summary.result
    run.status = "ended"
    run.endedAt = A.Wall()
    for k, field in pairs(summaryFields) do
        if A.Number(summary[field]) then
            run.values[k] = A.Number(summary[field])
        end
    end
    A.Event(run, "summary", "Resume officiel : " .. summary.result)
end

--- Mark a boundary, account the previous observation and detach it from the live tracker.
local function close(reason)
    local run = A.run
    if run then
        if run.status == "active" then
            run.status = "interrupted"
        end
        run.closeReason = reason
        A.Event(run, "boundary", reason)
        A.Account(run)
    end
    A.run = nil
end

--- Resume only plausible continuity or create one new local run, then freeze counter freshness baselines.
local function start(phase, serverTime)
    local database = A.db
    local key, class, hero, zone, zoneName, zoneSource = A.Identity()
    local old = database.runs[table.getn(database.runs)]
    -- No server run UUID exists. Continuity after a UI reload is explicitly heuristic.
    if
        not A.newBoundary
        and old
        and (old.identity == key or (old.hero == hero and old.class == class and (not zone or not old.zone or zone == old.zone)))
        and serverTime
        and old.lastRawTime
        and serverTime >= old.lastRawTime
        and not old.closeReason
        and phase ~= "ready"
    then
        A.run = old
        old.resumeHeuristic = true
        if zone then
            old.zone, old.zoneName, old.zoneSource, old.identity =
                zone, zoneName or old.zoneName, zoneSource, key
        end
        if not zone then
            old.zoneSource = old.zoneSource or "resumed observation"
        end
        A.Event(old, "resume", "Reprise probable apres rechargement ; pas d'identifiant serveur")
    else
        if old and old.status == "active" then
            old.status = "interrupted"
            old.closeReason = "continuite non prouvee"
        end
        database.sequence = database.sequence + 1
        local run = {
            id = "azstats-" .. tostring(database.sequence),
            identity = key,
            class = class,
            hero = hero,
            zone = zone,
            zoneName = zoneName,
            zoneSource = zone and zoneSource or nil,
            startedAt = A.Wall(),
            status = "active",
            phase = phase,
            values = {},
            accounted = {},
            meters = {},
            unavailable = {},
            events = {},
            timeline = {},
            partial = not serverTime or serverTime > 2,
            gate = A.boundaryGate,
            summaryBaseline = A.Sign(A.Copy(AZS_END)),
            summaryStamp = AZS_END_UPDATED,
            inventoryBaseline = A.inventoryBaseline,
            bootTerminal = not A.newBoundary and (phase == "dead" or phase == "victory"),
        }
        A.run = run
        table.insert(database.runs, run)
        A.Event(
            run,
            "start",
            run.partial and "Partie observee en cours ; couverture partielle" or "Debut observe"
        )
    end
    A.BeginInsights(A.run)
    A.BeginDeathWatch(A.run)
    A.newBoundary = nil
    A.Trim()
end

--- Save bounded build/inventory/timeline details every 15 server seconds, or immediately at a terminal phase.
local function snapshot(run, raw, force)
    if
        not force
        and run.snapshotAt
        and run.values.duration
        and run.values.duration < run.snapshotAt + 15
    then
        return
    end
    run.snapshotAt = run.values.duration or 0
    local point = {
        t = run.values.duration,
        level = run.values.level,
        kills = run.values.kills,
        gold = run.values.gold,
        phase = run.phase,
    }
    table.insert(run.timeline, point)
    if table.getn(run.timeline) > 240 then
        table.remove(run.timeline, 2)
        run.timelineTruncated = true
    end
    local sig = A.Sign(A.Copy(AZS_SPELLS))
    if not run.spellsBaseline or sig ~= run.spellsBaseline then
        run.spells = A.Copy(AZS_SPELLS)
    end
    if not run.statsBaseline or A.Sign(A.Copy(AZS_STATS)) ~= run.statsBaseline then
        run.stats = A.Copy(AZS_STATS)
    end
    run.equipment = {}
    run.equipmentIcons = {}
    run.equipmentTooltips = {}
    for slot = 1, 19 do
        local link
        -- Inventory's API takes two arguments, unlike the simple one-argument reader.
        if type(GetInventoryItemLink) == "function" then
            local ok, value = pcall(GetInventoryItemLink, "player", slot)
            if ok then
                link = value
            else
                link = nil
            end
        end
        if type(link) == "string" then
            run.equipment[slot] = A.PrefixText(link, 500)
            run.equipmentTooltips[slot] = A.CaptureItem(slot)
        end
        if type(GetInventoryItemTexture) == "function" then
            local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
            if ok and type(texture) == "string" then
                run.equipmentIcons[slot] = A.TexturePath(texture)
            end
        end
    end
end

--- Advance the run state machine from one validated native snapshot; missing data is not a fabricated end.
function A.Sample()
    if not A.db then
        return
    end
    local raw = A.ReadProgress()
    local phase = raw.ph
    local serverTime = A.Number(raw.t) -- server sample, never the interpolated helper for records
    local key, class, hero, zone, zoneName, zoneSource = A.Identity()
    if
        A.run
        and class == A.run.class
        and hero == A.run.hero
        and (not zone or not A.run.zone or zone == A.run.zone)
    then
        if zone and phase ~= "ready" then
            A.run.zone = zone
            A.run.zoneName = zoneName or A.run.zoneName
            A.run.zoneSource = zoneSource
            A.run.identity = key
        else
            key = A.run.identity
        end
    end
    local boundary = A.packetReady
        or (
            A.run
            and (
                (serverTime and A.run.lastRawTime and serverTime + 2 < A.run.lastRawTime)
                or (key ~= A.run.identity)
                or (
                    serverTime
                    and A.run.lastRawTime
                    and serverTime < A.run.lastRawTime
                    and A.Number(raw.kills)
                    and A.run.values.kills
                    and raw.kills < A.run.values.kills
                )
            )
        )
    A.packetReady = nil
    if boundary then
        -- End and ready packets can arrive in the same render interval.
        local ending = A.packetSummary and A.ReadSummary()
        if
            A.run
            and ending
            and ending.hero == A.run.hero
            and ending.zone == A.run.zone
            and A.Number(ending.t)
            and ending.t >= (A.run.lastRawTime or 0)
        then
            applySummary(A.run, ending)
        end
        A.packetSummary = nil
        close("nouvelle preparation, identite ou horloge reinitialisee")
        A.boundaryGate = A.Gate()
        A.newBoundary = true
        A.inventoryBaseline = A.InventorySignature()
        A.spellPacket = nil
        A.buildBaseline = { spells = A.Sign(A.Copy(AZS_SPELLS)), stats = A.Sign(A.Copy(AZS_STATS)) }
    end
    if phase == "ready" then
        if not A.inReady then
            close("retour en preparation")
            A.boundaryGate = A.Gate()
            A.newBoundary = true
            A.inventoryBaseline = A.InventorySignature()
            A.spellPacket = nil
            A.buildBaseline =
                { spells = A.Sign(A.Copy(AZS_SPELLS)), stats = A.Sign(A.Copy(AZS_STATS)) }
        end
        A.inReady = true
        A.packetSummary = nil
        A.meterPackets = {}
        return
    end
    A.inReady = nil
    if
        not A.run
        and (
            phase == "playing"
            or phase == "choosing"
            or phase == "paused"
            or phase == "dead"
            or phase == "victory"
            or phase == "endless"
        )
    then
        start(phase, serverTime)
        if A.buildBaseline then
            A.run.spellsBaseline = A.buildBaseline.spells
            A.run.statsBaseline = A.buildBaseline.stats
        end
    end
    local run = A.run
    if not run then
        A.packetSummary = nil
        return
    end
    if phase then
        run.apiMissing = nil
        local terminalSnapshot = (phase == "dead" or phase == "victory") and run.phase ~= phase
        if run.phase ~= phase then
            A.Event(run, "phase", tostring(run.phase) .. " -> " .. tostring(phase))
        end
        local endTime = run.summary and A.Number(run.summary.t) or run.values.duration
        if
            (phase == "playing" or phase == "endless")
            and (run.status == "terminal" or run.status == "ended")
            and serverTime
            and endTime
            and serverTime > endTime
        then
            run.status = "active"
            run.continued = true
            A.Event(run, "continue", "Continuation apres fin officielle")
        end
        run.phase = phase
        run.lastObservedAt = A.Wall()
        if serverTime then
            run.lastRawTime = serverTime
            run.values.duration = serverTime
            run.provenance = run.provenance or {}
            run.provenance.duration = "AZS_RUN.t (echantillon serveur)"
        end
        run.progress = A.Copy(raw)
        for k, field in pairs({
            kills = "kills",
            gold = "gold",
            level = "lvl",
            damage = "dealt",
            taken = "taken",
        }) do
            local n = A.Number(raw[field])
            if n then
                run.values[k] = n
            end
        end
        if A.meterPackets and run.gate then
            for k in pairs(A.meterPackets) do
                run.gate[k] = nil
            end
        end
        for k in pairs(A.sources) do
            local m, reason = A.ReadMeter(k, run.gate)
            if m then
                local old = run.meters[k]
                if k ~= "boss" and old and m.total < old.total then
                    run.unavailable[k] = "compteur en baisse : dernier echantillon conserve"
                    run.meterReset = true
                else
                    run.meters[k] = m
                    run.unavailable[k] = nil
                    -- Raw run counters have priority over sampled spell lists for whole-run totals.
                    if
                        k == "healing"
                        or (k == "damage" and raw.dealt == nil)
                        or (k == "taken" and raw.taken == nil)
                    then
                        run.values[k] = m.total
                    end
                end
            else
                run.unavailable[k] = reason
            end
        end
        local level = run.values.level
        if level and level ~= run.lastLevel then
            A.Event(run, "level", "Niveau " .. A.Format(level))
            run.lastLevel = level
        end
        A.ObserveInsights(run, raw, phase)
        if run.status == "active" then
            A.ObserveBuild(run)
        end
        snapshot(run, raw, terminalSnapshot)
        if (phase == "dead" or phase == "victory") and run.status == "active" then
            run.status = "terminal"
            run.endedAt = A.Wall()
            A.Event(run, "terminal", phase .. " ; attente du resume officiel")
        end
    else
        run.apiMissing = true -- a missing phase is not proof of death or abandonment
    end
    local summary = A.ReadSummary()
    local sig = A.Sign(summary)
    local bootstrap = summary
        and run.bootTerminal
        and serverTime
        and A.Number(summary.t)
        and math.abs(summary.t - serverTime) < 0.1
        and summary.hero == run.hero
        and summary.zone == run.zone
    local fresh = summary
        and (
            A.packetSummary
            or bootstrap
            or (sig ~= run.summaryBaseline and AZS_END_UPDATED ~= run.summaryStamp)
        )
    if fresh and sig ~= run.summarySignature then
        applySummary(run, summary)
    end
    -- A final summary outranks the older AZSRUN packet, including on subsequent polls.
    if run.status == "ended" and run.summary then
        for k, field in pairs(summaryFields) do
            if A.Number(run.summary[field]) then
                run.values[k] = A.Number(run.summary[field])
            end
        end
    end
    A.packetSummary = nil
    A.meterPackets = {}
    A.Account(run)
end
-- A notification records freshness only. The native client owns packet parsing;
-- this addon never evaluates payload text and never sends a reply.

--- Record recognized bounded packet notifications only; no payload evaluation, command dispatch or reply.
function A.Packet(prefix, message)
    local allowed = {
        AZSRUN = true,
        AZSEND = true,
        AZSMETER = true,
        AZSHEAL = true,
        AZSBOSSDMG = true,
        AZSTAKEN = true,
        AZSSPELLS = true,
        AZSPARTY = true,
        AZSZONE = true,
        AZSSTATS = true,
    }
    if not allowed[prefix] then
        return false
    end
    if type(message) ~= "string" or string.len(message) > A.limits.packetBytes then
        A.inputLimited = true
        return false
    end
    if prefix == "AZSRUN" then
        A.runPacketAt = GetTime()
        if string.find(";" .. message .. ";", ";ph=ready;", 1, true) then
            A.packetReady = true
        end
    end
    if prefix == "AZSSPELLS" then
        A.spellPacket = true
    end
    if prefix == "AZSPARTY" then
        A.partyGeneration = (A.partyGeneration or 0) + 1
    end
    if prefix == "AZSEND" then
        A.packetSummary = true
    end
    local meters =
        { AZSMETER = "damage", AZSHEAL = "healing", AZSBOSSDMG = "boss", AZSTAKEN = "taken" }
    if meters[prefix] then
        A.meterPackets = A.meterPackets or {}
        A.meterPackets[meters[prefix]] = true
    end
    return true
end

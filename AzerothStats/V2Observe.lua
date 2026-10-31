-- Passive native observations. Every world-state read requires a new matching
-- client packet. Absence of a packet is not a disappearance, death or zero.
local A = AzerothStats
local prefixes = {
    AZSZONE = true,
    AZSUNITS = true,
    AZSBOSSDMG = true,
    AZSREVIVE = true,
    AZSPETS = true,
    AZSBUFFS = true,
    AZSDEBUFFS = true,
}

function A.V2Packet(prefix)
    if prefixes[prefix] then
        A.v2Packets = A.v2Packets or {}
        A.v2Packets[prefix] = true
    end
end

local function append(list, value, limit, entry)
    table.insert(list, value)
    if table.getn(list) > limit then
        table.remove(list, 1)
        entry.truncated = true
    end
end

local function scalar(value)
    local n = A.Number(value)
    return n and n <= 1000000000000000 and n or nil
end

local function progression(entry, run, t)
    local points = entry.progression or {}
    entry.progression = points
    local last = points[table.getn(points)]
    if last and t < last.t + 15 then
        return
    end
    local point = { t = t, gap = last and t - last.t > 30 or (not last and entry.partial) }
    for _, key in ipairs({ "level", "kills", "gold", "damage", "healing", "taken" }) do
        point[key] = scalar(run.values[key])
        if last and last[key] and point[key] and point[key] < last[key] then
            point.gap = true
        end
    end
    append(points, point, 120, entry)
end

local function encounter(entry, t, packets)
    entry.encounters = entry.encounters or {}
    local list = entry.encounters
    if packets.AZSUNITS and type(AZS_UNITS) == "table" then
        local alive = {}
        for i = 1, math.min(64, table.getn(AZS_UNITS)) do
            local u = AZS_UNITS[i]
            if type(u) == "table" and (u.kind == "boss" or u.kind == "final") then
                local id, name = scalar(u.id), A.Text(u.name, 140)
                if id and name then
                    alive[tostring(id)] = true
                    local found
                    for _, b in ipairs(list) do
                        if b.id == id and not b.closedAt then
                            found = b
                        end
                    end
                    if not found and table.getn(list) < 16 then
                        found = { id = id, name = name, at = t, partial = true }
                        table.insert(list, found)
                    end
                    if found then
                        found.lastAt, found.hp, found.hpm = t, scalar(u.hp), scalar(u.hpm)
                    end
                end
            end
        end
        for _, b in ipairs(list) do
            if not b.closedAt and not alive[tostring(b.id)] then
                b.closedAt = t -- observation ended; never a confirmed kill
            end
        end
    end
    if packets.AZSBOSSDMG then
        -- Several bosses can share this native meter. Store once, not once per boss.
        local meter = A.ReadMeter("boss")
        if meter then
            local rows = {}
            for i = 1, math.min(8, table.getn(meter.rows)) do
                local r = meter.rows[i]
                table.insert(rows, { name = A.Text(r.name, 140), dmg = scalar(r.dmg) })
            end
            entry.bossSamples = entry.bossSamples or {}
            local last = entry.bossSamples[table.getn(entry.bossSamples)]
            local signature = A.Sign(rows)
            if not last or A.Sign(last.rows) ~= signature then
                entry.bossSequence = (entry.bossSequence or 0) + 1
                append(entry.bossSamples, {
                    t = t,
                    rows = rows,
                    total = scalar(meter.total),
                    seq = entry.bossSequence,
                    shared = true,
                }, 12, entry)
            end
        end
    end
end

local function support(entry, t)
    local raw = A.ReadFields(AZS_REVIVE)
    if raw.down ~= 0 and raw.down ~= 1 then
        return
    end
    local state = {
        down = raw.down,
        by = A.Text(raw.by, 80),
        reviving = A.Text(raw.reviving, 80),
        share = scalar(raw.share),
        rshare = scalar(raw.rshare),
    }
    if state.share and state.share > 1 then
        state.share = nil
    end
    if state.rshare and state.rshare > 1 then
        state.rshare = nil
    end
    local old = entry.reviveState
    entry.support = entry.support or {}
    local function event(kind, name, direction)
        entry.supportSequence = (entry.supportSequence or 0) + 1
        append(entry.support, {
            t = t,
            kind = kind,
            name = name,
            direction = direction,
            observed = true,
            seq = entry.supportSequence,
        }, 40, entry)
    end
    if not old then
        event("baseline", state.by)
    else
        if old.down == 0 and state.down == 1 then
            event("down")
        end
        if state.down == 1 and state.by and state.by ~= "" and state.by ~= old.by then
            event("attempt", state.by, "in")
        end
        if
            old.down == 1
            and state.down == 1
            and old.by
            and old.by ~= ""
            and (not state.by or state.by == "" or state.by ~= old.by)
        then
            event("interrupted", old.by)
        end
        if old.down == 1 and state.down == 0 then
            event("returned", old.by) -- return observed; no causal revive claim
        end
        if state.reviving and state.reviving ~= "" and state.reviving ~= old.reviving then
            event("attempt", state.reviving, "out")
        end
        if old.reviving and old.reviving ~= "" and state.reviving ~= old.reviving then
            event("attemptEnded", old.reviving, "out") -- outcome remains unknown
        end
    end
    entry.reviveState = state
end

local function presence(entry, key, raw, t, effects)
    if type(raw) ~= "table" then
        return
    end
    entry[key] = entry[key] or {}
    local grouped, count = {}, 0
    for i = 1, math.min(64, table.getn(raw)) do
        local p = raw[i]
        if type(p) == "table" then
            local name = A.Text(p.name or p.key or tostring(p.spell or ""), 140)
            if name and name ~= "" then
                local id = effects and (tostring(p.id or "player") .. ":" .. name) or name
                grouped[id] = grouped[id] or { name = name, n = 0, target = scalar(p.id) }
                grouped[id].n = effects and math.max(grouped[id].n, scalar(p.stacks) or 1)
                    or grouped[id].n + 1
                count = count + 1
            end
        end
    end
    local n = 0
    for _ in pairs(entry[key]) do
        n = n + 1
    end
    for id, p in pairs(grouped) do
        local old = entry[key][id]
        if entry.removed and entry.removed[key .. ":" .. id] then
            -- A reviewed reset fences this observation for the retained run.
        elseif old or n < 24 then
            if not old then
                old = { name = p.name, firstAt = t, maximum = 0, target = p.target, sampled = true }
                entry[key][id] = old
                n = n + 1
            end
            old.lastAt, old.maximum = t, math.max(old.maximum, p.n)
        else
            entry.truncated = true
        end
    end
    if not effects then
        entry.maxSummons = math.max(entry.maxSummons or 0, count)
    end
end

function A.ObserveV2World(run)
    local packets = A.v2Packets or {}
    A.v2Packets = nil
    if not run or run.status ~= "active" then
        return
    end
    local t = scalar(run.values.duration)
    if not t then
        return
    end
    if not next(packets) then
        if not A.runPacketAt or GetTime() - A.runPacketAt > 2 then
            return
        end
        local store = A.V2Store(false)
        local old = store and store.runs[run.id]
        local points = old and old.progression
        local last = points and points[table.getn(points)]
        if last and t < last.t + 15 then
            return
        end
    end
    A.V2Update(run, function(entry)
        if A.runPacketAt and GetTime() - A.runPacketAt <= 2 then
            progression(entry, run, t)
        end
        if packets.AZSZONE then
            local zone = A.ReadFields(AZS_ZONE)
            if zone.zone == run.zone and zone.class == run.class then
                if type(zone.affixes) == "string" and string.len(zone.affixes) <= 120 then
                    entry.affixesRaw, entry.affixesAt = A.Text(zone.affixes, 120), t
                end
            end
        end
        encounter(entry, t, packets)
        if packets.AZSREVIVE then
            support(entry, t)
        end
        local store = A.V2Store(false)
        local options = store and store.preferences or {}
        if options.summons and packets.AZSPETS then
            presence(entry, "summons", AZS_PETS, t)
        end
        if options.effects then
            if packets.AZSBUFFS then
                presence(entry, "buffs", AZS_BUFFS, t, true)
            end
            if packets.AZSDEBUFFS then
                presence(entry, "debuffs", AZS_DEBUFFS, t, true)
            end
        end
    end)
end

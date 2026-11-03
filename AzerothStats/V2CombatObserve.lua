-- LOT 2: bounded, opt-in combat-event observer. Never modifies the native meter.
local A = AzerothStats
local state =
    { cursor = nil, streamId = nil, runId = nil, summary = nil, lastRun = nil, lastFlush = nil }
local function newSummary()
    return {
        hits = 0,
        misses = 0,
        critical = 0,
        periodic = 0,
        reflected = 0,
        damageObserved = 0,
        dropped = 0,
        invalid = 0,
        gaps = 0,
        batches = 0,
        observed = true,
        partial = true,
        truncated = false,
        sources = {},
        schools = {},
    }
end
local function number(v)
    return type(v) == "number" and v == v and v >= 0 and v < 1000000000000000 and v or nil
end
local function bounded(map, key, amount)
    if type(key) ~= "string" or string.len(key) > 120 or key == "" then
        key = "unknown"
    end
    if map[key] == nil then
        local n = 0
        for _ in pairs(map) do
            n = n + 1
        end
        if n >= 24 then
            return false
        end
        map[key] = { hits = 0, damage = 0 }
    end
    local row = map[key]
    row.hits = row.hits + 1
    row.damage = row.damage + amount
    return true
end
local function read(cursor)
    local fn = getglobal("AZS_GetCombatTextEvents")
    if type(fn) ~= "function" then
        return nil, "missing"
    end
    local ok, batch, err = pcall(fn, cursor, 256)
    if not ok then
        return nil, "exception"
    end
    if not batch then
        return nil, type(err) == "table" and err.code or "unavailable"
    end
    if type(batch) ~= "table" or batch.apiVersion ~= 1 or type(batch.cursor) ~= "string" then
        return nil, "invalid"
    end
    return batch
end
local function enabled(run)
    return run
        and run.status == "active"
        and A.V2FeaturePreferences
        and A.V2FeaturePreferences().combatIntelligence
end
local function flush()
    if state.summary and state.lastRun and A.V2Update then
        local snapshot = A.Copy(state.summary)
        A.V2Update(state.lastRun, function(entry)
            entry.combatIntelligence = snapshot
        end)
    end
end
function A.V2CombatReset()
    state.cursor, state.streamId, state.runId, state.summary = nil, nil, nil, nil
    state.lastRun, state.lastFlush = nil, nil
end
function A.V2CombatSnapshot()
    return state.summary
end
function A.V2CombatTick(run)
    if not enabled(run) then
        flush()
        A.V2CombatReset()
        return
    end
    if state.runId ~= run.id then
        flush()
        A.V2CombatReset()
        state.runId = run.id
        state.summary = newSummary()
        state.lastRun = run
    end
    local summary = state.summary
    local batch, err = read(state.cursor)
    if not batch then
        if err == "STREAM_CHANGED" then
            summary.gaps = summary.gaps + 1
            state.cursor, state.streamId = nil, nil
        elseif err ~= "NOT_READY" and err ~= "NOT_IN_WORLD" then
            summary.invalid = summary.invalid + 1
        end
        return
    end
    if err == "STREAM_CHANGED" or (state.streamId and state.streamId ~= batch.streamId) then
        summary.gaps = summary.gaps + 1
        state.cursor, state.streamId = nil, nil
        return
    end
    if type(batch.streamId) ~= "string" then
        summary.invalid = summary.invalid + 1
        return
    end
    state.streamId = batch.streamId
    local pages = 0
    while batch and pages < 8 do
        pages = pages + 1
        summary.batches = summary.batches + 1
        summary.dropped = summary.dropped + (number(batch.droppedCount) or 0)
        local events = batch.events
        if type(events) ~= "table" then
            summary.invalid = summary.invalid + 1
            break
        end
        for i = 1, math.min(table.getn(events), 256) do
            local e = events[i]
            if type(e) == "table" then
                if e.kind == "damage" then
                    local amount = number(e.amount)
                    if amount then
                        summary.hits = summary.hits + 1
                        summary.damageObserved = summary.damageObserved + amount
                        if e.critical == true then
                            summary.critical = summary.critical + 1
                        end
                        if e.periodic == true then
                            summary.periodic = summary.periodic + 1
                        end
                        if e.reflected == true then
                            summary.reflected = summary.reflected + 1
                        end
                        if
                            not bounded(
                                summary.sources,
                                e.meterSourceKey or e.meterSource or e.abilityName,
                                amount
                            )
                        then
                            summary.truncated = true
                        end
                        if
                            not bounded(
                                summary.schools,
                                tostring(number(e.schoolMask) or "unknown"),
                                amount
                            )
                        then
                            summary.truncated = true
                        end
                    else
                        summary.invalid = summary.invalid + 1
                    end
                elseif e.kind == "miss" then
                    summary.misses = summary.misses + 1
                else
                    summary.invalid = summary.invalid + 1
                end
            else
                summary.invalid = summary.invalid + 1
            end
        end
        state.cursor = batch.cursor
        if not batch.hasMore then
            break
        end
        local nextBatch, nextError = read(state.cursor)
        if
            not nextBatch
            or nextBatch.cursor == state.cursor
            or nextBatch.streamId ~= state.streamId
        then
            summary.gaps = summary.gaps + 1
            if
                nextError == "STREAM_CHANGED"
                or (nextBatch and nextBatch.streamId ~= state.streamId)
            then
                state.cursor, state.streamId = nil, nil
            end
            break
        end
        batch = nextBatch
    end
    if batch and batch.hasMore and pages >= 8 then
        summary.truncated = true -- remaining events are read on next tick
    end
    local t = number(run.values and run.values.duration)
    if t and (not state.lastFlush or t >= state.lastFlush + 15) then
        flush()
        state.lastFlush = t
    end
end

-- Observed run-average DPS records and co-op snapshots.
-- A common packet is required for a group ranking. Legacy independent samples
-- remain explicitly partial. Sound is one fixed client asset, at most once per run.

local A = AzerothStats

--- Create the addon-owned per-run co-op containers when observing their first sample.
local function partyState(run)
    run.coop = run.coop or { peers = {}, latest = {}, accounted = {} }
    return run.coop
end

--- Freeze party freshness at run start/resume so a stale global roster is not inherited.
function A.BeginInsights(run)
    A.partySession = {
        run = run,
        generation = A.partyGeneration or 0,
        stamp = AZS_PARTY_UPDATED,
        signature = A.Sign(A.Copy(AZS_PARTY)),
    }
end

--- Play one fixed native level-up asset via pcall; callers decide whether playback is appropriate.
function A.PlayRecordSound()
    if type(PlaySoundFile) ~= "function" then
        return false
    end
    local ok, result = pcall(PlaySoundFile, "Sound\\interface\\LevelUp.wav")
    return ok and result ~= false
end

--- Observe server damage/time pairs after ten seconds; notify once against a frozen prior class baseline.
local function dps(run, progress, phase)
    if run.status ~= "active" or (phase ~= "playing" and phase ~= "endless") then
        return
    end
    local elapsed, damage = A.Number(progress.t), A.Number(progress.dealt)
    if not elapsed or elapsed < 10 or not damage then
        return
    end
    if run.dpsLastTime and (elapsed < run.dpsLastTime or damage < run.dpsLastDamage) then
        run.dpsCounterDecreased = true
        return
    end
    if elapsed == run.dpsLastTime and damage == run.dpsLastDamage then
        return
    end
    run.dpsLastTime = elapsed
    run.dpsLastDamage = damage
    if run.dpsBaseline == nil then
        local group = A.db.classes[run.class]
        local record = group and group.records and group.records.peakDps
        run.dpsBaseline = record and record.value or false
    end
    local rate = damage / elapsed
    if not A.Number(rate) then
        return
    end
    if rate > (run.values.peakDps or -1) then
        run.values.peakDps = rate
        run.dpsSample = { damage = damage, elapsed = elapsed, rate = rate }
    end
    if run.dpsBaseline and rate > run.dpsBaseline and not run.dpsRecordNotified then
        -- Saved before notification: reloads cannot replay the same milestone.
        run.dpsRecordNotified = true
        A.Say(
            A.T("New class DPS record") .. " · " .. A.ClassName(run.class) .. " : " .. A.Rate(rate)
        )
        A.Event(run, "dps", tostring(rate))
        if A.db.settings.recordSound then
            A.PlayRecordSound()
        end
    end
end

--- Accept a fresh bounded roster, sanitize its rows and retain the last real multiplayer snapshot.
local function party(run)
    local coop = partyState(run)
    if type(AZS_PARTY) ~= "table" then
        coop.unavailable = "Party API unavailable"
        return
    end
    local session = A.partySession
    if not session or session.run ~= run then
        A.BeginInsights(run)
        session = A.partySession
    end
    local signature = A.Sign(A.Copy(AZS_PARTY))
    local generation = A.partyGeneration or 0
    if
        generation == session.generation
        and AZS_PARTY_UPDATED == session.stamp
        and signature == session.signature
    then
        if not coop.sampledAt then
            coop.unavailable = "No fresh party sample"
        end
        return
    end
    if AZS_PARTY_UPDATED == nil and generation == 0 then
        coop.unavailable = "No fresh party sample"
        return
    end
    session.generation = generation
    session.stamp = AZS_PARTY_UPDATED
    session.signature = signature
    local latest, rows, seen = {}, {}, {}
    local partial = table.getn(AZS_PARTY) > 32
    local selfIncluded = false
    for i = 1, math.min(table.getn(AZS_PARTY), 32) do
        local item = AZS_PARTY[i]
        if
            type(item) == "table"
            and type(item.name) == "string"
            and string.len(item.name) > 0
            and string.len(item.name) <= 80
            and type(item.class) == "string"
            and A.knownClasses[string.lower(item.class)]
        then
            local name = A.Text(item.name, 80)
            local class = string.lower(item.class)
            if name ~= "" then
                local key = name .. ":" .. class
                if seen[key] then
                    partial = true
                else
                    seen[key] = true
                    local own = name == run.hero and class == run.class
                    local clean = {
                        name = name,
                        class = class,
                        damage = A.Number(item.dmg),
                        dps = A.Number(item.dps),
                        top = type(item.top) == "string" and item.top ~= "" and A.Text(
                            item.top,
                            140
                        ) or nil,
                        topdps = A.Number(item.topdps),
                        isSelf = own,
                    }
                    table.insert(rows, clean)
                    if own then
                        selfIncluded = true
                    else
                        local entry = coop.peers[key]
                        if not entry then
                            local count = 0
                            for _ in pairs(coop.peers) do
                                count = count + 1
                            end
                            if count < 64 then
                                entry =
                                    { name = name, class = class, firstSeen = run.values.duration }
                                coop.peers[key] = entry
                            else
                                coop.truncated = true
                            end
                        end
                        if entry then
                            entry.lastSeen = run.values.duration
                            entry.damage = clean.damage
                            entry.dps = clean.dps
                            entry.top = clean.top
                            entry.topdps = clean.topdps
                            table.insert(latest, A.Copy(clean))
                        end
                    end
                end
            end
        else
            partial = true
        end
    end
    -- Keep the last actual multi-player sample after empty/out-of-party packets.
    if table.getn(latest) > 0 then
        coop.comparison = {
            rows = rows,
            selfIncluded = selfIncluded,
            partial = partial,
            observedTime = run.values.duration,
            sampledAt = A.Wall(),
            source = "AZSPARTY",
        }
    end
    coop.latest = latest
    coop.sampledAt = A.Wall()
    coop.unavailable = nil
end

--- Update death evidence, observed DPS and party snapshots for the current sampled run.
function A.ObserveInsights(run, progress, phase)
    A.ObserveNemesis(run, progress, phase)
    dps(run, progress, phase)
    if run.status == "active" or run.status == "terminal" or run.status == "ended" then
        party(run)
    end
end

--- Count each observed companion once per run; associate only the local run outcome with that presence.
function A.AccountInsights(run)
    local coop = run.coop
    if not coop then
        return
    end
    for key, entry in pairs(coop.peers) do
        local old = coop.accounted[key] or {}
        for _, group in ipairs({ A.db.totals, A.db.classes[run.class] }) do
            group.companions = group.companions or {}
            local rec = group.companions[key]
            if not rec then
                local count = 0
                for _ in pairs(group.companions) do
                    count = count + 1
                end
                if count < 1024 then
                    rec = { name = entry.name, class = entry.class, runs = 0, wins = 0 }
                    group.companions[key] = rec
                else
                    group.companionsTruncated = true
                end
            end
            if rec then
                if not old.seen then
                    rec.runs = rec.runs + 1
                end
                if run.winCounted and not old.win then
                    rec.wins = rec.wins + 1
                end
            end
        end
        coop.accounted[key] = { seen = true, win = run.winCounted or old.win }
    end
end

--- Build a personal fallback with actual summary/progress/meter provenance for older independent data.
local function personalRow(run)
    local value, time, rate, source
    if run.status == "ended" and run.summary then
        value = A.Number(run.summary.dmg)
        time = A.Number(run.summary.t)
        source = "Official result"
    end
    if not value and run.progress then
        value = A.Number(run.progress.dealt)
        time = A.Number(run.progress.t)
        source = "Last sample"
    end
    if value and time and time > 0 then
        rate = value / time
    end
    if not value and run.meters and run.meters.damage then
        value = A.Number(run.meters.damage.total)
        rate = A.Number(run.meters.damage.rate)
        source = "Last sample"
    end
    local top, topdps, best = nil, nil, -1
    local meter = run.meters and run.meters.damage
    for _, entry in ipairs(meter and meter.rows or {}) do
        local damage = A.Number(entry.dmg)
        if damage and damage > best and type(entry.name) == "string" then
            best = damage
            top = entry.name
            topdps = A.Number(entry.dps)
        end
    end
    return {
        name = run.hero or "?",
        class = run.class,
        isSelf = true,
        damage = value,
        dps = rate,
        top = top,
        topdps = topdps,
        observedTime = time,
        source = source or "Unavailable",
    }
end

--- Return comparable group rows only when a common snapshot exists; otherwise suppress invented ranks/shares.
function A.CoopComparison(run)
    local out = { rows = {}, synchronized = false, ranked = false }
    if not run or not run.coop then
        return out
    end
    local coop = run.coop
    local sample = coop.comparison
    if sample and type(sample.rows) == "table" and table.getn(sample.rows) > 0 then
        out.rows = A.Copy(sample.rows)
        out.observedTime = sample.observedTime
        out.synchronized = true
        out.partial = sample.partial
        if not sample.selfIncluded then
            table.insert(out.rows, personalRow(run))
            out.synchronized = false
            out.partial = true
        end
    else
        if not coop.peers or not next(coop.peers) then
            return out
        end
        -- Legacy 1.5-dev saved peers separately and discarded the player's matching party row.
        -- These are independent source samples: show their real values, but no team total/share/rank.
        table.insert(out.rows, personalRow(run))
        out.partial = true
        for _, entry in pairs(coop.peers) do
            table.insert(out.rows, {
                name = entry.name,
                class = entry.class,
                damage = entry.damage,
                dps = entry.dps,
                top = entry.top,
                topdps = entry.topdps,
                source = "Last group snapshot",
                observedTime = entry.lastSeen,
            })
        end
    end
    local damage, rate = 0, 0
    local completeDamage, completeRate = true, true
    for _, entry in ipairs(out.rows) do
        if A.Number(entry.damage) then
            damage = damage + entry.damage
        else
            completeDamage = false
        end
        if A.Number(entry.dps) then
            rate = rate + entry.dps
        else
            completeRate = false
        end
        entry.source = entry.source or "Last group snapshot"
        entry.observedTime = entry.observedTime or out.observedTime
    end
    if not completeDamage or not completeRate then
        out.partial = true
    end
    if out.synchronized and not (sample and sample.partial) then
        if completeDamage then
            out.total = damage
            out.ranked = true
        end
        if completeRate then
            out.rate = rate
        end
    end
    table.sort(out.rows, function(a, b)
        if out.ranked and a.damage ~= b.damage then
            return a.damage > b.damage
        end
        if not out.ranked and a.isSelf ~= b.isSelf then
            return a.isSelf and true or false
        end
        return tostring(a.name) < tostring(b.name)
    end)
    if out.ranked and damage > 0 then
        for _, entry in ipairs(out.rows) do
            entry.fraction = entry.damage / damage
        end
    end
    return out
end

--- Evidence-only mode badge. No saved roster means unknown, never proof of solo play.
--- Count describes the last shared snapshot, not everyone who joined throughout the run.
function A.CoopLabel(run)
    if not run or not run.coop then
        return nil
    end
    local sample = run.coop.comparison
    if sample and sample.rows and table.getn(sample.rows) > 1 then
        return A.T("Co-op") .. " · " .. A.T("Players in sample") .. " " .. table.getn(sample.rows)
    end
    if run.coop.peers and next(run.coop.peers) then
        return A.T("Co-op") .. " · " .. A.T("Partial")
    end
end

--- One presentation model shared by the report's group view; no native calls or saved writes.
function A.CoopReport(model, run)
    local comparison = A.CoopComparison(run)
    model.cardsTop, model.rowY, model.rowHeight, model.capacity = 318, 455, 48, 5
    model.columnLabel, model.columnValue =
        A.T(comparison.ranked and "Party damage ranking" or "Co-op"), A.T("Damage")
    model.note = A.T(
        comparison.synchronized and "Last group snapshot"
            or "Partial comparison: independent samples"
    ) .. " · " .. A.Duration(comparison.observedTime)
    if comparison.partial then
        model.note = model.note .. " · " .. A.T("Partial")
    end
    model.emptyText = A.T("No group snapshot recorded")
    for _, data in ipairs({
        { "Group damage", A.Short(comparison.total), "Ability_Warrior_SavageBlow" },
        { "Group DPS", A.CompactRate(comparison.rate), "Spell_Nature_Lightning" },
        {
            "Players in sample",
            table.getn(comparison.rows) > 0 and A.Format(table.getn(comparison.rows))
                or A.T("Unavailable"),
            "INV_Misc_Book_09",
        },
    }) do
        table.insert(model.cards, {
            label = A.T(data[1]),
            value = data[2],
            detail = A.T("Last group snapshot"),
            icon = data[3],
            exact = data[1] == "Group DPS" and A.Rate(comparison.rate)
                or data[1] == "Group damage" and A.Format(comparison.total)
                or data[2],
        })
    end
    for index, peer in ipairs(comparison.rows) do
        local detail = A.ClassName(peer.class)
            .. " · "
            .. A.T("Per second")
            .. " "
            .. A.CompactRate(peer.dps)
        if peer.fraction then
            detail = detail
                .. " · "
                .. A.T("Share")
                .. " "
                .. A.Decimal(peer.fraction * 100, 1)
                .. "%"
        end
        local exact = A.T("Damage")
            .. " "
            .. A.Format(peer.damage)
            .. "\n"
            .. A.T("Per second")
            .. " "
            .. A.Rate(peer.dps)
            .. "\n"
            .. detail
            .. "\n"
            .. A.T("Top spell")
            .. ": "
            .. (peer.top and A.SourceName(peer.top) or A.T("Unavailable"))
        if peer.topdps then
            exact = exact .. " · " .. A.Rate(peer.topdps) .. " DPS"
        end
        exact = exact
            .. "\n"
            .. A.T(peer.source or "Last group snapshot")
            .. " · "
            .. A.Duration(peer.observedTime)
        exact = exact .. "\n" .. A.T("Other players' healing and kills are unavailable")
        table.insert(model.rows, {
            label = (comparison.ranked and (index .. ". ") or "")
                .. peer.name
                .. (peer.isSelf and (" · " .. A.T("You")) or ""),
            value = A.Short(peer.damage),
            detail = detail,
            exact = exact,
            class = peer.class,
            fraction = peer.fraction,
        })
    end
end

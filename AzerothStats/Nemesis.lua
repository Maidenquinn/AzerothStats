-- Death evidence rather than a guessed fatal-attacker API.
-- A fresh last hit is probable; only an explicit native slain-by message confirms.
-- Loading on a dead screen cannot create an old death. Lists/captures are bounded.

local A = AzerothStats
-- Audited legacy client chat templates, not the modern combat-log API.
local templates = {
    { "COMBATHITOTHERSELF", "%s hits you for %d.", 1, 2 },
    { "COMBATHITCRITOTHERSELF", "%s crits you for %d.", 1, 2 },
    { "SPELLLOGOTHERSELF", "%s's %s hits you for %d.", 1, 3 },
    { "SPELLLOGCRITOTHERSELF", "%s's %s crits you for %d.", 1, 3 },
    { "PERIODICAURADAMAGEOTHERSELF", "You suffer %d %s damage from %s's %s.", 3, 1 },
}

--- Use the common plain-text sanitizer with the smaller combat-log label bound.
local function clean(s)
    return A.Text(s, 140)
end

--- Compile a native format to an escaped match pattern; reject more than four or invalid positional fields.
local function pattern(format)
    local out = "^"
    local order = {}
    local pos, index = 1, 0
    while pos <= string.len(format) do
        local _, finish, token = string.find(format, "^%%([sd])", pos)
        local number
        if not token then
            _, finish, number, token = string.find(format, "^%%(%d+)%$([sd])", pos)
        end
        if token then
            index = index + 1
            if index > 4 or (number and (tonumber(number) < 1 or tonumber(number) > 4)) then
                return nil
            end
            table.insert(order, tonumber(number) or index)
            out = out .. (token == "d" and "([%d,]+)" or "(.-)")
            pos = finish + 1
        else
            local ch = string.sub(format, pos, pos)
            if string.find("^$()%.[]*+-?", ch, 1, true) then
                out = out .. "%"
            end
            out = out .. ch
            pos = pos + 1
        end
    end
    return out .. "$", order
end

--- Match a bounded native message through pcall and reorder positional fields; no text is evaluated.
local function parse(message, format)
    if type(format) ~= "string" or string.len(format) > 500 then
        return nil
    end
    local p, order = pattern(format)
    if not p then
        return nil
    end
    local ok, first, last, a, b, c, d = pcall(string.find, message, p)
    if not ok then
        A.inputLimited = true
        return nil
    end
    local found = { first, last, a, b, c, d }
    if not found[1] then
        return nil
    end
    local fields = {}
    for i, n in ipairs(order) do
        fields[n] = found[i + 2]
    end
    return fields
end

--- Create a runtime-only unarmed evidence window for a new/resumed run.
function A.BeginDeathWatch(run)
    A.deathWatch = { run = run, hits = {}, armed = false, closed = false }
end

--- Record relevant native log evidence or an explicit slain-by message; ignore unrelated/unarmed events.
function A.DeathEvidence(ev, message)
    local watch = A.deathWatch
    if
        not A.db
        or not watch
        or watch.run ~= A.run
        or not watch.armed
        or type(message) ~= "string"
        or string.len(message) > 1000
    then
        return
    end
    local fields
    if ev == "UI_ERROR_MESSAGE" or ev == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
        -- This explicit native template is stronger evidence than a final observed hit.
        fields = parse(message, ERR_KILLED_BY_S)
        if fields and fields[1] and fields[1] ~= "" then
            watch.explicit = { source = clean(fields[1]), at = GetTime(), raw = clean(message) }
            if watch.closed and watch.last and GetTime() - watch.lastClock <= 2 then
                A.UpgradeDeath(watch)
            end
        end
        return
    end
    if watch.closed then
        return
    end
    for _, t in ipairs(templates) do
        fields = parse(message, getglobal(t[1]) or t[2])
        if fields then
            local source = clean(fields[t[3]])
            local n = A.Number(string.gsub(fields[t[4]] or "", ",", ""))
            if source and source ~= "" and n and n > 0 then
                table.insert(watch.hits, {
                    source = source,
                    amount = n,
                    at = GetTime(),
                    raw = clean(message),
                    event = ev,
                })
                if table.getn(watch.hits) > 8 then
                    table.remove(watch.hits, 1)
                end
            end
            return
        end
    end
    watch.unparsed = watch.unparsed or {}
    table.insert(watch.unparsed, clean(message))
    if table.getn(watch.unparsed) > 8 then
        table.remove(watch.unparsed, 1)
    end
end

--- Adjust one source confidence bucket globally/per class within the 512-name limit.
local function account(run, evidence, delta)
    for _, group in ipairs({ A.db.totals, A.db.classes[run.class] }) do
        group.deathEvidence = group.deathEvidence or { deaths = 0, sources = {} }
        local t = group.deathEvidence
        if evidence.source then
            local key = evidence.source
            local s = t.sources[key]
            if not s then
                local n = 0
                for _ in pairs(t.sources) do
                    n = n + 1
                end
                if n >= 512 then
                    t.truncated = true
                else
                    s = { confirmed = 0, probable = 0 }
                    t.sources[key] = s
                end
            end
            if s then
                s[evidence.confidence] = math.max(0, (s[evidence.confidence] or 0) + delta)
            end
        end
    end
end

--- Replace a probable/unknown attribution with late explicit proof without incrementing deaths again.
function A.UpgradeDeath(watch)
    local run, evidence = watch.run, watch.last
    if run.nemesisReset or not evidence or evidence.confidence == "confirmed" then
        return
    end
    account(run, evidence, -1)
    evidence.source = watch.explicit.source
    evidence.confidence = "confirmed"
    evidence.explicit = watch.explicit.raw
    account(run, evidence, 1)
end

--- Close one armed life segment, retain recent bounded evidence and account one observed death.
function A.MarkDeath()
    local watch = A.deathWatch
    if not watch or not A.db or watch.run ~= A.run or not watch.armed or watch.closed then
        return
    end
    local run = watch.run
    if run.nemesisReset then
        return
    end
    local now = GetTime()
    watch.closed = true
    watch.lastClock = now
    local evidence = { at = A.Wall(), t = run.values.duration, confidence = "unknown", hits = {} }
    for _, h in ipairs(watch.hits) do
        if now - h.at <= 10 then
            local hit = A.Copy(h)
            hit.age = now - h.at
            table.insert(evidence.hits, hit)
        end
    end
    local hit = watch.hits[table.getn(watch.hits)]
    if watch.explicit and now - watch.explicit.at <= 2 then
        evidence.source = watch.explicit.source
        evidence.confidence = "confirmed"
        evidence.explicit = watch.explicit.raw
    elseif hit and now - hit.at <= 2 then
        evidence.source = hit.source
        evidence.confidence = "probable"
    end
    if evidence.source and run.nemesisResets and run.nemesisResets[evidence.source] then
        return
    end
    evidence.unparsed = A.Copy(watch.unparsed)
    run.deaths = run.deaths or {}
    table.insert(run.deaths, evidence)
    if table.getn(run.deaths) > 20 then
        table.remove(run.deaths, 1)
        run.deathsTruncated = true
    end
    watch.last = evidence
    if not A.db.classes[run.class] then
        A.db.classes[run.class] = {}
    end
    for _, group in ipairs({ A.db.totals, A.db.classes[run.class] }) do
        group.deathEvidence = group.deathEvidence or { deaths = 0, sources = {} }
        group.deathEvidence.deaths = group.deathEvidence.deaths + 1
    end
    account(run, evidence, 1)
end

--- Arm after observed play and re-arm only after positive health beyond the late-event grace period.
function A.ObserveNemesis(run, progress, phase)
    if run.nemesisReset then
        return
    end
    local watch = A.deathWatch
    if not watch or watch.run ~= run then
        A.BeginDeathWatch(run)
        watch = A.deathWatch
    end
    if phase == "dead" then
        A.MarkDeath()
    elseif phase == "playing" or phase == "endless" then
        if not watch.closed then
            watch.armed = true
        elseif
            A.Number(progress.hp)
            and tonumber(progress.hp) > 0
            and GetTime() - watch.lastClock > 2
        then
            watch.armed = true
            watch.closed = false
            watch.hits = {}
            watch.explicit = nil
            watch.unparsed = nil
        end
    end
end

--- Build separate confidence counts and retained death-report rows for the selected class filter.
function A.NemesisModel(m, group)
    m.rowHeight = 43
    m.capacity = 9
    local t = group.deathEvidence or { deaths = 0, sources = {} }
    local sorted = {}
    for name, s in pairs(t.sources) do
        if (s.confirmed or 0) + (s.probable or 0) > 0 then
            table.insert(sorted, { name = name, s = s })
        end
    end
    table.sort(sorted, function(x, y)
        local a = x.s.confirmed + x.s.probable
        local b = y.s.confirmed + y.s.probable
        if a == b then
            return x.name < y.name
        end
        return a > b
    end)
    for _, v in ipairs(sorted) do
        table.insert(m.rows, {
            label = v.name,
            entryAction = { kind = "nemesis", key = v.name, label = v.name },
            value = A.Format(v.s.confirmed) .. " · " .. A.T("Confirmed") .. " / " .. A.Format(
                v.s.probable
            ) .. " · " .. A.T("Probable"),
            detail = A.T("Last attacker is not proof of a killing blow"),
            icon = A.metricIcons.bosses,
        })
    end
    for i = table.getn(A.db.runs), 1, -1 do
        local run = A.db.runs[i]
        if not A.view.class or run.class == A.view.class then
            for j = table.getn(run.deaths or {}), 1, -1 do
                local death = run.deaths[j]
                local id = run.id
                local evidence = A.T("Last attacker is not proof of a killing blow")
                if death.explicit then
                    evidence = evidence .. "\n" .. death.explicit
                end
                for _, h in ipairs(death.hits or {}) do
                    evidence = evidence .. "\n" .. (h.raw or h.source or "")
                end
                for _, message in ipairs(death.unparsed or {}) do
                    evidence = evidence .. "\n" .. message
                end
                table.insert(m.rows, {
                    exact = evidence,
                    label = A.Date(death.at) .. " · " .. (death.source or A.T("Unknown")),
                    value = A.Duration(death.t),
                    detail = A.ClassName(run.class)
                        .. " · "
                        .. A.T(
                            death.confidence == "confirmed" and "Confirmed"
                                or death.confidence == "probable" and "Probable"
                                or "Unknown"
                        ),
                    action = function()
                        A.SelectRun(id)
                    end,
                    favorite = A.RunFavorite(run),
                })
            end
        end
    end
    m.subtitle = A.T("Observed deaths") .. " : " .. A.Format(t.deaths)
    m.note = A.T("Last attacker is not proof of a killing blow")
    m.emptyText = A.T((t.deaths or 0) > 0 and "Unavailable" or "No death evidence recorded")
    if t.truncated then
        m.note = m.note .. " · " .. A.T("Partial")
    end
end

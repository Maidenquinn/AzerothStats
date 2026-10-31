-- Read-only V2 presentation over retained run IDs. These models never account data.
local A = AzerothStats
local context = A.RunContext
function A.RunContext(run)
    local text = context(run)
    local data = A.V2RunData(run)
    if data and data.affixesRaw ~= nil then
        text = text
            .. " · "
            .. A.T("Affixes")
            .. ": "
            .. (data.affixesRaw ~= "" and data.affixesRaw or "∅")
    end
    return text
end

-- One layout contract for all renderers. Legacy view producers still own their
-- data, but cannot place a row/plot inside the shared selected-run banner.
function A.V2Layout(model, run)
    local tab = A.view.tab
    model.analysis = model.report or tab == 5 or (tab == 4 and not A.view.cumulative)
    model.bannerTop, model.bannerHeight = 199, 62
    if model.analysis then
        model.bannerTop, model.bannerHeight = 164, 70
    end
    if tab == 3 and not model.report and not model.comparison then
        local parts = {}
        for _, card in ipairs(model.cards) do
            table.insert(parts, card.label .. " : " .. card.value)
        end
        model.cohort = table.concat(parts, " · ")
        model.historySummary = model.cards
        model.cards, model.banner = {}, nil
        model.rowY, model.rowHeight = 280, 78
    elseif model.comparison then
        model.rowY = 382
    elseif model.analysis then
        model.title = A.T("Analyze run")
        if run then
            model.banner = {
                label = A.ZoneName(run) .. " · " .. A.ClassName(run.class),
                detail = A.RunContext(run),
                value = A.Status(run.status == "active" and "active" or run.result or run.status)
                    .. " · "
                    .. A.Duration(run.values.duration),
                zone = run.zone,
                photo = true,
            }
        end
        if tab == 5 then
            model.rowY, model.rowHeight = 350, model.attributeTable and 44 or 54
        elseif tab == 4 then
            model.cardsTop, model.rowY = 326, 470
        elseif A.view.reportSection == "Overview" or A.view.reportSection == "Co-op" then
            model.cardsTop, model.rowY, model.rowHeight = 292, 430, 54
        elseif A.view.reportSection == "Build journal" then
            model.rowY = 350
        elseif not A.view.v2BossSample then
            model.rowY = 322
        end
        if model.curve then
            model.plotTop = tab == 5 and 328 or 290
            model.rowY = A.editMode and 350 or model.plotTop + 250
        end
    elseif tab == 7 then
        model.banner, model.rowY, model.rowHeight, model.plainRows = nil, 194, 44, true
    elseif tab == 10 then
        model.banner, model.rowY = nil, 254
    end
    if tab == 2 or tab == 6 or tab == 9 then
        if tab == 6 and not A.view.v2Goals then
            model.cardsTop, model.rowY = 206, 350
        elseif tab == 2 then
            model.cardsTop = 206
        elseif tab == 9 then
            model.banner, model.rowY = nil, 270
        else
            model.rowY = 222
        end
    end
    if model.attributeTable then
        local group, filtered = A.view.v2AttributeGroup or "all", {}
        local essential = {
            hp = true,
            dmg = true,
            cd = true,
            crit = true,
            cm = true,
            arm = true,
            area = true,
            cnt = true,
            spd = true,
            reg = true,
            lch = true,
            heal = true,
            xp = true,
            gold = true,
            luck = true,
        }
        for _, item in ipairs(model.rows) do
            local key = string.sub(item.visibilityKey, 11)
            if
                group == "all"
                or (group == "essential" and essential[key])
                or (group == "advanced" and not essential[key])
                or (group == "gear" and item.gearValue ~= A.T("Unavailable"))
            then
                table.insert(filtered, item)
            end
        end
        model.rows = filtered
        model.columnLabel = A.T("Attributes")
    end
    if
        model.analysis and (A.view.reportSection == "Summons" or A.view.reportSection == "Effects")
    then
        local store = A.V2Store(false)
        local pref = store and store.preferences or {}
        local key = A.view.reportSection == "Summons" and "summons" or "effects"
        if not pref[key] and table.getn(model.rows) == 0 then
            model.emptyText = A.T("Disabled")
                .. "\n"
                .. A.T("Settings")
                .. " → "
                .. A.T("Optional analyses")
        end
    end
end
A.v2Attributes = {
    { "hp", "Health", "integer", "ghp" },
    { "dmg", "Damage", "mult", "gdmg" },
    { "cd", "Haste", "cooldown", "gcd" },
    { "crit", "Crit", "pct", "gcrit" },
    { "cm", "Crit Dmg", "pct", "gcm" },
    { "arm", "Armor", "pct", "garm" },
    { "area", "Area", "mult", "garea" },
    { "cnt", "Targets", "integer", "gcnt" },
    { "echo", "Echo", "pct", "gecho" },
    { "spd", "Speed", "mult", "gspd" },
    { "reg", "Regen", "number", "greg" },
    { "pick", "Pickup", "yards", "gpick" },
    { "lch", "Lifesteal", "pct" },
    { "heal", "Kill Heal", "number" },
    { "thn", "Thorns", "pct" },
    { "liv", "Lives", "integer" },
    { "xp", "Experience", "mult" },
    { "gold", "Gold", "mult", "ggold" },
    { "luck", "Luck", "pct" },
    { "bp", "Buff Power", "pct" },
    { "dots", "DoT Stacks", "integer" },
    { "doth", "DoT Haste", "pct" },
    { "big", "Vs Elites", "pct" },
    { "exe", "Execute", "pct" },
    { "cc", "Vs Controlled", "pct" },
    { "dotd", "Vs Afflicted", "pct" },
    { "shd", "Shielded", "pct" },
    { "auto", "Melee", "pct" },
    { "pet", "Pet Damage", "pct" },
}

--- Formulas are taken from the audited native character pane, not inferred.
function A.V2AttributeValue(value, mode, gear)
    value = A.Number(value)
    if not value then
        return A.T("Unavailable")
    end
    if mode == "integer" then
        return A.Format(value)
    end
    if mode == "number" then
        return A.Decimal(value, 1)
    end
    if mode == "yards" and not gear then
        return A.Decimal(value, 1) .. " yd"
    end
    if gear then
        return A.Decimal(value * 100, 1) .. "%"
    end
    if mode == "mult" then
        value = value - 1
    elseif mode == "cooldown" then
        value = 1 - value
    end
    return A.Decimal(value * 100, 1) .. "%"
end

function A.V2RunData(run)
    local store = A.V2Store(false)
    return store and run and store.runs[run.id]
end

--- Missing group/affix evidence cannot establish equivalent contexts.
function A.V2Context(left, right)
    if left and right and left.id == right.id then
        return "Same run"
    end
    if not A.MatchingContext(left, right) then
        return "Different context"
    end
    local a, b = A.V2RunData(left), A.V2RunData(right)
    if not a or not b or a.affixesRaw == nil or b.affixesRaw == nil then
        return "Partial"
    end
    if a.affixesRaw ~= b.affixesRaw then
        return "Different context"
    end
    local pa = left.coop and left.coop.comparison and left.coop.comparison.rows
    local pb = right.coop and right.coop.comparison and right.coop.comparison.rows
    if not pa or not pb then
        return "Partial"
    end
    return table.getn(pa) == table.getn(pb) and "Matching context" or "Different context"
end

local function row(model, label, value, detail, key)
    local item = {
        label = label,
        value = value or "",
        detail = detail or "",
        visibilityKey = key,
        icon = A.metricIcons.damage,
    }
    table.insert(model.rows, item)
    return item
end

local function attributes(model, run, data)
    model.attributeTable = true
    local stats = data and data.latest or run.stats or {}
    for _, def in ipairs(A.v2Attributes) do
        local raw = A.Number(stats[def[1]])
        local gear = def[4] and A.Number(stats[def[4]])
        local numberGear = def[4] == "ghp" or def[4] == "greg" or def[4] == "gcnt"
        local item = row(
            model,
            A.G(def[2]) or def[2],
            A.V2AttributeValue(raw, def[3]),
            A.T("Equipment")
                .. " : "
                .. A.V2AttributeValue(gear, numberGear and "number" or def[3], not numberGear),
            "attribute:" .. def[1]
        )
        item.gearValue = A.V2AttributeValue(
            gear,
            (def[4] == "ghp" or def[4] == "gcnt") and "integer" or numberGear and "number" or def[3],
            not numberGear
        )
    end
    model.note = A.T("Last sample") .. " · " .. A.T("Observed changes, not card effects")
end

--- Produce measured points only. Never stretch a final total backward into a curve.
function A.V2Curve(run, metric)
    local data = A.V2RunData(run)
    local out, byTime = {}, {}
    for _, points in ipairs({ run and run.timeline or {}, data and data.progression or {} }) do
        for _, p in ipairs(points) do
            local t, value = A.Number(p.t), A.Number(p[metric])
            if t and value then
                byTime[t] = { t = t, value = value, gap = p.gap == true }
            end
        end
    end
    for _, p in pairs(byTime) do
        table.insert(out, p)
    end
    table.sort(out, function(a, b)
        return a.t < b.t
    end)
    while table.getn(out) > 240 do
        table.remove(out, 1)
        out[1].gap = true
    end
    return out
end

function A.V2EnhanceModel(model, run)
    if A.view.tab == 6 and A.view.v2Goals then
        A.V2GoalsModel(model)
        return
    end
    if model.comparison then
        model.subtitle = A.T(A.V2Context(A.FindRun(A.view.compareA), A.FindRun(A.view.compareB)))
    end
    if A.view.tab == 3 then
        model.title =
            A.T(model.comparison and "Compare runs" or model.report and "Analyze run" or "My runs")
    elseif A.view.tab == 2 or A.view.tab == 6 or A.view.tab == 9 then
        model.title = A.T("My progress")
    elseif A.view.tab == 10 then
        model.title = A.T("My favorites")
    end
    if not run then
        return
    end
    if model.report and model.banner then
        model.banner.detail = A.RunContext(run)
    end
    if A.view.tab == 1 or (A.view.tab == 3 and not model.report and not model.comparison) then
        for _, item in ipairs(model.rows) do
            local id = item.favorite and item.favorite.kind == "run" and item.favorite.key
            local data = id and A.V2RunData(A.FindRun(id))
            if data and data.affixesRaw and data.affixesRaw ~= "" then
                item.detail = (item.detail or "") .. " · [" .. data.affixesRaw .. "]"
            end
        end
    end
    local section = model.report and A.view.reportSection
        or (A.view.tab == 5 and A.view.characterTab)
    local supported = section == "Attributes"
        or section == "Timeline"
        or section == "Encounters"
        or section == "Summons"
        or section == "Effects"
        or section == "Observed support"
    if not supported then
        return
    end
    model.subtitle = A.T(section) .. " · " .. A.RunContext(run)
    local data = A.V2RunData(run)
    model.rows, model.cards = {}, {}
    model.rowY, model.rowHeight, model.capacity = model.report and 322 or 194, 48, 8
    model.columnLabel, model.columnValue = A.T(section), A.T("Total")
    model.note = A.T("Values from available samples")
    if section == "Attributes" then
        attributes(model, run, data)
    elseif section == "Timeline" then
        local metric = A.view.v2CurveMetric or "kills"
        model.curve = A.V2Curve(run, metric)
        model.curveMetric = metric
        model.curveCompare = A.view.v2CurveCompare and A.FindRun(A.view.v2CurveCompare)
        for _, p in ipairs(model.curve) do
            local item = row(
                model,
                A.Duration(p.t),
                A.Short(p.value),
                A.Metric(metric) .. (p.gap and (" · " .. A.T("Partial")) or ""),
                "point:" .. metric .. ":" .. p.t
            )
            item.point = p
        end
        if not A.editMode then
            model.rowY = model.rowY + 250
        end
    elseif section == "Encounters" then
        model.columnValue = A.T("Server time")
        if A.view.v2BossSample then
            for _, sample in ipairs(data and data.bossSamples or {}) do
                if tostring(sample.t) .. ":" .. sample.seq == A.view.v2BossSample then
                    model.subtitle = A.T("Shared boss meter") .. " · " .. A.Duration(sample.t)
                    model.rowY = 356
                    model.columnLabel, model.columnValue = A.T("Source"), A.T("Total")
                    for i, source in ipairs(sample.rows) do
                        row(
                            model,
                            A.SourceName(source.name),
                            A.Short(source.dmg),
                            A.T("Shared boss meter"),
                            "boss-source:" .. A.view.v2BossSample .. ":" .. i
                        )
                    end
                    return
                end
            end
            A.view.v2BossSample = nil
        end
        for i, b in ipairs(data and data.encounters or {}) do
            local item = row(
                model,
                b.name,
                A.Duration(b.at),
                A.T("Last sample")
                    .. " : "
                    .. A.Duration(b.lastAt)
                    .. " · "
                    .. A.T(b.closedAt and "Observed disappearance" or "Observed presence"),
                "encounter:" .. b.id .. ":" .. b.at
            )
            item.entryAction = {
                kind = "v2",
                runId = run.id,
                section = "encounters",
                key = b.id .. ":" .. b.at,
                label = b.name,
            }
        end
        for i, sample in ipairs(data and data.bossSamples or {}) do
            local sampleKey = tostring(sample.t) .. ":" .. sample.seq
            local item = row(
                model,
                A.T("Shared boss meter"),
                A.Short(sample.total),
                A.Duration(sample.t),
                "boss-sample:" .. i
            )
            item.action = function()
                A.view.v2BossSample, A.view.page = sampleKey, 1
            end
        end
    elseif section == "Summons" or section == "Effects" then
        model.columnValue = A.T("Maximum observed")
        local kinds = section == "Summons" and { "summons" } or { "buffs", "debuffs" }
        for _, kind in ipairs(kinds) do
            for key, item in pairs(data and data[kind] or {}) do
                local itemRow = row(
                    model,
                    item.name,
                    A.Format(item.maximum),
                    A.Duration(item.firstAt)
                        .. " → "
                        .. A.Duration(item.lastAt)
                        .. " · "
                        .. A.T("Observed presence")
                        .. (item.target and (" · ID " .. item.target) or ""),
                    kind .. ":" .. key
                )
                itemRow.entryAction = {
                    kind = "v2",
                    runId = run.id,
                    section = kind,
                    key = key,
                    label = item.name,
                }
            end
        end
        table.sort(model.rows, function(a, b)
            return a.label < b.label
        end)
    elseif section == "Observed support" then
        model.columnValue = A.T("Server time")
        local names = {
            baseline = "Last sample",
            down = "Downed",
            attempt = "Attempt",
            attemptEnded = "Attempt ended",
            interrupted = "Interrupted",
            returned = "Returned to combat",
        }
        for i, event in ipairs(data and data.support or {}) do
            local item = row(
                model,
                A.T(names[event.kind] or "Unknown"),
                A.Duration(event.t),
                (event.direction == "out" and "→ " or event.direction == "in" and "← " or "")
                    .. (event.name or A.T("Current run")),
                "support:" .. tostring(event.seq or i)
            )
            item.entryAction = event.seq
                    and {
                        kind = "v2",
                        runId = run.id,
                        section = "support",
                        key = tostring(event.seq),
                        label = item.label,
                    }
                or nil
        end
    end
    if data and data.truncated then
        model.note = model.note .. " · " .. A.T("Partial")
    end
    if data and data.expired then
        model.note = A.T("Advanced observations expired") .. " · " .. A.T("History")
    end
end

-- Local run reports and two-run comparison models. No native writes or composite score.
-- Values retain their original coverage; a missing source is never an exact zero.
local A = AzerothStats

function A.FindRun(id)
    for _, run in ipairs(A.db.runs) do
        if run.id == id then
            return run
        end
    end
end

function A.OpenReport(id)
    A.view.tab, A.view.historySection, A.view.page = 3, "Run report", 1
    A.view.selected = id
    A.view.reportSection = A.view.reportSection or "Overview"
    A.view.cumulative = false
end

--- Select the newest distinct compatible retained run, falling back to an explicit warning.
function A.OpenCompare(id)
    local first
    if id then
        first = A.FindRun(id)
    else
        first = A.Selected()
    end
    A.view.tab, A.view.historySection, A.view.page = 3, "Compare runs", 1
    A.view.compareA, A.view.compareB = first and first.id, nil
    A.view.compareSection = "Overview"
    if first then
        for i = table.getn(A.db.runs), 1, -1 do
            local other = A.db.runs[i]
            if other.id ~= first.id then
                A.view.compareB = A.view.compareB or other.id
                if A.MatchingContext(first, other) then
                    A.view.compareB = other.id
                    break
                end
            end
        end
    end
end

--- This verifies only the three named facts, not identical gear, co-op or run duration.
function A.MatchingContext(left, right)
    return left
        and right
        and left.id ~= right.id
        and left.class ~= "unknown"
        and left.class == right.class
        and left.zone
        and left.zone ~= "unknown"
        and left.zone == right.zone
        and A.HeroicLevel(left.heroic) ~= nil
        and left.heroic == right.heroic
end

--- Freeze class records before a NEW run first contributes. Never backfill on a reload.
function A.BeginReport(run)
    run.recordBaseline = { values = {} }
    local group = A.db.classes[run.class]
    for _, key in ipairs(A.metrics) do
        local record = group and group.records and group.records[key]
        if record and A.Number(record.value) then
            run.recordBaseline.values[key] = record.value
        end
    end
end

--- Recompute summary milestones from that baseline; first accepted summary offers one local notice.
function A.FinishReport(run)
    if run.recordBaseline then
        run.reportRecords = {}
        for _, key in ipairs(A.metrics) do
            local value = A.Number(run.values[key])
            local before = run.recordBaseline.values[key]
            if value and (before == nil or value > before) then
                run.reportRecords[key] = value
            end
        end
    end
    if not run.reportNotified then
        run.reportNotified = true
        A.pendingReport = { id = run.id, expires = GetTime() + 30 }
    end
end

local function value(key, number)
    if key == "duration" then
        return A.Duration(number)
    end
    if key == "peakDps" then
        return A.Rate(number)
    end
    return A.Short(number)
end

--- Difference is B minus A. A zero baseline has no percentage, even if B is positive.
function A.RunDifference(key, left, right)
    if left == nil or right == nil then
        return A.T("Unavailable")
    end
    local delta = right - left
    local sign = delta > 0 and "+" or (delta < 0 and "-" or "")
    local text = sign .. value(key, math.abs(delta))
    if left > 0 then
        text = text .. " (" .. sign .. A.Decimal(math.abs(delta / left) * 100, 1) .. "%)"
    end
    return text
end

local function add(model, label, key, left, right, icon)
    local row = {
        label = label,
        left = value(key, left),
        right = value(key, right),
        value = A.RunDifference(key, left, right),
        icon = icon,
        exact = "A: "
            .. (key == "duration" and A.Duration(left) or A.Format(left))
            .. " | B: "
            .. (key == "duration" and A.Duration(right) or A.Format(right)),
        detail = "",
    }
    row.exact = row.exact .. "\n" .. A.T("Difference (B - A)") .. ": " .. row.value
    table.insert(model.rows, row)
    return row
end

local function equipment(run, slot)
    if not run or not run.equipment or not run.equipment[slot] then
        return nil
    end
    return {
        label = run.equipment[slot],
        link = run.equipment[slot],
        slot = slot,
        run = run,
        class = run.class,
        tooltip = run.equipmentTooltips and run.equipmentTooltips[slot],
        collection = not (slot == 2 or (slot >= 11 and slot <= 14)),
    }
end

--- Stable keys only; differently named historical meter sources are not fuzzily merged.
local function sources(run, section)
    local result = {}
    local list = section == "Spells" and run and run.spells
        or (run and run.meters and run.meters.damage and run.meters.damage.rows)
    for i = 1, math.min(256, table.getn(list or {})) do
        local item = list[i]
        local key = section == "Spells" and (item.key or tostring(item.spell or item.name or "?"))
            or tostring(item.name or item.source or "?")
        local number = A.Number(section == "Spells" and item.rank or item.dmg)
        if number then
            local old = result[key]
            result[key] = {
                number = (section ~= "Spells" and old and old.number or 0) + number,
                label = section == "Spells" and A.SpellName(item) or A.SourceName(key),
            }
        end
    end
    return result
end

function A.ComparisonModel(model)
    local left, right = A.FindRun(A.view.compareA), A.FindRun(A.view.compareB)
    model.title, model.layout, model.comparison = A.T("Compare runs"), "comparison", true
    model.compareRuns = { left, right }
    model.subtitle =
        A.T(A.MatchingContext(left, right) and "Matching context" or "Different context")
    if left and right and left.id == right.id then
        model.subtitle = A.T("Same run")
    end
    if (left and left.partial) or (right and right.partial) then
        model.subtitle = model.subtitle .. " · " .. A.T("Partial")
    end
    model.note = A.T("Difference (B - A)") .. " · " .. A.T("Values from available samples")
    model.rowY, model.rowHeight, model.capacity = 420, 52, 5
    model.columnLabel, model.columnValue = A.T("Details"), A.T("Difference (B - A)")
    if not left or not right then
        model.emptyText = A.T("Select another run")
            .. "\n"
            .. A.T("Historical details may be pruned")
        return
    end
    local section = A.view.compareSection or "Overview"
    if section == "Overview" then
        for _, key in ipairs(A.metrics) do
            add(
                model,
                A.Metric(key),
                key,
                A.Number(left.values[key]),
                A.Number(right.values[key]),
                A.metricIcons[key]
            )
        end
    elseif section == "Equipment" then
        for slot = 1, 19 do
            local a, b = equipment(left, slot), equipment(right, slot)
            if a or b then
                local row = add(
                    model,
                    A.G("slot." .. (slot - 1)) or (A.T("Slot") .. " " .. slot),
                    "item",
                    nil,
                    nil
                )
                row.left, row.right, row.value =
                    a and a.label or A.T("Unavailable"), b and b.label or A.T("Unavailable"), ""
                row.leftItem, row.rightItem = a, b
                row.exact = "A: " .. row.left .. "\nB: " .. row.right
            end
        end
    else
        local a, b, keys, seen = sources(left, section), sources(right, section), {}, {}
        for key in pairs(a) do
            table.insert(keys, key)
            seen[key] = true
        end
        for key in pairs(b) do
            if not seen[key] then
                table.insert(keys, key)
            end
        end
        table.sort(keys, function(x, y)
            local vx, vy =
                (a[x] and a[x].number or 0) + (b[x] and b[x].number or 0),
                (a[y] and a[y].number or 0) + (b[y] and b[y].number or 0)
            if vx == vy then
                return x < y
            end
            return vx > vy
        end)
        for _, key in ipairs(keys) do
            local item = a[key] or b[key]
            local row = add(
                model,
                item.label,
                "number",
                a[key] and a[key].number,
                b[key] and b[key].number,
                A.SpellIcon(item.label)
            )
            if not a[key] or not b[key] then
                row.detail = A.T("Partial")
            end
        end
    end
end

function A.ReportModel(model, run)
    model.title, model.layout, model.report = A.T("Run report"), "report", true
    model.rowY, model.rowHeight, model.capacity = 350, 58, 6
    model.columnLabel, model.columnValue = A.T("Details"), A.T("Total")
    model.note = A.T("Last sample") .. " · " .. A.T("Values from available samples")
    if not run then
        model.emptyText = A.T("Source run no longer retained")
        return
    end
    model.banner = {
        label = A.ZoneName(run) .. " · " .. A.ClassName(run.class) .. " · " .. A.HeroicLabel(run),
        detail = A.Date(run.startedAt) .. " · " .. A.T(
            run.partial and "Partial" or "Observed runs"
        ),
        value = A.Status(run.status == "active" and "active" or run.result or run.status)
            .. " · "
            .. A.Duration(run.values.duration),
        zone = run.zone,
        photo = true,
    }
    local coop = A.CoopLabel(run)
    if coop then
        model.banner.detail = model.banner.detail .. " · " .. coop
    end
    local section = A.view.reportSection or "Overview"
    if section == "Overview" then
        model.cardsTop = 318
        for _, key in ipairs({ "duration", "kills", "damage" }) do
            table.insert(model.cards, {
                label = A.Metric(key),
                value = value(key, run.values[key]),
                detail = run.summary and A.T("Official summary") or A.T("Last sample"),
                icon = A.metricIcons[key],
                exact = A.Format(run.values[key]),
            })
        end
        model.rowY, model.capacity = 455, 4
        for _, key in ipairs({
            "gold",
            "level",
            "healing",
            "taken",
            "bosses",
            "elites",
            "guardians",
            "chests",
            "magnets",
            "peakDps",
        }) do
            table.insert(model.rows, {
                label = A.Metric(key),
                value = value(key, run.values[key]),
                exact = A.Format(run.values[key]),
                detail = "",
                icon = A.metricIcons[key],
            })
        end
    elseif section == "Build journal" then
        A.JournalModel(model, run)
    elseif section == "Character" then
        for i = 1, math.min(256, table.getn(run.spells or {})) do
            local spell = run.spells[i]
            table.insert(model.rows, {
                label = A.SpellName(spell),
                value = A.T("Rank") .. " " .. A.Format(spell.rank),
                detail = A.T("Spells"),
                icon = A.SpellIcon(A.SpellName(spell)),
            })
        end
        for slot = 1, 19 do
            local item = equipment(run, slot)
            if item then
                item.value, item.detail =
                    A.G("slot." .. (slot - 1)) or A.T("Slot"), A.T("Equipment")
                item.icon = run.equipmentIcons and run.equipmentIcons[slot]
                table.insert(model.rows, item)
            end
        end
    elseif section == "Co-op" then
        A.CoopReport(model, run)
    elseif section == "Records" then
        model.note = A.T("Records at summary") .. " · " .. A.T("All difficulties")
        for _, key in ipairs(A.metrics) do
            local number = run.reportRecords and run.reportRecords[key]
            if number then
                table.insert(model.rows, {
                    label = A.Metric(key),
                    value = value(key, number),
                    exact = A.Format(number),
                    detail = A.T("New class record"),
                    icon = A.metricIcons[key],
                })
            end
        end
        model.emptyText = A.T(run.recordBaseline and "No data yet" or "No record baseline")
    else
        local meter = run.meters and run.meters.damage
        local rows = {}
        for i = 1, math.min(256, table.getn(meter and meter.rows or {})) do
            table.insert(rows, meter.rows[i])
        end
        table.sort(rows, function(a, b)
            return a.dmg > b.dmg
        end)
        for _, entry in ipairs(rows) do
            local name = A.SourceName(entry.name or entry.source)
            table.insert(model.rows, {
                label = name,
                value = A.Short(entry.dmg),
                exact = A.Format(entry.dmg),
                detail = A.T("Per second") .. " " .. A.Rate(entry.dps),
                icon = A.SpellIcon(name),
            })
        end
    end
    A.DecorateFavorites(model, 5, run)
end

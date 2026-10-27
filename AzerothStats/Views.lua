-- Presentation models: cards, rows and trusted local navigation callbacks.
-- Missing counters stay unavailable. Rates, final results and partial samples
-- retain their provenance; view builders never issue gameplay commands.

local A = AzerothStats
A.tabs = {
    "Overview",
    "Classes",
    "History",
    "Combat",
    "Character",
    "Records",
    "Diagnostics",
    "Settings",
    "Usage",
    "Favorites",
    "Nemesis",
}
A.view = { tab = 1, page = 1, mode = "damage", characterTab = "Spells", combatTab = "Spells" }
A.metricIcons = {
    duration = "INV_Misc_PocketWatch_01",
    kills = "Ability_Warrior_Cleave",
    gold = "INV_Misc_Coin_01",
    damage = "Ability_Warrior_SavageBlow",
    healing = "Spell_Holy_Heal",
    taken = "INV_Shield_05",
    bosses = "Ability_Creature_Cursed_02",
    elites = "Ability_Creature_Cursed_01",
    guardians = "Spell_Nature_ProtectionformNature",
    chests = "INV_Box_01",
    magnets = "Spell_Nature_Purge",
    level = "INV_Misc_Book_09",
    peakDps = "Spell_Nature_Lightning",
}

--- Append one presentation row with a trusted optional local navigation callback.
local function row(out, label, value, detail, action, icon, fraction)
    local rowData = {
        label = label,
        value = value or "",
        detail = detail or "",
        action = action,
        icon = icon,
        fraction = fraction,
    }
    table.insert(out, rowData)
    return rowData
end

--- Append one summary card; cards contain display data rather than native gameplay operations.
local function card(model, label, value, detail, icon, action)
    local c = { label = label, value = value, detail = detail or "", icon = icon, action = action }
    table.insert(model.cards, c)
    return c
end

--- Resolve the requested retained run, or the current/latest run if retention removed that ID.
function A.Selected()
    if A.view.selected then
        for _, run in ipairs(A.db.runs) do
            if run.id == A.view.selected then
                return run
            end
        end
        A.view.selected = nil -- retention may have removed this detailed run
    end
    return A.run or A.db.runs[table.getn(A.db.runs)]
end

--- Choose the current own class aggregate or the global aggregate.
function A.Group()
    return A.view.class and (A.db.classes[A.view.class] or {}) or A.db.totals
end

--- Set local navigation to the selected run combat view.
function A.SelectRun(id)
    A.view.selected = id
    A.view.tab = 4
    A.view.cumulative = false
    A.view.combatTab = "Spells"
    A.view.page = 1
end

--- Set local navigation to one run comparison and clear the companion-list drilldown.
function A.SelectCoopRun(id)
    A.view.selected = id
    A.view.tab = 9
    A.view.usageTab = "Co-op"
    A.view.cumulative = false
    A.view.coopPartner = nil
    A.view.page = 1
end

--- Describe how many observed runs supplied a metric; missing coverage is not assumed complete.
function A.Coverage(group, key)
    return A.T("Coverage")
        .. " : "
        .. A.Format(group.coverage and group.coverage[key] or 0)
        .. " / "
        .. A.Format(group.runs or 0)
end

--- Translate stored event kinds and their bounded details for the activity journal.
function A.EventLabel(entry, run)
    local keys = {
        dps = "New class DPS record",
        start = "Observed runs",
        resume = "Probable resume; no server run ID",
        level = "Rank",
        phase = "Activity",
        summary = "Official result",
        terminal = "Ended",
        continue = "Continued",
        boundary = "Interrupted",
        checkpoint = "Local storage",
    }
    local label = A.T(keys[entry.kind] or "Activity")
    local detail = ""
    if entry.kind == "dps" then
        detail = A.Rate(A.Number(entry.text))
    elseif entry.kind == "level" then
        local _, _, n = string.find(entry.text or "", "(%d+)$")
        detail = n or ""
    elseif entry.kind == "phase" then
        local _, _, before, after = string.find(entry.text or "", "^(%w+) %-> (%w+)$")
        if before then
            detail = A.Status(before) .. " > " .. A.Status(after)
        end
    elseif entry.kind == "summary" then
        local _, _, result = string.find(entry.text or "", ": (%w+)$")
        detail = A.Status(result)
    elseif entry.kind == "start" and run.partial then
        detail = A.T("Partial observation")
    end
    return label, detail
end

--- Build global/class cards and coverage rows from already-accounted data.
local function overview(model, group)
    for _, entry in ipairs({
        { "Observed runs", group.runs or 0, "INV_Misc_Book_09" },
        { "Wins", group.wins or 0, "INV_Misc_Coin_02" },
    }) do
        card(
            model,
            A.T(entry[1]),
            A.Format(entry[2]),
            A.T("Collected since installation"),
            entry[3]
        )
    end
    for _, key in ipairs({ "duration", "kills", "damage", "gold" }) do
        local v = group.sum and group.sum[key]
        local c = card(
            model,
            key == "duration" and A.T("Play time") or A.Metric(key),
            key == "duration" and A.Duration(v) or A.Short(v),
            A.Coverage(group, key),
            A.metricIcons[key]
        )
        c.exact = key == "duration" and A.Duration(v) or A.Format(v)
    end
    for _, key in ipairs({
        "healing",
        "taken",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        row(
            model.rows,
            A.Metric(key),
            A.Format(group.sum and group.sum[key]),
            A.Coverage(group, key),
            nil,
            A.metricIcons[key]
        )
    end
    model.note = A.T("Values from available samples")
end

--- Build one navigation card per observed class aggregate.
local function classes(model)
    model.layout = "classes"
    local keys = {}
    for cls in pairs(A.db.classes) do
        table.insert(keys, cls)
    end
    table.sort(keys)
    for _, cls in ipairs(keys) do
        local b = A.db.classes[cls]
        local chosen = cls
        local c = card(
            model,
            A.ClassName(cls),
            A.Format(b.runs or 0),
            A.T("Observed runs") .. " · " .. A.Format(b.wins or 0) .. " " .. A.T("Wins"),
            nil,
            function()
                A.view.class = chosen
                A.view.tab = 1
                A.view.page = 1
            end
        )
        c.class = cls
    end
end

--- List retained observed runs under the class filter with stable-ID navigation and favorites.
local function history(model)
    model.rowHeight = 43
    model.rowY = 164
    model.capacity = 9
    for i = table.getn(A.db.runs), 1, -1 do
        local run = A.db.runs[i]
        local id = run.id
        if not A.view.class or A.view.class == run.class then
            local item = row(
                model.rows,
                (run.hero or "?") .. " · " .. A.ClassName(run.class),
                A.Duration(run.values.duration),
                A.Date(run.startedAt)
                    .. " · "
                    .. A.ZoneName(run)
                    .. " · "
                    .. A.Status(run.result or run.status)
                    .. (run.partial and " · " .. A.T("Partial") or ""),
                function()
                    A.SelectRun(id)
                end
            )
            item.favorite = A.RunFavorite(run)
            item.class = run.class
            item.exact = run.id
                .. " · "
                .. A.Metric("kills")
                .. " "
                .. A.Format(run.values.kills)
                .. " · "
                .. A.Metric("level")
                .. " "
                .. A.Format(run.values.level)
        end
    end
end

--- Build one sampled/cumulative meter, keeping unavailable rates and last-boss scope explicit.
local function combat(model, run, group)
    model.rowY = 301
    model.rowHeight = 28
    model.capacity = 10
    local mode = A.view.mode
    if A.view.combatTab == "Activity" then
        if A.view.cumulative then
            model.note = A.T("Current run")
            return
        end
        model.rowY = 191
        model.rowHeight = 34
        model.capacity = 11
        if run then
            if run.official then
                row(
                    model.rows,
                    A.T("Official result"),
                    A.Status(run.official.result),
                    A.Duration(run.official.t)
                )
            end
            for _, key in ipairs({ "bosses", "elites", "guardians", "chests", "magnets" }) do
                row(
                    model.rows,
                    A.Metric(key),
                    A.Format(run.values[key]),
                    key == "chests"
                            and not run.summary
                            and A.T("Chest count available in final summary")
                        or "",
                    nil,
                    A.metricIcons[key]
                )
            end
            for i = table.getn(run.events), 1, -1 do
                local entry = run.events[i]
                local label, detail = A.EventLabel(entry, run)
                row(model.rows, label, A.Duration(entry.t), detail)
            end
        end
        return
    end
    local rows, total, rate = {}
    if A.view.cumulative then
        if mode == "boss" then
            model.note = A.T("The last boss fight only")
            model.emptyText = A.T("Select a run for its last boss fight")
            return
        end
        for name, value in pairs(group.spells and group.spells[mode] or {}) do
            table.insert(rows, { name = name, dmg = value })
            total = (total or 0) + value
        end
        model.note = A.T("Values from available samples")
    elseif run then
        local meter = run.meters[mode]
        if meter then
            rows = meter.rows
            total = meter.total
            rate = meter.rate
        end
        model.note = mode == "boss" and A.T("The last boss fight only")
            or A.T("Values from available samples")
        if run.unavailable and run.unavailable[mode] then
            model.note = A.Reason(run.unavailable[mode])
        end
    end
    card(
        model,
        A.T("Total"),
        A.Short(total),
        A.ModeName(mode),
        A.metricIcons[mode] or A.metricIcons.bosses
    ).exact =
        A.Format(total)
    card(
        model,
        A.T("Per second"),
        A.Rate(rate),
        A.view.cumulative and A.T("Unavailable") or A.T("Last sample"),
        "Spell_Nature_Lightning"
    )
    card(
        model,
        A.T("Play time"),
        A.view.cumulative and A.Duration(group.sum and group.sum.duration)
            or A.Duration(run and run.values.duration),
        A.T("Server time"),
        A.metricIcons.duration
    )
    local sorted = {}
    for _, spell in ipairs(rows) do
        table.insert(sorted, spell)
    end
    table.sort(sorted, function(a, b)
        return a.dmg > b.dmg
    end)
    for i, spell in ipairs(sorted) do
        local share = total and total > 0 and spell.dmg / total or 0
        local detail = A.T("Share") .. " " .. A.Decimal(share * 100, 1) .. "%"
        if spell.dps then
            detail = detail .. " · " .. A.T("Per second") .. " " .. A.Rate(spell.dps)
        end
        if spell.proc == 1 then
            detail = detail .. " · " .. A.T("Proc")
        end
        local item = row(
            model.rows,
            A.SourceName(spell.name or spell.source),
            A.Short(spell.dmg),
            detail,
            nil,
            A.SpellIcon(spell.name),
            share
        )
        item.favorite = {
            kind = "spell",
            key = (not A.view.cumulative and run and (run.id .. ":") or "")
                .. mode
                .. ":"
                .. tostring(spell.name or spell.source),
            label = item.label,
            tab = 4,
            mode = mode,
            class = A.view.cumulative and A.view.class or (run and run.class),
            cumulative = A.view.cumulative == true,
            runId = not A.view.cumulative and run and run.id or nil,
        }
        item.rank = i
        item.exact = A.Format(spell.dmg)
    end
end

--- Present recorded spells, equipment, scalar attributes or progression; never modify the character.
local function character(model, run)
    model.rowY = 193
    model.rowHeight = 31
    model.capacity = 12
    if not run then
        return
    end
    local section = A.view.characterTab or "Spells"
    if section == "Spells" then
        for _, spell in ipairs(run.spells or {}) do
            local item = row(
                model.rows,
                A.SpellName(spell),
                A.T("Rank") .. " " .. A.Format(spell.rank),
                "",
                nil,
                A.SpellIcon(A.SpellName(spell))
            )
            item.favorite = {
                kind = "spell",
                key = spell.key or tostring(spell.spell or item.label),
                label = item.label,
                tab = 9,
                section = "Spells",
                class = run.class,
            }
        end
    elseif section == "Equipment" then
        local extra = {
            [2] = "Neck",
            [4] = "Shirt",
            [11] = "Finger",
            [12] = "Finger",
            [13] = "Trinket",
            [14] = "Trinket",
            [19] = "Tabard",
        }
        local fallback = {
            "INV_Helmet_03",
            "INV_Jewelry_Necklace_01",
            "INV_Shoulder_01",
            "INV_Shirt_01",
            "INV_Chest_Chain_04",
            "INV_Belt_03",
            "INV_Pants_06",
            "INV_Boots_05",
            "INV_Bracer_01",
            "INV_Gauntlets_05",
            "INV_Jewelry_Ring_03",
            "INV_Jewelry_Ring_03",
            "INV_Misc_Gem_Pearl_04",
            "INV_Misc_Gem_Pearl_04",
            "INV_Misc_Cape_03",
            "INV_Sword_04",
            "INV_Shield_05",
            "INV_Weapon_Bow_01",
            "INV_Shirt_01",
        }
        for slot = 1, 19 do
            if run.equipment and run.equipment[slot] then
                local jewel = slot == 2 or (slot >= 11 and slot <= 14)
                local item = row(
                    model.rows,
                    run.equipment[slot],
                    A.G("slot." .. (slot - 1)) or A.T(extra[slot] or "Slot"),
                    A.T(jewel and "Run jewelry" or "Collection equipment"),
                    nil,
                    run.equipmentIcons and run.equipmentIcons[slot] or fallback[slot]
                )
                item.link = run.equipment[slot]
                item.tooltip = run.equipmentTooltips and run.equipmentTooltips[slot]
                item.slot = slot
                item.run = run
                item.collection = not jewel
                item.class = run.class
            end
        end
    elseif section == "Attributes" then
        -- Names and conversions audited against the installed MASH stat table.
        local known = {
            { "hp", "Health", "number" },
            { "dmg", "Damage", "mult" },
            { "cd", "Haste", "cooldown" },
            { "crit", "Crit", "pct" },
            { "cm", "Crit Dmg", "pct" },
            { "arm", "Armor", "pct" },
            { "area", "Area", "mult" },
            { "cnt", "Targets", "number" },
            { "spd", "Speed", "mult" },
            { "reg", "Regen", "number" },
            { "lch", "Lifesteal", "pct" },
            { "heal", "Kill Heal", "number" },
            { "xp", "Experience", "mult" },
            { "gold", "Gold", "mult" },
            { "luck", "Luck", "pct" },
        }
        for _, def in ipairs(known) do
            local value = run.stats and A.Number(run.stats[def[1]])
            if value then
                local formatted = A.Decimal(value, 1)
                if def[3] == "mult" then
                    formatted = A.Decimal((value - 1) * 100, 1) .. "%"
                elseif def[3] == "cooldown" then
                    formatted = A.Decimal((1 - value) * 100, 1) .. "%"
                elseif def[3] == "pct" then
                    formatted = A.Decimal(value * 100, 1) .. "%"
                end
                row(model.rows, A.G(def[2]) or def[2], formatted, A.T("Last sample"))
            end
        end
    else
        for _, v in ipairs(run.timeline or {}) do
            row(
                model.rows,
                A.Duration(v.t),
                A.Metric("level") .. " " .. A.Format(v.level),
                A.Metric("kills")
                    .. " "
                    .. A.Format(v.kills)
                    .. " · "
                    .. A.Metric("gold")
                    .. " "
                    .. A.Format(v.gold)
            )
        end
    end
    model.note = A.T("Last sample") .. " · " .. A.T("Values from available samples")
end

--- Dispatch the active page and annotate partial coverage; return cards/rows for the renderer.
function A.PageModel()
    local tab, run, group = A.view.tab, A.Selected(), A.Group()
    local model = {
        title = A.T(A.tabs[tab]),
        subtitle = A.T("Collected since installation"),
        cards = {},
        rows = {},
        rowY = 164,
        rowHeight = 31,
        capacity = 12,
        layout = "list",
    }
    if tab == 1 then
        model.layout = "overview"
        model.rowY = 386
        model.rowHeight = 26
        model.capacity = 7
        overview(model, group)
    elseif tab == 2 then
        classes(model)
    elseif tab == 3 then
        history(model)
    elseif tab == 4 then
        model.layout = "combat"
        model.subtitle = A.view.cumulative
                and (A.T("All runs") .. " · " .. A.ModeName(A.view.mode) .. " · " .. (A.view.class and A.ClassName(
                    A.view.class
                ) or A.T("All classes")))
            or (
                A.Metric("level")
                .. " "
                .. A.Format(run and run.values.level)
                .. " · "
                .. A.Metric("kills")
                .. " "
                .. A.Format(run and run.values.kills)
                .. " · "
                .. A.Metric("gold")
                .. " "
                .. A.Format(run and run.values.gold)
            )
        combat(model, run, group)
    elseif tab == 5 then
        model.subtitle = A.T("Last sample")
        character(model, run)
    elseif tab == 6 then
        for _, key in ipairs(A.metrics) do
            local rec = group.records and group.records[key]
            local action
            if rec then
                for _, run in ipairs(A.db.runs) do
                    if run.id == rec.id then
                        local id = rec.id
                        action = function()
                            A.SelectRun(id)
                        end
                        break
                    end
                end
            end
            row(
                model.rows,
                A.Metric(key),
                rec
                        and (key == "duration" and A.Duration(rec.value) or (key == "peakDps" and A.Rate(
                            rec.value
                        ) or A.Format(rec.value)))
                    or A.T("Unavailable"),
                rec
                        and (A.Date(rec.at) .. " · " .. rec.id .. (key == "peakDps" and (" · " .. A.T(
                            "Server-sample run average (10s+)"
                        )) or ""))
                    or "",
                action,
                A.metricIcons[key]
            )
        end
        model.note = A.T("Values from available samples")
    elseif tab == 7 then
        model.subtitle = A.T("Raw API identifiers are not translated")
        for _, d in ipairs(A.DiagnosticRows()) do
            row(model.rows, d[1], d[2], d[3])
        end
        if run then
            row(
                model.rows,
                A.T("Quality"),
                run.partial and A.T("Partial observation") or A.T("Available"),
                run.resumeHeuristic and A.T("Probable resume; no server run ID") or ""
            )
            for k, v in pairs(run.summary or {}) do
                if type(v) ~= "table" then
                    row(model.rows, "AZS_END." .. k, A.Format(v))
                end
            end
            for k, v in pairs(run.progress or {}) do
                if type(v) ~= "table" then
                    row(model.rows, "AZS_RUN." .. k, A.Format(v))
                end
            end
        end
    elseif tab == 8 then
        model.layout = "settings"
        model.subtitle = A.T("Changes apply immediately")
    elseif tab == 9 then
        model.rowY = 200
        model.rowHeight = 46
        model.capacity = 8
        if A.view.usageTab == "Co-op" then
            if A.view.cumulative then
                if A.view.coopPartner then
                    local name = A.view.coopPartner
                    for i = table.getn(A.db.runs), 1, -1 do
                        local run = A.db.runs[i]
                        local peer = run.coop and run.coop.peers and run.coop.peers[name]
                        if peer and (not A.view.class or run.class == A.view.class) then
                            local id = run.id
                            local item = row(
                                model.rows,
                                A.Date(run.startedAt) .. " · " .. A.ZoneName(run),
                                A.Duration(run.values.duration)
                                    .. " · "
                                    .. A.Status(run.result or run.status),
                                peer.name
                                    .. " · "
                                    .. A.Short(peer.damage)
                                    .. " · "
                                    .. A.Rate(peer.dps)
                                    .. " DPS",
                                function()
                                    A.SelectCoopRun(id)
                                end
                            )
                            item.class = run.class
                        end
                    end
                    model.subtitle = A.T("History") .. " · " .. A.view.coopPartner
                    model.note = A.T("Historical details may be pruned")
                else
                    local sorted = {}
                    for key, entry in pairs(group.companions or {}) do
                        table.insert(sorted, { key = key, e = entry })
                    end
                    table.sort(sorted, function(a, b)
                        if (a.e.runs or 1) == (b.e.runs or 1) then
                            return a.key < b.key
                        end
                        return (a.e.runs or 1) > (b.e.runs or 1)
                    end)
                    for _, v in ipairs(sorted) do
                        local entry, key = v.e, v.key
                        local item = row(
                            model.rows,
                            entry.name,
                            A.Format(entry.runs or 1) .. " · " .. A.T("Runs observed"),
                            A.ClassName(entry.class)
                                .. " · "
                                .. A.T("Victories in observed runs")
                                .. " "
                                .. A.Format(entry.wins)
                                .. " · "
                                .. A.T("History"),
                            function()
                                A.view.coopPartner = key
                                A.view.page = 1
                            end
                        )
                        item.class = entry.class
                        item.favorite = { kind = "companion", key = key, label = entry.name }
                    end
                    model.subtitle = A.T("All runs")
                    model.note = A.T("Observed names only") .. " · " .. A.T("Click to inspect")
                end
            else
                local comparison = A.CoopComparison(run)
                model.layout = "combat"
                model.rowY = 301
                model.capacity = 6
                card(
                    model,
                    A.T("Group damage"),
                    A.Short(comparison.total),
                    A.T("Last group snapshot"),
                    A.metricIcons.damage
                ).exact =
                    A.Format(comparison.total)
                card(
                    model,
                    A.T("Group DPS"),
                    A.Rate(comparison.rate),
                    A.T("Last group snapshot"),
                    "Spell_Nature_Lightning"
                )
                card(
                    model,
                    A.T("Players in sample"),
                    A.Format(table.getn(comparison.rows)),
                    A.T("Last sample") .. " · " .. A.Duration(comparison.observedTime),
                    A.metricIcons.duration
                )
                for i, entry in ipairs(comparison.rows) do
                    local label = (comparison.ranked and (i .. ". ") or "")
                        .. entry.name
                        .. (entry.isSelf and (" · " .. A.T("You")) or "")
                    local detail = A.ClassName(entry.class)
                    if entry.fraction then
                        detail = detail
                            .. " · "
                            .. A.T("Share of sampled damage")
                            .. " "
                            .. A.Decimal(entry.fraction * 100, 1)
                            .. "%"
                    end
                    detail = detail
                        .. " · "
                        .. A.T("Top spell")
                        .. " : "
                        .. (entry.top and A.SourceName(entry.top) or A.T("Unavailable"))
                    if entry.topdps then
                        detail = detail .. " (" .. A.Rate(entry.topdps) .. " DPS)"
                    end
                    if not comparison.synchronized then
                        detail = detail
                            .. " · "
                            .. A.T(entry.source)
                            .. " · "
                            .. A.Duration(entry.observedTime)
                    end
                    local item = row(
                        model.rows,
                        label,
                        A.Short(entry.damage) .. " · " .. A.Rate(entry.dps) .. " DPS",
                        detail,
                        nil,
                        nil,
                        entry.fraction
                    )
                    item.class = entry.class
                    item.player = entry.name
                    item.exact = A.T("Damage")
                        .. " "
                        .. A.Format(entry.damage)
                        .. " · "
                        .. A.Rate(entry.dps)
                        .. " DPS"
                end
                model.subtitle = comparison.ranked and A.T("Party damage ranking") or A.T("Co-op")
                model.note = A.T(
                    comparison.synchronized and "Last group snapshot"
                        or "Partial comparison: independent samples"
                ) .. " · " .. A.T(
                    "Other players' healing and kills are unavailable"
                )
                if comparison.partial and comparison.synchronized then
                    model.note = A.T("Partial") .. " · " .. model.note
                end
                if table.getn(comparison.rows) == 0 then
                    model.cards = {}
                    model.emptyText = A.T("No group snapshot recorded")
                    model.note = run
                            and run.coop
                            and run.coop.unavailable
                            and A.T(run.coop.unavailable)
                        or A.T("No group snapshot recorded")
                end
            end
            if group.companionsTruncated or (run and run.coop and run.coop.truncated) then
                model.note = model.note .. " · " .. A.T("Partial")
            end
        else
            local kind = A.view.usageTab == "Jewelry" and "jewelry" or "spells"
            local source = A.view.cumulative and group or run
            local entries = source and source.usage and source.usage[kind] or {}
            local sorted = {}
            for key, entry in pairs(entries) do
                table.insert(sorted, { key = key, e = entry })
            end
            table.sort(sorted, function(a, b)
                if (a.e.runs or 1) ~= (b.e.runs or 1) then
                    return (a.e.runs or 1) > (b.e.runs or 1)
                end
                local av, bv = a.e.gains or a.e.changes or 0, b.e.gains or b.e.changes or 0
                if av ~= bv then
                    return av > bv
                end
                return a.key < b.key
            end)
            for _, v in ipairs(sorted) do
                local entry, key = v.e, v.key
                local label = kind == "spells" and A.SpellName({ key = key, spell = entry.spell })
                    or A.JewelName(key, entry.name)
                local detail = kind == "spells"
                        and (A.T("Observed rank gains") .. " " .. A.Format(entry.gains) .. " · " .. A.T(
                            "Maximum rank"
                        ) .. " " .. A.Format(entry.maxRank))
                    or (A.T("Observed item changes") .. " " .. A.Format(entry.changes))
                local item = row(
                    model.rows,
                    label,
                    A.Format(entry.runs or 1) .. " · " .. A.T("Runs observed"),
                    detail,
                    nil,
                    kind == "spells" and A.SpellIcon(label) or entry.icon
                )
                item.favorite = {
                    kind = kind == "spells" and "spell" or "jewelry",
                    key = key,
                    label = label,
                    tab = 9,
                    section = kind == "spells" and "Spells" or "Jewelry",
                    class = A.view.class,
                    display = {
                        link = entry.link,
                        tooltip = entry.tooltip,
                        icon = entry.icon,
                        label = label,
                    },
                }
                if kind == "jewelry" then
                    item.link = entry.link
                    item.tooltip = entry.tooltip
                end
            end
            model.subtitle = A.T(A.view.cumulative and "All runs" or "Current run")
                .. " · "
                .. (A.view.class and A.ClassName(A.view.class) or A.T("All classes"))
            model.note = A.T("Build observations since 1.3; not clicks or casts")
        end
    end
    if tab == 10 then
        A.FavoritesModel(model)
    elseif tab == 11 then
        A.NemesisModel(model, group)
    end
    if
        group.usageTruncated
        or group.spellSourcesTruncated
        or (run and (run.usageTruncated or run.spellSourcesTruncated))
    then
        model.note = (model.note or "") .. " · " .. A.T("Partial")
    end
    A.DecorateFavorites(model, tab, run)
    if table.getn(model.rows) == 0 and table.getn(model.cards) == 0 and tab ~= 8 then
        model.empty = true
    end
    return model
end

--- Expose the current presentation rows for callers/tests without touching native game state.
function A.Rows()
    return A.PageModel().rows
end

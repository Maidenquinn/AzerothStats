-- Local HUD configuration and read-only metric models. No native gameplay effects.
-- Scope belongs to each block; presentation never changes the accounting ledger.
local A = AzerothStats
A.barMetrics = {
    { "runs", "Observed runs", "INV_Misc_Book_09", 3 },
    { "wins", "Wins", "INV_Misc_Coin_02", 3 },
    { "duration", "Play time", "INV_Misc_PocketWatch_01", 1, true },
    { "kills", "Kills", "Ability_Warrior_Cleave", 1, true },
    { "gold", "Gold", "INV_Misc_Coin_01", 1, true },
    { "damage", "Damage dealt", "Ability_Warrior_SavageBlow", 4, true },
    { "healing", "Effective healing", "Spell_Holy_Heal", 4, true },
    { "taken", "Damage taken", "INV_Shield_05", 4, true },
    { "bosses", "Bosses killed", "Ability_Creature_Cursed_02", 1, true },
    { "elites", "Elites killed", "Ability_Creature_Cursed_01", 1, true },
    { "guardians", "Guardians killed", "Spell_Nature_ProtectionformNature", 1, true },
    { "chests", "Chests opened", "INV_Box_01", 1, true },
    { "magnets", "Magnets", "Spell_Nature_Purge", 1, true },
    { "level", "Level", "INV_Misc_Book_09", 6, true },
    { "peakDps", "Peak observed DPS", "Spell_Nature_Lightning", 6, true },
}

--- Resolve only a source-defined metric ID, never a payload-selected API function.
function A.BarMetric(id)
    for _, metric in ipairs(A.barMetrics) do
        if metric[1] == id then
            return metric
        end
    end
end

--- Return a fresh bounded preset; durations default to lifetime/class time, not the native run clock.
function A.BarPreset(name)
    local scope = name == "class" and "current" or "all"
    local blocks = { { metric = "runs", scope = scope }, { metric = "wins", scope = scope } }
    if name ~= "compact" then
        table.insert(blocks, { metric = "duration", scope = scope })
        table.insert(blocks, { metric = "kills", scope = scope })
    end
    if name == "journey" then
        table.insert(blocks, { metric = "bosses", scope = scope })
    end
    return {
        version = 1,
        width = name == "compact" and 380 or 820,
        height = 46,
        opacity = 1,
        textSize = 12,
        icons = true,
        labels = true,
        locked = false,
        blocks = blocks,
    }
end

--- Normalize stored/editor preferences into a new plain tree without touching stats or source input.
function A.NormalizeBar(value)
    local defaults = A.BarPreset("journey")
    if type(value) ~= "table" or value.version ~= 1 then
        return defaults
    end
    local result = { version = 1, blocks = {} }
    for _, range in ipairs({
        { "width", 240, 1600 },
        { "height", 28, 96 },
        { "opacity", 0.45, 1 },
        { "textSize", 11, 16 },
    }) do
        result[range[1]] =
            math.max(range[2], math.min(range[3], A.Number(value[range[1]]) or defaults[range[1]]))
    end
    for _, key in ipairs({ "icons", "labels", "locked" }) do
        if type(value[key]) == "boolean" then
            result[key] = value[key]
        else
            result[key] = defaults[key]
        end
    end
    if type(value.blocks) == "table" then
        for index = 1, math.min(8, table.getn(value.blocks)) do
            local block = value.blocks[index]
            if type(block) == "table" then
                local metric = A.BarMetric(block.metric)
                local scope = block.scope
                if
                    metric
                    and (
                        scope == "all"
                        or scope == "current"
                        or scope == "class"
                        or (scope == "run" and metric[5])
                    )
                then
                    local class = scope == "class" and block.class or nil
                    if
                        scope ~= "class"
                        or (
                            type(class) == "string"
                            and A.knownClasses[class]
                            and class ~= "unknown"
                        )
                    then
                        table.insert(
                            result.blocks,
                            { metric = metric[1], scope = scope, class = class }
                        )
                    end
                end
            end
        end
    end
    if table.getn(result.blocks) == 0 then
        result.blocks = defaults.blocks
    end
    return result
end

--- Resolve the native current character class independently from a selected historical run/view filter.
function A.BarClass(block)
    if block.scope == "class" then
        return block.class
    end
    local _, class = A.Identity()
    return class
end

--- Describe block provenance visibly, including mixed-scope configurations.
function A.BarScope(block)
    if block.scope == "run" then
        return A.T("Current run")
    end
    if block.scope == "all" then
        return A.T("All classes")
    end
    local name = A.ClassName(A.BarClass(block))
    return block.scope == "current" and (A.T("Current class") .. " · " .. name) or name
end

--- Read an existing counter/record; absence remains nil and no history is reconstructed from pruned rows.
function A.BarValue(block)
    local key, value, coverage, partial = block.metric
    if block.scope == "run" then
        local run = A.run
        if run and run.status == "active" then
            value = run.values and run.values[key]
            partial = run.partial or run.spellSourcesTruncated
        end
    else
        local group = block.scope == "all" and A.db.totals or A.db.classes[A.BarClass(block)]
        if group then
            if key == "runs" or key == "wins" then
                value = group[key] or 0
            elseif key == "level" or key == "peakDps" then
                value = group.records and group.records[key] and group.records[key].value
            else
                value = group.sum and group.sum[key]
            end
            coverage = group.coverage and group.coverage[key]
            partial = group.usageTruncated
                or group.spellSourcesTruncated
                or (coverage and coverage < (group.runs or 0))
        elseif A.BarClass(block) ~= "unknown" then
            if key == "runs" or key == "wins" then
                value = 0
            end
        end
    end
    return A.Number(value), partial, coverage
end

--- Build one immutable HUD description with a precision-preserving tooltip and explicit scope.
function A.BarBlockModel(block)
    local metric = A.BarMetric(block.metric)
    local value, partial = A.BarValue(block)
    local label = A.BarLabel(metric)
    local formatted = block.metric == "duration" and A.Duration(value) or A.Short(value)
    return {
        label = label,
        value = formatted,
        exact = block.metric == "duration" and A.Duration(value) or A.Format(value),
        scope = A.BarScope(block),
        icon = metric[3],
        partial = partial,
        detail = A.T(
            block.scope == "run" and "Values from available samples"
                or "Collected since installation"
        ) .. (block.metric == "peakDps" and (" · " .. A.T(
            "Server-sample run average (10s+)"
        )) or ""),
        block = block,
        tab = metric[4],
    }
end

--- Fit at most eight blocks into one/two rows; overflow stays explicit instead of shrinking text invisibly.
function A.BarLayout(config, availableWidth)
    local width = math.min(config.width, math.max(160, availableWidth - 16))
    local rows = config.height >= 72 and 2 or 1
    local minimum = config.labels and 142 or 104
    local columns = math.max(1, math.floor((width - 68) / minimum))
    local count = table.getn(config.blocks)
    local capacity = math.min(count, columns * rows)
    local overflow = count > capacity
    if overflow then
        columns = math.max(1, math.floor((width - 96) / minimum))
        capacity = math.min(count, columns * rows)
    end
    return {
        width = width,
        height = config.height,
        rows = rows,
        columns = math.min(columns, math.max(1, math.ceil(capacity / rows))),
        capacity = capacity,
        overflow = count - capacity,
    }
end

--- Open the matching local view while preserving the block's class/run scope.
function A.OpenBarBlock(block)
    local metric = A.BarMetric(block.metric)
    A.view.class = nil
    if block.scope ~= "all" and block.scope ~= "run" then
        A.view.class = A.BarClass(block)
    end
    A.view.selected = nil
    A.view.page = 1
    A.view.tab = metric[4]
    A.view.cumulative = block.scope ~= "run"
    if block.scope == "run" then
        if not A.run or A.run.status ~= "active" then
            A.view.tab = 7
        else
            A.view.tab = 4
        end
    end
    if A.view.tab == 4 then
        A.view.mode = block.metric == "taken" and "taken"
            or (block.metric == "healing" and "healing" or "damage")
        A.view.combatTab = "Spells"
        if
            block.scope == "run"
            and block.metric ~= "damage"
            and block.metric ~= "healing"
            and block.metric ~= "taken"
        then
            A.view.combatTab = "Activity"
        end
    end
    A.ToggleUI(true)
end

--- Reuse audited native/localized metric labels rather than duplicating game translations.
function A.BarLabel(metric)
    if metric[1] == "runs" or metric[1] == "wins" or metric[1] == "duration" then
        return A.T(metric[2])
    end
    return A.Metric(metric[1])
end

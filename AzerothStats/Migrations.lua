-- Schema-1 compatibility migrations, deliberately kept for existing players.
-- One-time markers prevent repeated changes; legacy values remain available for audit.

-- Compatibility migrations for schema-1 saves. Never remove without a supported upgrade path.
local A = AzerothStats

--- Quarantine legacy chest-price values and rebuild retained exact chest counts once from final summaries.
function A.CorrectChests()
    local d = A.db
    d.migrations = d.migrations or {}
    if d.migrations.chestPrice13 then
        return
    end
    local groups = { d.totals }
    for _, g in pairs(d.classes) do
        table.insert(groups, g)
    end
    for _, g in ipairs(groups) do
        g.legacyChest13 = {
            sum = g.sum and g.sum.chests,
            coverage = g.coverage and g.coverage.chests,
            record = g.records and g.records.chests,
        }
        if g.sum then
            g.sum.chests = nil
        end
        if g.coverage then
            g.coverage.chests = nil
        end
        if g.records then
            g.records.chests = nil
        end
    end
    for _, r in ipairs(d.runs) do
        r.legacyChestPrice13 = r.values.chests
        local value = r.summary and A.Number(r.summary.chests)
        r.values.chests = value
        r.accounted.chests = value
        if value then
            for _, g in ipairs({ d.totals, d.classes[r.class] or {} }) do
                g.sum = g.sum or {}
                g.coverage = g.coverage or {}
                g.records = g.records or {}
                g.sum.chests = (g.sum.chests or 0) + value
                g.coverage.chests = (g.coverage.chests or 0) + 1
                if not g.records.chests or value > g.records.chests.value then
                    g.records.chests = { value = value, id = r.id, at = r.startedAt }
                end
            end
        end
    end
    d.migrations.chestPrice13 = { version = A.version, pruned = d.pruned or 0 }
end

--- Merge legacy accessory rank variants per retained run; archive previous aggregate entries once.
function A.NormalizeJewelry()
    local d = A.db
    d.migrations = d.migrations or {}
    if d.migrations.jewelry14 then
        return
    end
    local groups = { d.totals }
    for _, g in pairs(d.classes) do
        table.insert(groups, g)
    end
    for _, g in ipairs(groups) do
        g.usage = g.usage or {}
        g.legacyJewelry14 = g.usage.jewelry
        g.usage.jewelry = {}
    end
    for _, r in ipairs(d.runs) do
        local u = r.usage
        if u and u.jewelry then
            local old = u.jewelry
            local merged = {}
            local mapped = {}
            for key, e in pairs(old) do
                local canonical, name =
                    A.JewelKey(e.link or ("[" .. tostring(e.name or key) .. "]"), r.class)
                mapped[key] = canonical
                local out = merged[canonical]
                if not out then
                    out = { name = name, changes = 0 }
                    merged[canonical] = out
                end
                out.changes = out.changes + (e.changes or 0)
                out.link = e.link
                out.tooltip = e.tooltip or out.tooltip
                out.icon = e.icon or out.icon
                out.slot = e.slot
            end
            -- Prefer the last observed slot's description over arbitrary hash-table iteration order.
            for _, slot in pairs(u.slots or {}) do
                local entry = old[slot.key]
                local key = mapped[slot.key]
                if entry and key then
                    local out = merged[key]
                    out.link = entry.link
                    out.tooltip = entry.tooltip or out.tooltip
                    out.icon = entry.icon or out.icon
                end
                if key then
                    slot.key = key
                end
            end
            u.jewelry = merged
            u.accounted = u.accounted or {}
            u.accounted.jewelry = {}
            if not d.classes[r.class] then
                d.classes[r.class] = {}
            end
            for key, e in pairs(merged) do
                A.AccountUsage(r, "jewelry", key, e)
            end
        end
        if not r.zone and r.summary and type(r.summary.zone) == "string" then
            r.zone = r.summary.zone
        end
    end
    d.migrations.jewelry14 = { version = A.version, pruned = d.pruned or 0 }
end

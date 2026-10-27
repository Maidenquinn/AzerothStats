-- Observed build popularity, rank gains and accessory changes.
-- The first observation is a baseline, not an inferred click/cast/loot selection.
-- Variant keys are canonicalized and admitted to bounded per-run/global ledgers.

local A = AzerothStats
A.jewelSlots = { 2, 11, 12, 13, 14 }

--- Read five native accessory slots into a stable equality marker; never change inventory.
function A.InventorySignature()
    local t = {}
    for _, slot in ipairs(A.jewelSlots) do
        if type(GetInventoryItemLink) == "function" then
            local ok, link = pcall(GetInventoryItemLink, "player", slot)
            if ok then
                t[slot] = link or ""
            end
        end
    end
    return A.Sign(t)
end

--- Normalize a localized accessory name/rank to a canonical key, preferring the observed class on collisions.
function A.JewelKey(link, class)
    local _, _, name = string.find(link or "", "%[(.-)%]")
    if not name then
        return nil
    end
    local _, _, base = string.find(name, "^(.-) [IVXLCDM]+$")
    name = base or name
    if not A.jewelKeys then
        A.jewelKeys = {}
        A.amuletPrefixes = {}
        for _, lang in pairs(A.gameText) do
            for k, v in pairs(lang) do
                if string.find(k, "^jewel%.") or string.find(k, "^amulet%.") then
                    A.jewelKeys[v] = k
                end
            end
            for _, prefix in ipairs({ "The Eternal Talisman", "The Reaper's Amulet" }) do
                if lang[prefix] then
                    table.insert(
                        A.amuletPrefixes,
                        { label = lang[prefix], kind = prefix, lang = lang }
                    )
                end
            end
        end
    end
    if A.jewelKeys[name] then
        return A.jewelKeys[name], name
    end
    if not class then
        local _, file = A.Call(UnitClass, "player")
        class = string.lower(tostring(file or ""))
    end
    for _, prefix in ipairs(A.amuletPrefixes) do
        if string.sub(name, 1, string.len(prefix.label)) == prefix.label then
            local ability =
                string.gsub(string.sub(name, string.len(prefix.label) + 1), "^%s*:%s*", "")
            local known, unknown, knownCount, unknownCount = nil, nil, 0, 0
            for key, value in pairs(prefix.lang) do
                if
                    value == ability
                    and string.find(key, "^ability%.")
                    and string.find(key, "%.name$")
                then
                    local owner = A.abilityClasses[string.sub(key, 9, -6)]
                    if owner == class then
                        known = key
                        knownCount = knownCount + 1
                    elseif not owner then
                        unknown = key
                        unknownCount = unknownCount + 1
                    end
                end
            end
            -- Prefer the character's known ability over an identically translated ability
            -- whose class is not in the static index (e.g. Portuguese Retalhar).
            local selected = knownCount == 1 and known
                or (knownCount == 0 and unknownCount == 1 and unknown)
            if selected then
                return (prefix.kind == "The Eternal Talisman" and "eternal:" or "reaper:")
                    .. selected,
                    name
            end
        end
    end
    -- Synthetic inventory IDs are reused. The base name is safer than the numeric link ID.
    return "name:" .. name, name
end

--- Resolve a canonical accessory key back to its localized display name.
function A.JewelName(key, fallback)
    local prefix = string.sub(key, 1, 8) == "eternal:" and "The Eternal Talisman"
        or (string.sub(key, 1, 7) == "reaper:" and "The Reaper's Amulet")
    if prefix then
        local _, _, ability = string.find(key, "^[^:]+:(.+)$")
        return (A.G(prefix) or prefix) .. ": " .. (A.G(ability) or fallback or "?")
    end
    return A.G(key) or fallback
end

--- Apply one entry delta globally and per class, then save the run ledger; cap new aggregate keys.
function A.AccountUsage(run, kind, key, entry)
    local usage = run.usage
    usage.accounted = usage.accounted or {}
    usage.accounted[kind] = usage.accounted[kind] or {}
    local old = usage.accounted[kind][key] or {}
    for _, group in ipairs({ A.db.totals, A.db.classes[run.class] }) do
        group.usage = group.usage or {}
        group.usage[kind] = group.usage[kind] or {}
        if A.Admit(group.usage[kind], key, A.limits.usageKeys, group, "usageTruncated") then
            local rec = group.usage[kind][key] or { runs = 0, gains = 0, changes = 0, maxRank = 0 }
            if not old.seen then
                rec.runs = rec.runs + 1
            end
            rec.gains = rec.gains + (entry.gains or 0) - (old.gains or 0)
            rec.changes = rec.changes + (entry.changes or 0) - (old.changes or 0)
            rec.maxRank = math.max(rec.maxRank, entry.maxRank or 0)
            rec.name = entry.name
            rec.spell = entry.spell
            rec.link = entry.link
            rec.tooltip = entry.tooltip
            rec.icon = entry.icon
            group.usage[kind][key] = rec
        end
    end
    usage.accounted[kind][key] =
        { seen = true, gains = entry.gains or 0, changes = entry.changes or 0 }
end

--- Observe bounded spell ranks/accessory descriptions and update their ledgers without inferring clicks.
function A.ObserveBuild(run)
    if not A.db.classes[run.class] then
        A.db.classes[run.class] = {}
    end
    run.usage = run.usage or { spells = {}, jewelry = {}, slots = {} }
    local usage = run.usage
    local fresh = not run.spellsBaseline
        or A.Sign(A.Copy(AZS_SPELLS)) ~= run.spellsBaseline
        or A.spellPacket
    if fresh and type(AZS_SPELLS) == "table" then
        for i = 1, math.min(table.getn(AZS_SPELLS), 256) do
            local spell = AZS_SPELLS[i]
            local rank = type(spell) == "table" and A.Number(spell.rank)
            if
                type(spell) == "table"
                and type(spell.key) == "string"
                and string.len(spell.key) <= 80
                and string.find(spell.key, "^[%w_%-]+$")
                and rank
                and rank > 0
                and rank == math.floor(rank)
                and A.Admit(usage.spells, spell.key, A.limits.usageKeys, run, "usageTruncated")
            then
                local entry = usage.spells[spell.key]
                if not entry then
                    entry = {
                        name = spell.key,
                        spell = A.Number(spell.spell),
                        maxRank = rank,
                        lastRank = rank,
                        gains = 0,
                    }
                    usage.spells[spell.key] = entry
                else
                    if rank > entry.maxRank then
                        entry.gains = entry.gains + rank - entry.maxRank
                    end
                    entry.lastRank = rank
                    entry.maxRank = math.max(entry.maxRank, rank)
                end
                A.AccountUsage(run, "spells", spell.key, entry)
            end
        end
        if table.getn(AZS_SPELLS) > 256 then
            run.usageTruncated = true
        end
    end
    local inventory = A.InventorySignature()
    if not run.inventoryBaseline or inventory ~= run.inventoryBaseline then
        for _, slot in ipairs(A.jewelSlots) do
            local ok, link = false, nil
            if type(GetInventoryItemLink) == "function" then
                ok, link = pcall(GetInventoryItemLink, "player", slot)
            end
            if ok and type(link) == "string" then
                local key, name = A.JewelKey(link, run.class)
                if
                    key and A.Admit(usage.jewelry, key, A.limits.usageKeys, run, "usageTruncated")
                then
                    local lines = A.CaptureItem(slot)
                    local sig = A.Sign(lines or link)
                    local entry = usage.jewelry[key]
                    if not entry then
                        entry = { name = name, changes = 0 }
                        usage.jewelry[key] = entry
                    end
                    local old = usage.slots[slot]
                    if old and (old.key ~= key or old.sig ~= sig) then
                        entry.changes = entry.changes + 1
                    end
                    entry.link = A.PrefixText(link, 500)
                    entry.tooltip = lines or entry.tooltip
                    entry.slot = slot
                    if type(GetInventoryItemTexture) == "function" then
                        local good, ic = pcall(GetInventoryItemTexture, "player", slot)
                        if good then
                            entry.icon = A.TexturePath(ic)
                        end
                    end
                    usage.slots[slot] = { key = key, sig = sig }
                    A.AccountUsage(run, "jewelry", key, entry)
                end
            elseif ok then
                usage.slots[slot] = { key = "", sig = "" }
            end
        end
    end
    A.spellPacket = nil
end

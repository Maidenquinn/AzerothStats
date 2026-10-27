-- Input and persistence contracts. Pure Lua checks; no I/O or gameplay actions.
-- Reject invalid shapes before any migration or call into a native widget parser.

-- Input contracts shared by readers, persistence and presentation.
-- This module performs no I/O and never modifies AZS_* or third-party globals.
local A = AzerothStats
A.limits = {
    packetBytes = 65536,
    textBytes = 500,
    meterRows = 256,
    usageKeys = 512,
    spellSources = 1024,
    copyNodes = 8192,
    savedNodes = 4000000,
    savedDepth = 32,
}
A.knownClasses = {
    warrior = true,
    paladin = true,
    hunter = true,
    rogue = true,
    priest = true,
    shaman = true,
    mage = true,
    warlock = true,
    druid = true,
    unknown = true,
}
A.knownPhases = {
    ready = true,
    playing = true,
    choosing = true,
    paused = true,
    levelup = true,
    dead = true,
    victory = true,
    endless = true,
}
-- Convert an external label to bounded plain text. UI-owned color strings and
-- validated inventory links take separate paths; external texture/link escapes do not.

--- Bound an external label and remove control/texture/link markup before it becomes ordinary UI text.
function A.Text(value, limit)
    if type(value) ~= "string" then
        return nil
    end
    value = A.PrefixText(value, limit or A.limits.textBytes)
    value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
    value = string.gsub(value, "|r", "")
    value = string.gsub(value, "|H.-|h(.-)|h", "%1")
    value = string.gsub(value, "|T.-|t", "")
    -- Explicit ASCII controls: locale-dependent %c can classify UTF-8 continuation
    -- bytes as Windows C1 controls and corrupt otherwise valid CJK names.
    value = string.gsub(value, "[%z\001-\031\127|]", "")
    return value
end
-- Native texture loading is restricted to the client's Interface namespace.
-- Reject OS paths, URL schemes, parent traversal and embedded font-string markup.

--- Accept only bounded Interface texture paths; reject traversal, URL/OS prefixes and markup.
function A.TexturePath(value)
    if type(value) ~= "string" or string.len(value) > 240 then
        return nil
    end
    value = string.gsub(value, "/", "\\")
    if string.find(value, "..", 1, true) or string.find(value, "[^%w_\\%.%-]") then
        return nil
    end
    if not string.find(value, "\\", 1, true) then
        value = "Interface\\Icons\\" .. value
    end
    if string.lower(string.sub(value, 1, 10)) ~= "interface\\" then
        return nil
    end
    return value
end
-- Only item identifiers are handed to SetHyperlink. A colored display link may
-- still be shown as text, but cannot choose a different native hyperlink handler.

--- Extract a numeric item payload; all other hyperlink handlers are rejected.
function A.ItemLink(value)
    if type(value) ~= "string" or string.len(value) > 500 then
        return nil
    end
    local payload = value
    if string.sub(payload, 1, 5) ~= "item:" then
        local first, last, found = string.find(payload, "|H(item:[%d:%-]+)|h%[[^%c|]*%]|h")
        if not first then
            return nil
        end
        local prefix = string.sub(payload, 1, first - 1)
        local suffix = string.sub(payload, last + 1)
        if prefix ~= "" and not string.find(prefix, "^|c%x%x%x%x%x%x%x%x$") then
            return nil
        end
        if suffix ~= "" and suffix ~= "|r" then
            return nil
        end
        payload = found
    end
    if not string.find(payload, "^item:%d+[:%d%-]*$") then
        return nil
    end
    return payload
end
-- Frame anchors and coordinates are data, not arbitrary native API arguments.

--- Return a safe four-field frame position, or nil so the caller uses its default anchor.
function A.FramePosition(value)
    local anchors = {
        TOP = true,
        BOTTOM = true,
        LEFT = true,
        RIGHT = true,
        CENTER = true,
        TOPLEFT = true,
        TOPRIGHT = true,
        BOTTOMLEFT = true,
        BOTTOMRIGHT = true,
    }
    if type(value) ~= "table" or not anchors[value[1]] or not anchors[value[2]] then
        return nil
    end
    for i = 3, 4 do
        if type(value[i]) ~= "number" or value[i] ~= value[i] or math.abs(value[i]) > 1000000 then
            return nil
        end
    end
    return { value[1], value[2], value[3], value[4] }
end
-- A bounded admission check for dictionaries that grow over several games.
-- Existing keys remain updatable when the cap is reached; new keys are skipped.

--- Allow existing dictionary keys or a bounded new key; flag the owner when capacity is reached.
function A.Admit(map, key, limit, owner, flag)
    if map[key] ~= nil then
        return true
    end
    local count = 0
    for _ in pairs(map) do
        count = count + 1
        if count >= limit then
            if owner then
                owner[flag or "truncated"] = true
            end
            return false
        end
    end
    return true
end
-- Validate an already-loaded SavedVariables tree BEFORE migration or writes.
-- This is corruption handling, not a sandbox for an untrusted .lua save: the
-- client evaluates SavedVariables before the addon receives the resulting table.

--- Validate loaded data before mutation. Return false and preserve the original tree on corruption.
function A.ValidateDatabase(database)
    local budget = A.limits.savedNodes
    local visiting, checked = {}, {}

    --- Check a plain-data tree with shared cycle, depth and node guards; shared references are allowed.
    local function visit(value, depth)
        budget = budget - 1
        if budget < 0 or depth > A.limits.savedDepth then
            return false
        end
        local kind = type(value)
        if kind == "nil" or kind == "boolean" or kind == "string" then
            return true
        end
        if kind == "number" then
            return value == value and math.abs(value) < 1e100
        end
        if kind ~= "table" or getmetatable(value) ~= nil or visiting[value] then
            return false
        end
        if checked[value] then
            return true
        end
        visiting[value] = true
        for key, child in pairs(value) do
            if type(key) ~= "string" and type(key) ~= "number" then
                return false
            end
            if not visit(key, depth + 1) or not visit(child, depth + 1) then
                return false
            end
        end
        visiting[value] = nil
        checked[value] = true
        return true
    end
    if not visit(database, 0) then
        return false
    end
    if type(database) ~= "table" or database.schema ~= A.schema then
        return false
    end
    for _, name in ipairs({ "runs", "settings", "totals", "classes" }) do
        if type(database[name]) ~= "table" then
            return false
        end
    end
    local sequence = A.Number(database.sequence)
    if not sequence or sequence ~= math.floor(sequence) then
        return false
    end
    if database.migrations ~= nil and type(database.migrations) ~= "table" then
        return false
    end

    --- Require present optional container fields to be tables while keeping old missing fields valid.
    local function optional(record, names)
        for _, name in ipairs(names) do
            if record[name] ~= nil and type(record[name]) ~= "table" then
                return false
            end
        end
        return true
    end

    --- Require optional numeric fields to be valid counters instead of accepting arithmetic-breaking strings.
    local function numbers(record, names)
        for _, name in ipairs(names) do
            if record[name] ~= nil and not A.Number(record[name]) then
                return false
            end
        end
        return true
    end

    --- Validate captured tooltip-line shapes and color channels before native AddLine calls.
    local function tooltip(lines)
        if type(lines) ~= "table" then
            return false
        end
        for _, line in ipairs(lines) do
            if
                type(line) ~= "table"
                or type(line.text) ~= "string"
                or (line.right ~= nil and type(line.right) ~= "string")
            then
                return false
            end
            for _, channel in ipairs({ "r", "g", "b" }) do
                if line[channel] ~= nil and (not A.Number(line[channel]) or line[channel] > 1) then
                    return false
                end
            end
        end
        return true
    end

    --- Validate build entries and their accounting ledger without rebuilding or deleting observations.
    local function usage(value)
        if not optional(value, { "spells", "jewelry", "slots", "accounted" }) then
            return false
        end
        for _, kind in ipairs({ "spells", "jewelry" }) do
            for key, entry in pairs(value[kind] or {}) do
                if
                    type(key) ~= "string"
                    or type(entry) ~= "table"
                    or not numbers(entry, { "runs", "gains", "changes", "maxRank", "lastRank" })
                then
                    return false
                end
                if entry.tooltip ~= nil and not tooltip(entry.tooltip) then
                    return false
                end
            end
        end
        for _, slot in pairs(value.slots or {}) do
            if type(slot) ~= "table" or type(slot.key) ~= "string" then
                return false
            end
        end
        for _, entries in pairs(value.accounted or {}) do
            if type(entries) ~= "table" then
                return false
            end
            for _, entry in pairs(entries) do
                if type(entry) ~= "table" or not numbers(entry, { "gains", "changes" }) then
                    return false
                end
            end
        end
        return true
    end

    --- Validate one saved observed-player record; it remains a name/class observation, not an account ID.
    local function peer(entry)
        return type(entry) == "table"
            and type(entry.name) == "string"
            and type(entry.class) == "string"
            and numbers(entry, { "damage", "dps", "topdps", "lastSeen", "firstSeen" })
    end

    --- Validate the dictionaries that dashboards and accounting will read at startup.
    local function aggregate(group)
        if
            type(group) ~= "table"
            or not optional(
                group,
                { "sum", "coverage", "records", "spells", "usage", "companions", "deathEvidence" }
            )
        then
            return false
        end
        for _, name in ipairs({ "sum", "coverage" }) do
            for _, value in pairs(group[name] or {}) do
                if not A.Number(value) then
                    return false
                end
            end
        end
        for _, record in pairs(group.records or {}) do
            if type(record) ~= "table" or not A.Number(record.value) then
                return false
            end
        end
        if group.spells then
            for _, rows in pairs(group.spells) do
                if type(rows) ~= "table" then
                    return false
                end
                for _, value in pairs(rows) do
                    if not A.Number(value) then
                        return false
                    end
                end
            end
        end
        if group.usage and not usage(group.usage) then
            return false
        end
        for _, entry in pairs(group.companions or {}) do
            if not peer(entry) or not A.Number(entry.runs) or not A.Number(entry.wins) then
                return false
            end
        end
        if group.deathEvidence then
            local evidence = group.deathEvidence
            if not A.Number(evidence.deaths) or type(evidence.sources) ~= "table" then
                return false
            end
            for _, source in pairs(evidence.sources) do
                if
                    type(source) ~= "table"
                    or not A.Number(source.confirmed)
                    or not A.Number(source.probable)
                then
                    return false
                end
            end
        end
        return true
    end
    if not aggregate(database.totals) then
        return false
    end
    for class, group in pairs(database.classes) do
        if type(class) ~= "string" or not aggregate(group) then
            return false
        end
    end
    for _, run in ipairs(database.runs) do
        if type(run) ~= "table" or type(run.id) ~= "string" or type(run.class) ~= "string" then
            return false
        end
        if
            run.heroic ~= nil and (type(run.heroic) ~= "number" or not A.HeroicLevel(run.heroic))
        then
            return false
        end
        if run.recordBaseline ~= nil then
            if
                type(run.recordBaseline) ~= "table"
                or type(run.recordBaseline.values) ~= "table"
            then
                return false
            end
            for key, value in pairs(run.recordBaseline.values) do
                if type(key) ~= "string" or not A.Number(value) then
                    return false
                end
            end
        end
        if run.reportRecords ~= nil then
            if type(run.reportRecords) ~= "table" then
                return false
            end
            for key, value in pairs(run.reportRecords) do
                if type(key) ~= "string" or not A.Number(value) then
                    return false
                end
            end
        end
        for _, name in ipairs({ "values", "accounted", "events", "meters" }) do
            if type(run[name]) ~= "table" then
                return false
            end
        end
        if
            not optional(run, {
                "timeline",
                "summary",
                "progress",
                "usage",
                "coop",
                "equipment",
                "equipmentIcons",
                "equipmentTooltips",
                "deaths",
                "spells",
                "stats",
                "unavailable",
            })
        then
            return false
        end
        for _, name in ipairs({ "values", "accounted" }) do
            for _, value in pairs(run[name]) do
                if not A.Number(value) then
                    return false
                end
            end
        end
        for _, meter in pairs(run.meters) do
            if
                type(meter) ~= "table"
                or type(meter.rows) ~= "table"
                or not A.Number(meter.total)
            then
                return false
            end
            for _, row in ipairs(meter.rows) do
                if type(row) ~= "table" or not A.Number(row.dmg) then
                    return false
                end
            end
        end
        if run.usage and not usage(run.usage) then
            return false
        end
        for _, entry in ipairs(run.spells or {}) do
            if
                type(entry) ~= "table"
                or type(entry.key) ~= "string"
                or not A.Number(entry.rank)
            then
                return false
            end
        end
        for _, entry in ipairs(run.timeline or {}) do
            if type(entry) ~= "table" or not numbers(entry, { "t", "level", "kills", "gold" }) then
                return false
            end
        end
        for _, entry in ipairs(run.events) do
            if
                type(entry) ~= "table"
                or type(entry.kind) ~= "string"
                or (entry.text ~= nil and type(entry.text) ~= "string")
            then
                return false
            end
        end
        for slot, link in pairs(run.equipment or {}) do
            if type(slot) ~= "number" or type(link) ~= "string" then
                return false
            end
        end
        for _, lines in pairs(run.equipmentTooltips or {}) do
            if not tooltip(lines) then
                return false
            end
        end
        for _, death in ipairs(run.deaths or {}) do
            if
                type(death) ~= "table"
                or not optional(death, { "hits", "unparsed" })
                or (death.source ~= nil and type(death.source) ~= "string")
            then
                return false
            end
            for _, hit in ipairs(death.hits or {}) do
                if type(hit) ~= "table" or not numbers(hit, { "amount", "at", "age" }) then
                    return false
                end
            end
        end
        if
            run.coop
            and (
                type(run.coop.peers) ~= "table"
                or type(run.coop.latest) ~= "table"
                or type(run.coop.accounted) ~= "table"
            )
        then
            return false
        end
        if run.coop then
            for _, entry in pairs(run.coop.peers) do
                if not peer(entry) then
                    return false
                end
            end
            for _, entry in ipairs(run.coop.latest) do
                if not peer(entry) then
                    return false
                end
            end
            for _, entry in pairs(run.coop.accounted) do
                if type(entry) ~= "table" then
                    return false
                end
            end
            if run.coop.comparison then
                local sample = run.coop.comparison
                if type(sample) ~= "table" or type(sample.rows) ~= "table" then
                    return false
                end
                for _, entry in ipairs(sample.rows) do
                    if not peer(entry) then
                        return false
                    end
                end
            end
        end
    end
    local favorites = database.favorites
    if favorites ~= nil then
        if
            type(favorites) ~= "table"
            or favorites.version ~= 1
            or type(favorites.entries) ~= "table"
        then
            return false
        end
        local kinds = { run = true, spell = true, item = true, jewelry = true, companion = true }
        for id, entry in pairs(favorites.entries) do
            if
                type(id) ~= "string"
                or type(entry) ~= "table"
                or not kinds[entry.kind]
                or type(entry.key) ~= "string"
                or type(entry.label) ~= "string"
                or (entry.at ~= nil and not A.Number(entry.at))
            then
                return false
            end
            if
                entry.display ~= nil
                and (
                    type(entry.display) ~= "table"
                    or (entry.display.tooltip ~= nil and not tooltip(entry.display.tooltip))
                )
            then
                return false
            end
        end
    end
    return true
end

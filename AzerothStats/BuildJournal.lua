-- Sampled build observations, never a native card-selection/bonus attribution API.
-- Cooldown movement is excluded. Known numeric snapshots are kept separately from missing data.
local A = AzerothStats
A.journalStats = {
    { "hp", "Health", 1, 0 },
    { "dmg", "Damage", 100, 1 },
    { "cd", "Haste", -100, 1 },
    { "crit", "Crit", 100, 0 },
    { "cm", "Crit Dmg", 100, 0 },
    { "arm", "Armor", 100, 0 },
    { "reg", "Regen", 1, 0 },
    { "area", "Area", 100, 1 },
    { "cnt", "Targets", 1, 0 },
    { "spd", "Speed", 100, 1 },
    { "xp", "Experience", 100, 1 },
    { "luck", "Luck", 100, 0 },
    { "gold", "Gold", 100, 1 },
    { "heal", "Kill Heal", 1, 0 },
    { "lch", "Lifesteal", 100, 0 },
}

--- Only NEW runs get an initial observer; enabling mid-run remains partial.
function A.BeginJournal(run)
    run.buildJournal = { version = 1, entries = {}, last = {}, partial = run.partial == true }
end

--- Read complete bounded rank maps only when the native spell state is fresh.
local function ranks(run)
    if
        run.spellsBaseline
        and A.Sign(A.Copy(AZS_SPELLS)) == run.spellsBaseline
        and not A.spellPacket
    then
        return nil
    end
    if type(AZS_SPELLS) ~= "table" or getmetatable(AZS_SPELLS) then
        return nil
    end
    if table.getn(AZS_SPELLS) > 32 then
        run.buildJournal.partial = true
        return nil
    end
    local result = {}
    for _, item in ipairs(AZS_SPELLS) do
        if type(item) ~= "table" or getmetatable(item) then
            run.buildJournal.partial = true
            return nil
        end
        local rank = A.Number(item.rank)
        if
            type(item) ~= "table"
            or type(item.key) ~= "string"
            or string.len(item.key) > 80
            or not string.find(item.key, "^[%w_%-]+$")
            or not rank
            or rank ~= math.floor(rank)
            or rank > 10000
            or result[item.key] ~= nil
        then
            run.buildJournal.partial = true
            return nil
        end
        result[item.key] = rank
    end
    return result
end

--- Read a fixed numeric global-stat whitelist; unrelated nested/native data is ignored.
local function stats(run)
    if
        run.statsBaseline
        and A.Sign(A.Copy(AZS_STATS)) == run.statsBaseline
        and not A.statsPacket
    then
        return nil
    end
    if type(AZS_STATS) ~= "table" or getmetatable(AZS_STATS) then
        return nil
    end
    local result = {}
    for _, def in ipairs(A.journalStats) do
        local raw = AZS_STATS[def[1]]
        local number = A.Number(raw)
        if raw ~= nil and not number then
            run.buildJournal.partial = true
            return nil
        end
        if number then
            result[def[1]] = number
        end
    end
    if not next(result) then
        return nil
    end
    return result
end

--- Persist one bounded dimension change. Missing numbers never become zero/removals.
local function observe(run, kind, current)
    if not current then
        return
    end
    local journal = run.buildJournal
    local previous, changes = journal.last[kind], {}
    for key, number in pairs(current) do
        local before = previous and previous[key]
        if before ~= number then
            table.insert(changes, { key = key, before = before, after = number })
        end
    end
    if kind == "gear" and previous then
        for key, before in pairs(previous) do
            if current[key] == nil then
                table.insert(changes, { key = key, before = before })
            end
        end
    end
    table.sort(changes, function(a, b)
        return tostring(a.key) < tostring(b.key)
    end)
    if table.getn(changes) > 0 then
        local total = 0
        for _, entry in ipairs(journal.entries) do
            total = total + table.getn(entry.changes)
        end
        if
            not journal.truncated
            and table.getn(journal.entries) < 128
            and total + table.getn(changes) <= 256
        then
            table.insert(journal.entries, {
                kind = kind,
                initial = previous == nil,
                t = run.values.duration,
                level = run.values.level,
                phase = run.phase,
                changes = changes,
            })
        else
            journal.truncated = true
        end
    end
    journal.last[kind] = current
    return table.getn(changes) > 0
end

--- Called once per sampler BEFORE usage clears spell freshness. Gear uses the existing 15s snapshot.
function A.ObserveJournal(run)
    if
        run.status ~= "active"
        or (
            run.phase ~= "playing"
            and run.phase ~= "choosing"
            and run.phase ~= "paused"
            and run.phase ~= "endless"
            and run.phase ~= "levelup"
        )
    then
        return
    end
    if not run.buildJournal then
        A.BeginJournal(run)
        run.buildJournal.partial = true
    end
    local rankChanged = observe(run, "ranks", ranks(run))
    local gearChanged = false
    if run.snapshotAt ~= nil and run.buildJournal.gearAt ~= run.snapshotAt then
        local gear = {}
        for slot = 1, 19 do
            local link = run.equipment and run.equipment[slot]
            if type(link) == "string" and A.ItemLink(link) then
                gear[slot] = A.PrefixText(link, 500)
            end
        end
        gearChanged = observe(run, "gear", gear)
        run.buildJournal.gearAt = run.snapshotAt
    end
    local previousPhase = A.journalPhaseRun == run and A.journalPhase or nil
    local choosing = previousPhase == "choosing" or previousPhase == "levelup"
    local choiceExit = choosing and run.phase ~= "choosing" and run.phase ~= "levelup"
    local checkpoint = rankChanged or gearChanged or choiceExit
    if checkpoint then
        A.journalStatsWindow = { run = run, untilTime = GetTime() + 2 }
    end
    local window = A.journalStatsWindow
    local delayed = A.statsPacket and window and window.run == run and GetTime() <= window.untilTime
    if run.buildJournal.last.stats == nil or checkpoint or delayed then
        observe(run, "stats", stats(run))
    end
    -- Session-only phase state: saved schema stays compatible; reload does not invent a choice exit.
    A.journalPhaseRun, A.journalPhase = run, run.phase
end

--- Percentage-point changes of GLOBAL sampled stats, never the percentage rolled on a card.
function A.JournalChange(kind, change)
    local label, scale, offset = tostring(change.key), 1, 0
    if kind == "ranks" then
        label = A.SpellName({ key = change.key })
    elseif kind == "gear" then
        label = A.G("slot." .. (change.key - 1)) or (A.T("Slot") .. " " .. change.key)
    else
        for _, def in ipairs(A.journalStats) do
            if def[1] == change.key then
                label, scale, offset = A.G(def[2]) or def[2], def[3], def[4]
                break
            end
        end
    end
    local function display(number)
        if kind == "gear" then
            return number or A.T("Unavailable")
        end
        if number == nil then
            return A.T("Unavailable")
        end
        if kind == "ranks" then
            return A.Format(number)
        end
        return A.Decimal((number - offset) * scale, 2) .. (math.abs(scale) == 100 and "%" or "")
    end
    local text = label .. ": " .. display(change.before) .. " -> " .. display(change.after)
    if kind ~= "gear" and change.before ~= nil and change.after ~= nil then
        local delta = (change.after - change.before) * scale
        text = text
            .. " ("
            .. (delta > 0 and "+" or (delta < 0 and "-" or ""))
            .. (kind == "ranks" and A.Format(math.abs(delta)) or A.Decimal(math.abs(delta), 2))
            .. (math.abs(scale) == 100 and " pp" or "")
            .. ")"
    end
    return text
end

--- Report-only rows with full per-observation details on hover. No events/cards are reconstructed.
function A.JournalModel(model, run)
    local journal = run and run.buildJournal
    model.columnLabel, model.columnValue = A.T("Build journal"), A.T("Details")
    model.note = A.T("Observed changes, not card effects")
    model.subtitle = A.T("Observed build checkpoints")
    model.rowY, model.rowHeight = 390, 58
    model.emptyText = A.T("No build journal recorded")
    if not journal then
        return
    end
    if journal.partial then
        model.note = model.note .. " · " .. A.T("Partial")
    end
    if journal.truncated then
        model.note = model.note .. " · " .. A.T("Journal limit reached")
    end
    local captions = { ranks = "Rank changes", stats = "Stat changes", gear = "Equipment changes" }
    for i = table.getn(journal.entries), 1, -1 do
        local entry, lines = journal.entries[i], {}
        if not A.view.journalKind or A.view.journalKind == entry.kind then
            for _, change in ipairs(entry.changes) do
                table.insert(lines, A.JournalChange(entry.kind, change))
            end
            local caption = A.T(entry.initial and "Initial observed state" or captions[entry.kind])
            table.insert(model.rows, {
                label = A.Duration(entry.t) .. " · " .. caption,
                value = A.Format(table.getn(lines)) .. " · " .. A.T("Details"),
                detail = lines[1] or "",
                exact = table.concat(lines, "\n") .. "\n" .. A.T(
                    "Observed changes, not card effects"
                ) .. "\n" .. A.Metric("level") .. " " .. A.Format(entry.level),
                icon = entry.kind == "stats" and "INV_Misc_Gear_01" or "INV_Misc_Book_09",
            })
        end
    end
end

--- Saved optional metadata must remain bounded and typed before presentation/arithmetic.
function A.ValidateJournal(journal)
    local function keys(value, allowed)
        if type(value) ~= "table" or getmetatable(value) then
            return false
        end
        for key in pairs(value) do
            if not allowed[key] then
                return false
            end
        end
        return true
    end
    local function sequence(value, limit)
        if type(value) ~= "table" or getmetatable(value) then
            return false
        end
        local n, count = table.getn(value), 0
        if n > limit then
            return false
        end
        for key in pairs(value) do
            count = count + 1
            if
                count > limit
                or type(key) ~= "number"
                or key < 1
                or key > n
                or key ~= math.floor(key)
            then
                return false
            end
        end
        return count == n
    end
    if
        not keys(journal, {
            version = true,
            entries = true,
            last = true,
            partial = true,
            truncated = true,
            gearAt = true,
        }) or not sequence(journal.entries, 128)
    then
        return false
    end
    for _, flag in ipairs({ "partial", "truncated" }) do
        if journal[flag] ~= nil and type(journal[flag]) ~= "boolean" then
            return false
        end
    end
    if
        type(journal) ~= "table"
        or journal.version ~= 1
        or type(journal.entries) ~= "table"
        or type(journal.last) ~= "table"
        or table.getn(journal.entries) > 128
    then
        return false
    end
    local statKeys = {}
    for _, def in ipairs(A.journalStats) do
        statKeys[def[1]] = true
    end
    local function field(kind, key, number)
        if kind == "gear" then
            return type(key) == "number"
                and key >= 1
                and key <= 19
                and key == math.floor(key)
                and (
                    number == nil
                    or (
                        type(number) == "string"
                        and string.len(number) <= 500
                        and A.ItemLink(number) ~= nil
                    )
                )
        end
        if
            type(key) ~= "string"
            or string.len(key) > 80
            or (kind == "stats" and not statKeys[key])
            or (kind == "ranks" and not string.find(key, "^[%w_%-]+$"))
        then
            return false
        end
        if number == nil then
            return true
        end
        if type(number) ~= "number" then
            return false
        end
        local n = A.Number(number)
        return n ~= nil and (kind ~= "ranks" or (n <= 10000 and n == math.floor(n)))
    end
    for kind, values in pairs(journal.last) do
        if kind ~= "ranks" and kind ~= "stats" and kind ~= "gear" then
            return false
        end
        if type(values) ~= "table" then
            return false
        end
        local count = 0
        for key, number in pairs(values) do
            count = count + 1
            if count > 32 or not field(kind, key, number) then
                return false
            end
        end
    end
    local total = 0
    for _, entry in ipairs(journal.entries) do
        if
            not keys(entry, {
                kind = true,
                initial = true,
                t = true,
                level = true,
                phase = true,
                changes = true,
            })
            or type(entry.initial) ~= "boolean"
            or not sequence(entry.changes, 64)
            or (entry.phase ~= nil and not A.knownPhases[entry.phase])
        then
            return false
        end
        if
            type(entry) ~= "table"
            or (entry.kind ~= "ranks" and entry.kind ~= "stats" and entry.kind ~= "gear")
            or type(entry.changes) ~= "table"
            or table.getn(entry.changes) > 64
            or (entry.t ~= nil and not A.Number(entry.t))
            or (entry.level ~= nil and not A.Number(entry.level))
        then
            return false
        end
        total = total + table.getn(entry.changes)
        if total > 256 then
            return false
        end
        for _, change in ipairs(entry.changes) do
            if not keys(change, { key = true, before = true, after = true }) then
                return false
            end
            if
                type(change) ~= "table"
                or not field(entry.kind, change.key, change.before)
                or not field(entry.kind, change.key, change.after)
            then
                return false
            end
        end
    end
    return journal.gearAt == nil or A.Number(journal.gearAt) ~= nil
end

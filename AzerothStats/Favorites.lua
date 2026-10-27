-- Bounded local bookmark metadata and stable run references.
-- Callbacks are constructed by the addon UI, never persisted or read from packets.
-- Protected-run indexes are temporary and do not alter aggregate statistics.

local A = AzerothStats
A.favoriteCategories = {
    { "run", "History" },
    { "combat", "Combat" },
    { "spell", "Spells" },
    { "item", "Equipment" },
    { "jewelry", "Jewelry" },
    { "companion", "Co-op" },
}

--- Classify old combat spell bookmarks from their source tab without rewriting saved IDs.
function A.FavoriteCategory(entry)
    if entry.kind == "spell" and entry.tab == 4 then
        return "combat"
    end
    return entry.kind
end

--- Map a category key to its UI label, defaulting safely to History.
function A.FavoriteCategoryLabel(key)
    for _, c in ipairs(A.favoriteCategories) do
        if c[1] == key then
            return c[2]
        end
    end
    return "History"
end

--- Count categories under the current class filter; do not modify bookmark metadata.
function A.FavoriteCounts()
    local counts = {}
    for _, entry in pairs(A.db.favorites.entries) do
        if not A.view.class or entry.class == A.view.class then
            local key = A.FavoriteCategory(entry)
            counts[key] = (counts[key] or 0) + 1
        end
    end
    return counts
end

--- Build a temporary set of run IDs pinned directly or by historical combat references.
function A.ProtectedRunIds()
    local ids = {}
    for _, entry in pairs(A.db.favorites.entries) do
        local id = entry.kind == "run" and entry.key
            or (A.FavoriteCategory(entry) == "combat" and entry.runId)
        if id then
            ids[id] = true
        end
    end
    return ids
end

--- Check membership in the temporary protected-run set.
function A.IsRunProtected(id)
    return A.ProtectedRunIds()[id] == true
end
-- Build a temporary index for UI/navigation; it is never written to SavedVariables.

--- Build a temporary ID-to-run lookup so bookmark rendering does not repeatedly scan history.
function A.IndexRuns()
    local index = {}
    for _, run in ipairs(A.db.runs) do
        index[run.id] = run
    end
    return index
end
local kinds = { run = true, spell = true, jewelry = true, item = true, companion = true }

--- Compose a stable local kind/key bookmark ID; it is not a server identity.
function A.FavoriteId(kind, key)
    return kind .. ":" .. key
end

--- Check an own bookmark entry without mutating it.
function A.IsFavorite(kind, key)
    return A.db and A.db.favorites and A.db.favorites.entries[A.FavoriteId(kind, key)] ~= nil
end

--- Add/remove bounded data-only bookmark metadata; cap total bookmarks and distinct protected runs.
function A.ToggleFavorite(descriptor)
    if
        not descriptor
        or not kinds[descriptor.kind]
        or type(descriptor.key) ~= "string"
        or string.len(descriptor.key) > 600
    then
        return false
    end
    local entries = A.db.favorites.entries
    local id = A.FavoriteId(descriptor.kind, descriptor.key)
    if entries[id] then
        entries[id] = nil
        return false
    end
    local count, runs, protected = 0, 0, {}
    for _, entry in pairs(entries) do
        count = count + 1
        local id = entry.kind == "run" and entry.key
            or (A.FavoriteCategory(entry) == "combat" and entry.runId)
        if id and not protected[id] then
            protected[id] = true
            runs = runs + 1
        end
    end
    local pin = descriptor.kind == "run" and descriptor.key
        or (A.FavoriteCategory(descriptor) == "combat" and descriptor.runId)
    if count >= 300 or (pin and not protected[pin] and runs >= 200) then
        A.Say(A.T("Favorite limit reached"))
        return false
    end
    local saved = A.Copy(descriptor, 8)
    saved.key = descriptor.key
    saved.at = A.Wall()
    entries[id] = saved
    return true
end

--- Describe a run bookmark using its stable local ID and observed display metadata.
function A.RunFavorite(run)
    if not run then
        return nil
    end
    return {
        kind = "run",
        key = run.id,
        label = (run.hero or "?") .. " · " .. A.ClassName(run.class),
        class = run.class,
        runId = run.id,
        startedAt = run.startedAt,
        tab = 4,
        mode = "damage",
    }
end

--- Navigate through trusted own view state; a missing source run cannot open an unrelated game.
function A.OpenFavorite(entry)
    if entry.runId then
        local exists = false
        for _, run in ipairs(A.db.runs) do
            if run.id == entry.runId then
                exists = true
                break
            end
        end
        if not exists then
            A.Say(A.T("Source run no longer retained"))
            return
        end
    end
    if entry.kind == "run" then
        A.OpenReport(entry.key)
    elseif entry.kind == "companion" then
        A.view.tab = 9
        A.view.usageTab = "Co-op"
        A.view.cumulative = true
        A.view.coopPartner = entry.key
        A.view.class = nil
    else
        A.view.tab = entry.tab or 9
        A.view.mode = entry.mode or "damage"
        A.view.usageTab = entry.section or "Spells"
        A.view.characterTab = "Equipment"
        if entry.tab == 4 then
            A.view.cumulative = entry.cumulative ~= false
            A.view.combatTab = "Spells"
        else
            A.view.cumulative = entry.tab ~= 5
        end
        A.view.selected = entry.runId
        A.view.class = entry.class
    end
    A.view.page = 1
    A.view.focusFavorite = A.FavoriteId(entry.kind, entry.key)
    A.view.highlightFavorite = A.view.focusFavorite
end

--- Build one exclusive category, with exact source-run metadata where recorded.
function A.FavoritesModel(model)
    model.rowHeight = 46
    model.rowY = 200
    model.capacity = 8
    local category = A.view.favoriteCategory or "run"
    local sorted = {}
    local runs = A.IndexRuns()
    for _, entry in pairs(A.db.favorites.entries) do
        if
            A.FavoriteCategory(entry) == category
            and (not A.view.class or entry.class == A.view.class)
        then
            table.insert(sorted, entry)
        end
    end
    table.sort(sorted, function(x, y)
        if x.kind ~= y.kind then
            return x.kind < y.kind
        end
        return (x.at or 0) > (y.at or 0)
    end)
    for _, entry in ipairs(sorted) do
        local entry = entry
        local descriptor = A.Copy(entry.display or {})
        if entry.kind == "run" then
            local run = runs[entry.key]
            if run then
                descriptor.detail = A.Date(run.startedAt)
                    .. " · "
                    .. A.ClassName(run.class)
                    .. " · "
                    .. (run.hero or A.T("Unknown"))
                descriptor.value = A.Duration(run.values.duration)
                descriptor.runLabel = A.ZoneName(run)
                descriptor.zone, descriptor.result = run.zone, run.result or run.status
                descriptor.extra = A.Metric("level")
                    .. " "
                    .. A.Format(run.values.level)
                    .. " · "
                    .. A.Metric("kills")
                    .. " "
                    .. A.Short(run.values.kills)
            end
        end
        descriptor.label = descriptor.runLabel
            or entry.kind == "run" and (A.T("Run") .. " · " .. A.Date(entry.startedAt or entry.at))
            or entry.label
        if entry.kind == "spell" then
            descriptor.label = A.G("ability." .. entry.key .. ".name") or A.SourceName(entry.label)
        elseif entry.kind == "jewelry" then
            descriptor.label = A.JewelName(entry.key, entry.label)
        end
        if category == "combat" then
            local _, _, source =
                string.find(entry.key, entry.runId and "^[^:]+:[^:]+:(.+)$" or "^[^:]+:(.+)$")
            descriptor.label = A.SourceName(source or entry.label)
            descriptor.detail = A.ModeName(entry.mode or "damage") .. " · " .. A.T("All runs")
            descriptor.value = A.T("All runs")
            local run = entry.runId and runs[entry.runId]
            if run then
                descriptor.detail = A.Date(run.startedAt)
                    .. " · "
                    .. A.ClassName(run.class)
                    .. " · "
                    .. A.ZoneName(run)
                    .. " · "
                    .. A.ModeName(entry.mode or "damage")
                descriptor.value = A.Duration(run.values.duration)
            end
        end
        if descriptor.runLabel then
            local sourceRun = runs[entry.key]
            descriptor.extra = descriptor.extra .. " · " .. A.HeroicLabel(sourceRun)
        end
        descriptor.value = descriptor.value
            or A.T(
                category == "combat" and "Combat"
                    or entry.kind == "run" and "Run"
                    or entry.kind == "companion" and "Co-op"
                    or entry.kind == "spell" and "Spells"
                    or entry.kind == "jewelry" and "Jewelry"
                    or "Equipment"
            )
        descriptor.detail = descriptor.detail
            or (entry.class and A.ClassName(entry.class) .. " · " or "")
                .. A.T("Click to inspect")
        descriptor.favorite = entry
        descriptor.action = function()
            A.OpenFavorite(entry)
        end
        descriptor.class = entry.class or descriptor.class
        table.insert(model.rows, descriptor)
    end
    model.subtitle = A.T(A.FavoriteCategoryLabel(category))
        .. " · "
        .. A.Format(table.getn(sorted))
    model.note = A.T("Favorite runs are protected from history pruning")
    model.emptyText = A.T("No favorites in this category")
        .. "\n"
        .. A.T("Use the heart to save a favorite")
end

--- Attach data-only item bookmark descriptors to eligible presentation rows.
function A.DecorateFavorites(model, tab, run)
    for _, descriptor in ipairs(model.rows) do
        if not descriptor.favorite and descriptor.link then
            local _, _, id = string.find(descriptor.link, "item:(%d+)")
            local jewelKey, base
            if not descriptor.collection then
                jewelKey, base =
                    A.JewelKey(descriptor.link, descriptor.class or (run and run.class))
            end
            descriptor.favorite = {
                kind = descriptor.collection and "item" or "jewelry",
                key = descriptor.favoriteKey or jewelKey or id or descriptor.link,
                label = jewelKey and A.JewelName(jewelKey, base) or descriptor.label,
                class = descriptor.class or (run and run.class),
                tab = 5,
                runId = run and run.id,
                display = {
                    label = descriptor.label,
                    link = descriptor.link,
                    tooltip = descriptor.tooltip,
                    icon = descriptor.icon,
                    class = descriptor.class,
                    collection = descriptor.collection,
                },
            }
        end
    end
end

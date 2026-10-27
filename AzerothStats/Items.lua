-- Item-description capture and display through native read-only tooltip methods.
-- Only validated item: identifiers can reach SetHyperlink; links never execute code.
-- Static loot references are labeled separately from captured historical bonuses.

local A = AzerothStats

--- Capture at most 40 native tooltip lines as bounded text/color data; always hide the scanner afterward.
local function readLines(tip)
    local lines = {}
    local count = tip.NumLines and A.Number(tip:NumLines()) or 0
    for i = 1, math.min(count or 0, 40) do
        local left = getglobal("AzerothStatsItemScanTextLeft" .. i)
        local right = getglobal("AzerothStatsItemScanTextRight" .. i)
        local text = left and left:GetText()
        if type(text) == "string" and text ~= "" then
            local r, g, b = 1, 1, 1
            if left.GetTextColor then
                r, g, b = left:GetTextColor()
            end
            table.insert(lines, {
                text = A.Text(text, 1500),
                right = right and A.Text(right:GetText(), 1500),
                r = r,
                g = g,
                b = b,
            })
        end
    end
    tip:Hide()
    if table.getn(lines) > 0 then
        return lines
    end
end

--- Read an inventory slot or validated item link using one hidden scanner tooltip; never equip an item.
function A.CaptureItem(slot, link)
    if link then
        link = A.ItemLink(link)
        if not link then
            return nil
        end
    end
    if not A.itemTip then
        A.itemTip =
            CreateFrame("GameTooltip", "AzerothStatsItemScan", UIParent, "GameTooltipTemplate")
    end
    local tip = A.itemTip
    local ok = pcall(function()
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearLines()
        if link then
            tip:SetHyperlink(link)
        else
            tip:SetInventoryItem("player", slot)
        end
    end)
    if ok then
        return readLines(tip)
    end
    tip:Hide()
end

--- Return the numeric identifier from a validated item link, or nil for unsupported link types.
local function itemId(link)
    local safe = A.ItemLink(link)
    if not safe then
        return nil
    end
    local _, _, id = string.find(safe, "^item:(%d+)")
    return id
end

--- Find a newer static-item description by exact ID; it is explicitly a current reference.
function A.CollectionReference(link)
    local id = itemId(link)
    if not id then
        return nil
    end
    -- Old runs may lack descriptions: reuse a newer observation of this static collection item.
    for i = table.getn(A.db.runs), 1, -1 do
        local r = A.db.runs[i]
        for slot, value in pairs(r.equipment or {}) do
            if slot ~= 2 and (slot < 11 or slot > 14) and itemId(value) == id then
                local lines = r.equipmentTooltips and r.equipmentTooltips[slot]
                if lines and table.getn(lines) > 1 then
                    return lines
                end
            end
        end
    end
    local lines = A.CaptureItem(nil, link)
    if lines and table.getn(lines) > 1 then
        return lines
    end
end

--- Append static base loot references when a recognized collection item is displayed.
local function dropSources(descriptor)
    if not descriptor.collection then
        return
    end
    local _, _, name = string.find(descriptor.link or "", "%[(.-)%]")
    local aliases = A.collectionAliases[descriptor.class] or {}
    local canonical = aliases[name or ""] or name
    local sources = A.collectionSources[descriptor.class]
        and A.collectionSources[descriptor.class][canonical or ""]
    if not sources then
        return
    end
    GameTooltip:AddLine(A.T("Loot catalog"), 0.9, 0.75, 0.4)
    for _, source in ipairs(sources) do
        local boss = A.G(source.boss) or source.boss
        GameTooltip:AddLine(
            boss
                .. " · "
                .. A.ZoneName({ zone = source.zone })
                .. " · "
                .. A.Duration((source.minute or 0) * 60),
            0.85,
            0.75,
            0.55,
            true
        )
        GameTooltip:AddLine(
            A.T("Base drop chance") .. " : " .. A.Format(source.chance) .. "%",
            0.7,
            0.7,
            0.6,
            true
        )
    end
end

--- Display a live, captured or labeled reference description; return whether an item tooltip was handled.
function A.ItemTooltip(frame, descriptor)
    if not descriptor.link then
        return false
    end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if descriptor.run == A.run and descriptor.slot and type(GetInventoryItemLink) == "function" then
        local ok, link = pcall(GetInventoryItemLink, "player", descriptor.slot)
        if ok and link == descriptor.link then
            local good, has = pcall(function()
                return GameTooltip:SetInventoryItem("player", descriptor.slot)
            end)
            if good and has then
                dropSources(descriptor)
                GameTooltip:Show()
                return true
            end
        end
    end
    local lines = descriptor.tooltip
    local reference = false
    if (not lines or table.getn(lines) == 0) and descriptor.collection then
        lines = A.CollectionReference(descriptor.link)
        reference = lines ~= nil
    end
    if lines and table.getn(lines) > 0 then
        for i = 1, math.min(table.getn(lines), 40) do
            local line = lines[i]
            if type(line) == "table" and type(line.text) == "string" then
                if line.right and line.right ~= "" and GameTooltip.AddDoubleLine then
                    GameTooltip:AddDoubleLine(
                        A.Text(line.text, 1500),
                        A.Text(line.right, 1500),
                        line.r or 1,
                        line.g or 1,
                        line.b or 1,
                        1,
                        1,
                        1
                    )
                else
                    GameTooltip:AddLine(
                        A.Text(line.text, 1500),
                        line.r or 1,
                        line.g or 1,
                        line.b or 1,
                        true
                    )
                end
            end
        end
        GameTooltip:AddLine(
            A.T(reference and "Current collection reference" or "Captured item description"),
            0.6,
            0.6,
            0.6,
            true
        )
    else
        GameTooltip:AddLine(descriptor.label or "", 1, 0.82, 0.4)
        GameTooltip:AddLine(A.T("Item description unavailable"), 0.7, 0.7, 0.7, true)
    end
    dropSources(descriptor)
    GameTooltip:Show()
    return true
end

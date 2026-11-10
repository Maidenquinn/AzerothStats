-- Read-only interoperability projection. No SavedVariables root or network output.
-- Schema v1 is a Lua table returned on demand; no duplicate history is stored.
local A = AzerothStats
local function number(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end
local function scalar(value, limit)
    if type(value) == "string" and string.len(value) > 0 and string.len(value) <= limit then
        return value
    end
    return nil
end
local function enum(value, allowed)
    if type(value) == "string" and allowed[value] then
        return value
    end
    return nil
end
local statuses = { active = true, ended = true, interrupted = true, terminal = true }
local outcomes = { victory = true, defeat = true, left = true }
local function metric(values, key)
    local value = type(values) == "table" and number(values[key]) or nil
    if value == nil then
        return { availability = "unavailable" }
    end
    return { value = value, availability = "available", provenance = "retained-run" }
end
-- Return an isolated, deliberately allowlisted projection. Never expose names,
-- coop roster, backup roots, event payloads or mutable internal tables.
function A.ExportRunV1(run)
    if type(run) ~= "table" or getmetatable(run) then
        return nil
    end
    local id = scalar(run.id, 80)
    if not id then
        return nil
    end
    local values = run.values
    local metrics = {}
    for _, key in ipairs({
        "duration",
        "level",
        "kills",
        "gold",
        "damage",
        "taken",
        "healing",
        "peakDps",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        metrics[key] = metric(values, key)
    end
    local heroic = number(run.heroic)
    if heroic == nil or heroic < 0 or heroic > 5 or heroic ~= math.floor(heroic) then
        heroic = nil
    end
    local partial = nil
    if type(run.partial) == "boolean" then
        partial = run.partial
    end
    return {
        schemaVersion = "1.0.0",
        source = { addon = "AzerothStats", version = A.version },
        run = {
            localId = id,
            nativeRunId = nil, -- AZS_ZONE.run semantics not yet verified.
            zone = scalar(run.zone, 80),
            class = scalar(run.class, 40),
            heroic = heroic,
            status = enum(run.status, statuses),
            outcome = enum(run.result, outcomes),
            partial = partial,
            startedAt = number(run.startedAt),
            endedAt = number(run.endedAt),
        },
        metrics = metrics,
    }
end

-- Resolve an owned retained run by local ID, without exposing the database or
-- accepting caller-owned tables. Explicit invocation only; no automatic export.
function A.ExportRetainedRunV1(localId)
    if type(localId) ~= "string" or string.len(localId) == 0 or string.len(localId) > 80 then
        return nil
    end
    local database = A.db
    if
        type(database) ~= "table"
        or getmetatable(database)
        or type(database.runs) ~= "table"
        or getmetatable(database.runs)
    then
        return nil
    end
    local matched = nil
    for key, run in pairs(database.runs) do
        if
            type(key) == "number"
            and key >= 1
            and key == math.floor(key)
            and type(run) == "table"
            and run.id == localId
        then
            -- Historical imports may collide. Never silently choose one run.
            if matched then
                return nil
            end
            matched = run
        end
    end
    if matched then
        return A.ExportRunV1(matched)
    end
    return nil
end

-- Observe the same native field read by WoW Logs AS v0.2.2. This is a
-- diagnostic candidate only: never attach it retroactively to a retained run.
-- Native run ID uniqueness, reuse and reload semantics remain unverified.
function A.InteropNativeRunCandidate()
    local zone = AZS_ZONE
    if type(zone) ~= "table" or getmetatable(zone) then
        return nil
    end
    local id = zone.run
    if type(id) == "string" then
        if string.len(id) > 0 and string.len(id) <= 80 then
            return id
        end
    elseif type(id) == "number" and number(id) and id >= 0 and id == math.floor(id) then
        local value = tostring(id)
        if string.len(value) <= 80 then
            return value
        end
    end
    return nil
end

-- AZST1 is a separate, explicit paste contract. It must never be passed off as
-- a WLAS2 payload. The encoder accepts only our own scalar projection.
local function jsonString(value)
    local replacements = {
        [34] = '\\"',
        [92] = "\\\\",
        [8] = "\\b",
        [9] = "\\t",
        [10] = "\\n",
        [12] = "\\f",
        [13] = "\\r",
    }
    local output = { '"' }
    for i = 1, string.len(value) do
        local byte = string.byte(value, i)
        if replacements[byte] then
            table.insert(output, replacements[byte])
        elseif byte < 32 then
            table.insert(output, string.format("\\u%04x", byte))
        else
            table.insert(output, string.char(byte))
        end
    end
    table.insert(output, '"')
    return table.concat(output)
end

local function jsonScalar(value)
    if type(value) == "string" then
        return jsonString(value)
    elseif type(value) == "number" and number(value) then
        return tostring(value)
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    end
    return "null"
end

-- Bounded, deterministic output; all keys originate from a fixed allowlist.
-- This deliberately avoids a general-purpose recursive table serializer.
function A.ExportCodeV1(run)
    local projected = A.ExportRunV1(run)
    if not projected then
        return nil
    end
    local r = projected.run
    local fields = {
        '"v":1',
        '"addon":"AzerothStats"',
        '"schema":"1.0.0"',
    }
    local runFields = {}
    for _, key in ipairs({
        "localId",
        "nativeRunId",
        "zone",
        "class",
        "heroic",
        "status",
        "outcome",
        "partial",
        "startedAt",
        "endedAt",
    }) do
        table.insert(runFields, jsonString(key) .. ":" .. jsonScalar(r[key]))
    end
    table.insert(fields, '"run":{' .. table.concat(runFields, ",") .. "}")
    local metricFields = {}
    for _, key in ipairs({
        "duration",
        "level",
        "kills",
        "gold",
        "damage",
        "taken",
        "healing",
        "peakDps",
        "bosses",
        "elites",
        "guardians",
        "chests",
        "magnets",
    }) do
        local m = projected.metrics[key]
        local item = '{"availability":' .. jsonString(m.availability)
        if m.availability == "available" then
            item = item .. ',"value":' .. jsonScalar(m.value) .. ',"provenance":"retained-run"'
        end
        table.insert(metricFields, jsonString(key) .. ":" .. item .. "}")
    end
    table.insert(fields, '"metrics":{' .. table.concat(metricFields, ",") .. "}")
    local code = "AZST1:{" .. table.concat(fields, ",") .. "}"
    if string.len(code) > 8192 then
        return nil
    end
    return code
end

function A.ExportRetainedCodeV1(localId)
    local projected = A.ExportRetainedRunV1(localId)
    if not projected then
        return nil
    end
    -- This path is safe because ExportRunV1 only reads its fixed allowlist.
    local r = projected.run
    local values = {}
    for key, metricValue in pairs(projected.metrics) do
        if metricValue.availability == "available" then
            values[key] = metricValue.value
        end
    end
    return A.ExportCodeV1({
        id = r.localId,
        zone = r.zone,
        class = r.class,
        heroic = r.heroic,
        status = r.status,
        result = r.outcome,
        partial = r.partial,
        startedAt = r.startedAt,
        endedAt = r.endedAt,
        values = values,
    })
end

-- Resolve the newest usable retained local ID without assuming dense run arrays.
function A.LatestRetainedRunId()
    local database = A.db
    if
        type(database) ~= "table"
        or getmetatable(database)
        or type(database.runs) ~= "table"
        or getmetatable(database.runs)
    then
        return nil
    end
    local selected, bestTime, bestIndex = nil, nil, nil
    for index, run in pairs(database.runs) do
        if
            type(index) == "number"
            and index >= 1
            and index == math.floor(index)
            and type(run) == "table"
            and type(run.id) == "string"
            and string.len(run.id) > 0
            and string.len(run.id) <= 80
        then
            local stamp = number(run.startedAt) or number(run.endedAt) or 0
            if
                not bestTime
                or stamp > bestTime
                or (stamp == bestTime and index > bestIndex)
            then
                selected, bestTime, bestIndex = run.id, stamp, index
            end
        end
    end
    return selected
end

-- Manual-only paste window. Never prints the payload in chat or persists it.
-- Created lazily so normal startup and combat sampling pay no UI cost.
function A.OpenInteropExport()
    if not A.db or type(A.db.runs) ~= "table" then
        A.Say("AZST1: run history unavailable.")
        return
    end
    if not A.interopWindow then
        local frame = CreateFrame("Frame", "AzerothStatsInteropExport", UIParent)
        frame:SetWidth(660)
        frame:SetHeight(350)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function()
            this:StartMoving()
        end)
        frame:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
        end)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        local function caption(y, label)
            local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
            text:SetText(label)
            return text
        end
        caption(-22, "AZST1 - Manual run export (browser users)")
        caption(-55, "Select a retained run ID (local only):")
        local selector = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        selector:SetWidth(390)
        selector:SetHeight(24)
        selector:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -72)
        selector:SetAutoFocus(false)
        selector:SetMaxLetters(80)
        selector:SetScript("OnEscapePressed", function()
            this:ClearFocus()
        end)
        -- Explicit convenience selection: find the latest retained run without
        -- changing SavedVariables or assuming numeric indices are contiguous.
        local latest = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        latest:SetWidth(130)
        latest:SetHeight(24)
        latest:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -72)
        latest:SetText("Select latest")
        latest:SetScript("OnClick", function()
            local selected = A.LatestRetainedRunId()
            if selected then
                selector:SetText(selected)
            else
                selector:SetText("")
            end
        end)
        local info = caption(-114, "No run selected. No data is transmitted.")
        info:SetWidth(620)
        local copyHint =
            caption(-144, "Generate, then Ctrl+A / Ctrl+C to copy. No WoW Logs importer yet.")
        copyHint:SetWidth(620)
        local code = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        code:SetWidth(610)
        code:SetHeight(24)
        code:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -184)
        code:SetAutoFocus(false)
        code:SetMaxLetters(8192)
        code:SetScript("OnEscapePressed", function()
            this:ClearFocus()
        end)
        local generate = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        generate:SetWidth(140)
        generate:SetHeight(26)
        generate:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 24)
        generate:SetText("Generate AZST1")
        generate:SetScript("OnClick", function()
            local id = selector:GetText() or ""
            local result = A.ExportRetainedRunV1(id)
            code:SetText("")
            if not result then
                info:SetText("Run not found, invalid or ambiguous. Check its local ID.")
                return
            end
            local encoded = A.ExportRetainedCodeV1(id)
            if not encoded then
                info:SetText("Export unavailable: invalid data or payload exceeds 8192 bytes.")
                return
            end
            local r = result.run
            info:SetText(
                "Run: "
                    .. r.localId
                    .. " | Zone: "
                    .. (r.zone or "unknown")
                    .. " | Status: "
                    .. (r.status or "unknown")
                    .. " | "
                    .. string.len(encoded)
                    .. " bytes"
            )
            code:SetText(encoded)
            code:SetFocus()
            code:HighlightText()
        end)
        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetWidth(90)
        close:SetHeight(26)
        close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 24)
        close:SetText("Close")
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
        frame.selector = selector
        frame.code = code
        A.interopWindow = frame
    end
    A.interopWindow.code:SetText("")
    A.interopWindow:Show()
end

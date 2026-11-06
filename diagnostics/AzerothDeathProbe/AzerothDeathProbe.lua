-- Read-only death diagnostics, standalone from Azeroth Stats.
local probe = CreateFrame("Frame")
local armed = false
local function log(kind, value)
    if not armed then return end
    if type(value) ~= "string" then value = tostring(value) end
    if string.len(value) > 220 then value = string.sub(value, 1, 220) end
    if type(AzerothDeathProbeLog) ~= "table" then AzerothDeathProbeLog = {} end
    table.insert(AzerothDeathProbeLog, string.format("%.2f [%s] %s", GetTime(), kind, value))
    while table.getn(AzerothDeathProbeLog) > 500 do table.remove(AzerothDeathProbeLog, 1) end
end
local function inspect()
    local count = 0
    local globals = (type(_G) == "table" and _G) or (type(getfenv) == "function" and getfenv(0))
    if type(globals) ~= "table" then
        log("SCAN", "Global environment unavailable")
        return
    end
    for k, v in pairs(globals) do
        if type(k) == "string" and (string.find(string.lower(k), "death") or string.find(string.lower(k), "recap") or string.find(string.lower(k), "kill")) then
            if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                log("GLOBAL", k .. "=" .. tostring(v))
            elseif type(v) == "table" then
                log("GLOBAL", k .. " [table]")
                local n = 0
                for key, val in pairs(v) do
                    if n >= 6 then break end
                    if (type(key) == "string" or type(key) == "number") and (type(val) == "string" or type(val) == "number" or type(val) == "boolean") then
                        log("FIELD", k .. "." .. tostring(key) .. "=" .. tostring(val))
                        n = n + 1
                    end
                end
            elseif type(v) == "function" then
                log("GLOBAL", k .. " [function]")
            end
            count = count + 1
            if count >= 30 then break end
        end
    end
end
-- Scan visible UI text without modifying native frames or invoking game functions.
-- Keep work bounded: the client may expose a large UI hierarchy.
local scanPending, scanDelay = false, 0
local function scanFrames()
    if not armed or not UIParent then return end
    local visited, recorded = 0, 0
    local function visit(frame, depth, context)
        if not frame or depth > 12 or visited >= 2500 or recorded >= 70 then return end
        visited = visited + 1
        if frame.IsVisible and not frame:IsVisible() then return end
        local name = frame.GetName and frame:GetName() or ""
        local lname = string.lower(name or "")
        local relevant = context or string.find(lname, "death") or string.find(lname, "recap")
            or string.find(lname, "kill")
        if frame.GetRegions then
            local regions = { frame:GetRegions() }
            for _, region in ipairs(regions) do
                if recorded >= 70 then break end
                if region and region.GetObjectType and region:GetObjectType() == "FontString"
                    and region.GetText and (not region.IsVisible or region:IsVisible()) then
                    local value = region:GetText()
                    if type(value) == "string" and value ~= "" then
                        local lower = string.lower(value)
                        local important = string.find(lower, "mort") or string.find(lower, "fatal")
                            or string.find(lower, "killed") or string.find(lower, "tué")
                            or string.find(lower, "blaumeux") or string.find(lower, "mograine")
                            or string.find(lower, "korth") or string.find(lower, "damage")
                            or string.find(lower, "dégât")
                        if relevant or important then
                            log("UI", (name ~= "" and name or "<unnamed>") .. ": " .. value)
                            recorded = recorded + 1
                        end
                    end
                end
            end
        end
        if frame.GetChildren then
            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do visit(child, depth + 1, relevant) end
        end
    end
    visit(UIParent, 0, false)
    log("UI_SCAN", "frames=" .. visited .. " texts=" .. recorded)
end
probe:SetScript("OnUpdate", function()
    if not scanPending then return end
    scanDelay = scanDelay + (arg1 or 0)
    if scanDelay < 0.7 then return end
    scanPending = false
    scanDelay = 0
    scanFrames()
end)
for _, ev in ipairs({"VARIABLES_LOADED", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_COMBAT_FRIENDLY_DEATH", "UI_ERROR_MESSAGE", "PLAYER_DEAD"}) do probe:RegisterEvent(ev) end
probe:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if type(AzerothDeathProbeLog) ~= "table" then AzerothDeathProbeLog = {} end
        return
    end
    if not armed then return end
    if event == "PLAYER_DEAD" then
        log("EVENT", event)
        inspect()
        scanPending = true
        scanDelay = 0
        return
    end
    if type(arg1) == "string" then log(event, arg1) end
end)
SLASH_AZEROTHDEATHPROBE1 = "/asdiag"
SlashCmdList["AZEROTHDEATHPROBE"] = function(cmd)
    cmd = string.lower(cmd or "")
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "start" then
        AzerothDeathProbeLog = {}
        armed = true
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: capture started; play until death.")
    elseif cmd == "stop" then
        scanPending = false
        armed = false
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: stopped; /reload to save.")
    elseif cmd == "scan" then
        inspect()
        scanFrames()
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: Lua globals and visible UI scanned.")
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: " .. (armed and "active" or "inactive") .. ", records " .. table.getn(AzerothDeathProbeLog or {}))
    else
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: /asdiag start | scan | stop | status")
    end
end

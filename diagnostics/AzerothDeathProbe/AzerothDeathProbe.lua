-- Read-only death diagnostics, standalone from Azeroth Stats.
local probe = CreateFrame("Frame")
local armed = false
local function log(kind, value)
    if not armed then return end
    if type(value) ~= "string" then value = tostring(value) end
    if string.len(value) > 220 then value = string.sub(value, 1, 220) end
    if type(AzerothDeathProbeLog) ~= "table" then AzerothDeathProbeLog = {} end
    table.insert(AzerothDeathProbeLog, string.format("%.2f [%s] %s", GetTime(), kind, value))
    while table.getn(AzerothDeathProbeLog) > 100 do table.remove(AzerothDeathProbeLog, 1) end
end
local function inspect()
    local count = 0
    for k, v in pairs(_G) do
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
for _, ev in ipairs({"VARIABLES_LOADED", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_COMBAT_FRIENDLY_DEATH", "UI_ERROR_MESSAGE", "PLAYER_DEAD"}) do probe:RegisterEvent(ev) end
probe:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if type(AzerothDeathProbeLog) ~= "table" then AzerothDeathProbeLog = {} end
        return
    end
    if not armed then return end
    if event == "PLAYER_DEAD" then log("EVENT", event); inspect(); return end
    if type(arg1) == "string" then log(event, arg1) end
end)
SLASH_AZEROTHDEATHPROBE1 = "/asdiag"
SlashCmdList["AZEROTHDEATHPROBE"] = function(cmd)
    cmd = string.lower(cmd or "")
    if cmd == "start" then
        AzerothDeathProbeLog = {}
        armed = true
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: capture started; play until death.")
    elseif cmd == "stop" then
        armed = false
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: stopped; /reload to save.")
    elseif cmd == "scan" then
        inspect()
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: Lua globals scanned.")
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: " .. (armed and "active" or "inactive") .. ", records " .. table.getn(AzerothDeathProbeLog or {}))
    else
        DEFAULT_CHAT_FRAME:AddMessage("Death Probe: /asdiag start | scan | stop | status")
    end
end

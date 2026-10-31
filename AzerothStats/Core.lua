-- Only addon entry point: lifecycle events, a 1 Hz sampler and /azstats.
-- Received addon messages mark freshness; the client parses native AZS_* data.
-- Commands change local views/settings only. Nothing is sent to another player.

local A = AzerothStats
local driver = CreateFrame("Frame", "AzerothStatsDriver", UIParent)
A.driver = driver
for _, eventName in ipairs({
    "ADDON_LOADED",
    "VARIABLES_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "CHAT_MSG_ADDON",
    "PLAYER_DEAD",
    "UI_ERROR_MESSAGE",
    "CHAT_MSG_COMBAT_FRIENDLY_DEATH",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
}) do
    driver:RegisterEvent(eventName)
end

--- Run locale/database initialization once and build widgets only after validation succeeds.
local function initialize()
    if A.initialized then
        return
    end
    A.initialized = true
    A.DetectLocale()
    if A.InitDB() then
        A.DetectLocale()
        local viewSettings = A.db.settings.view
        if type(viewSettings) == "table" then
            A.view.tab = math.max(1, math.min(11, math.floor(A.Number(viewSettings.tab) or 1)))
            if A.sources[viewSettings.mode] then
                A.view.mode = viewSettings.mode
            end
            if type(viewSettings.class) == "string" then
                A.view.class = viewSettings.class
            end
            for _, c in ipairs(A.favoriteCategories) do
                if c[1] == viewSettings.favoriteCategory then
                    A.view.favoriteCategory = c[1]
                end
            end
            if
                viewSettings.difficulty == "unknown"
                or A.HeroicLevel(viewSettings.difficulty) ~= nil
            then
                A.view.difficulty = viewSettings.difficulty == "unknown" and "unknown"
                    or A.HeroicLevel(viewSettings.difficulty)
            end
            local sections = {
                historySection = { "History", "Run report", "Compare runs" },
                reportSection = {
                    "Overview",
                    "Combat",
                    "Character",
                    "Co-op",
                    "Records",
                    "Build journal",
                    "Attributes",
                    "Timeline",
                    "Encounters",
                    "Summons",
                    "Effects",
                    "Observed support",
                },
                compareSection = { "Overview", "Combat", "Spells", "Equipment" },
            }
            for key, choices in pairs(sections) do
                for _, option in ipairs(choices) do
                    if viewSettings[key] == option then
                        A.view[key] = option
                    end
                end
            end
            for _, key in ipairs({ "kills", "gold", "level", "damage", "healing", "taken" }) do
                if viewSettings.v2CurveMetric == key then
                    A.view.v2CurveMetric = key
                end
            end
            if
                type(viewSettings.v2CurveCompare) == "string"
                and A.FindRun(viewSettings.v2CurveCompare)
            then
                A.view.v2CurveCompare = viewSettings.v2CurveCompare
            end
            A.view.compareA, A.view.compareB =
                A.Text(viewSettings.compareA, 80), A.Text(viewSettings.compareB, 80)
            if A.view.historySection == "Run report" then
                A.view.selected = A.Text(viewSettings.reportRun, 80)
            end
            A.view.v2Goals = viewSettings.v2Goals == true
            for _, group in ipairs({ "all", "essential", "advanced", "gear" }) do
                if viewSettings.v2AttributeGroup == group then
                    A.view.v2AttributeGroup = group
                end
            end
            A.view.cumulative = viewSettings.cumulative == true
            A.view.overviewStats = viewSettings.overviewStats == true
            if viewSettings.usageTab == "Jewelry" or viewSettings.usageTab == "Co-op" then
                A.view.usageTab = viewSettings.usageTab
            end
            if
                viewSettings.characterTab == "Equipment"
                or viewSettings.characterTab == "Attributes"
                or viewSettings.characterTab == "Timeline"
            then
                A.view.characterTab = viewSettings.characterTab
            end
        end
        if A.view.tab == 9 and A.view.usageTab == "Co-op" then
            A.view.cumulative = true
        end
        A.BuildUI()
        A.Say(A.T("Loaded") .. " · " .. A.version .. " · /azstats")
    end
end
driver:SetScript("OnEvent", function()
    if (event == "ADDON_LOADED" and arg1 == "AzerothStats") or event == "VARIABLES_LOADED" then
        initialize()
    elseif event == "CHAT_MSG_ADDON" then
        A.Packet(arg1, arg2)
    elseif event == "PLAYER_DEAD" then
        if A.runPacketAt and GetTime() - A.runPacketAt <= 2 then
            A.MarkDeath()
        end
    elseif
        event == "UI_ERROR_MESSAGE"
        or event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH"
        or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
        or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"
    then
        A.DeathEvidence(event, arg1)
    elseif event == "PLAYER_LOGOUT" then
        A.Sample()
        if A.run then
            A.Event(A.run, "checkpoint", "Sortie normale du client")
        end
    elseif event == "PLAYER_ENTERING_WORLD" and A.db then
        A.DetectLocale()
        A.ApplyUI()
    end
end)
local tick, languageTick = 0, 0
driver:SetScript("OnUpdate", function()
    tick = tick + (A.Number(arg1) or 0)
    languageTick = languageTick + (A.Number(arg1) or 0)
    if tick < 1 then
        return
    end
    tick = 0
    if A.db then
        if languageTick >= 10 then
            languageTick = 0
            local old = A.Locale()
            A.DetectLocale()
            if A.Locale() ~= old then
                A.ApplyUI()
            end
        end
        -- Refit owned panels only when the native viewport actually changes.
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        if A.ui and (A.ui.viewportWidth ~= width or A.ui.viewportHeight ~= height) then
            A.ui.viewportWidth, A.ui.viewportHeight = width, height
            A.ApplyUI()
        end
        A.Sample()
        A.RefreshUI()
        A.SyncScreenOverlays()
    end
end)
SLASH_AZEROTHSTATS1 = "/azstats"
SlashCmdList["AZEROTHSTATS"] = function(message)
    if not A.db then
        A.Say(A.T("Unavailable"))
        return
    end
    message = string.lower(string.gsub(string.gsub(message or "", "^%s+", ""), "%s+$", ""))
    local _, _, command, value = string.find(message, "^(%S+)%s*(.-)$")
    local settings = A.db.settings
    if not command or command == "toggle" then
        A.ToggleUI()
    elseif command == "show" then
        A.ToggleUI(true)
    elseif command == "hide" then
        A.ToggleUI(false)
    elseif command == "hud" or (command == "bar" and value == "config") then
        A.OpenBarEditor()
    elseif command == "bar" then
        settings.bar = not settings.bar
        A.ApplyUI()
    elseif command == "overlay" then
        if value ~= "" and not A.SetScreenOverlayMode(value) then
            A.Say("/azstats overlay on | off | bar | window")
        else
            A.Say("Overlay · " .. A.ScreenOverlayStatus())
        end
    elseif command == "minimap" then
        settings.minimap = not settings.minimap
        A.ApplyUI()
    elseif command == "lock" then
        settings.locked = not settings.locked
        A.Say(A.T("Lock position") .. " : " .. A.T(settings.locked and "Enabled" or "Disabled"))
    elseif command == "resetpos" then
        A.ResetPosition()
    elseif command == "scale" and A.Number(value) then
        settings.scale = math.max(0.65, math.min(1.5, tonumber(value)))
        A.ApplyUI()
    elseif command == "retention" and A.Number(value) then
        A.RequestRetention(tonumber(value))
        A.RefreshUI()
    elseif command == "opacity" and A.Number(value) then
        settings.opacity = math.max(0.45, math.min(1, tonumber(value)))
        A.ApplyUI()
        A.RefreshUI()
    elseif command == "lang" then
        if not A.SetLanguage(value) then
            A.Say(A.T("Unknown command"))
        end
    elseif command == "class" then
        A.view.class = nil
        if value ~= "all" then
            for cls in pairs(A.db.classes) do
                if string.lower(cls) == value then
                    A.view.class = cls
                end
            end
        end
        A.view.page = 1
        A.RefreshUI()
    elseif command == "data" or command == "reset" then
        A.OpenDataManagement()
    elseif command == "diagnose" or command == "debug" then
        A.view.tab = 7
        A.view.page = 1
        A.ToggleUI(true)
        for _, line in ipairs(A.Diagnostics()) do
            A.Say(line)
        end
    elseif command == "favorites" then
        A.view.tab = 10
        A.view.page = 1
        A.ToggleUI(true)
    elseif command == "favorite" then
        A.ToggleFavorite(A.RunFavorite(A.Selected()))
        A.RefreshUI()
    elseif command == "nemesis" then
        A.view.tab = 11
        A.view.page = 1
        A.ToggleUI(true)
    elseif command == "coop" then
        A.OpenReport(A.Selected() and A.Selected().id)
        A.view.reportSection = "Co-op"
        A.ToggleUI(true)
    elseif command == "journal" then
        A.OpenReport(A.Selected() and A.Selected().id)
        A.view.reportSection = "Build journal"
        A.ToggleUI(true)
    elseif command == "report" then
        A.OpenReport(A.Selected() and A.Selected().id)
        A.ToggleUI(true)
    elseif command == "compare" then
        A.OpenCompare(A.Selected() and A.Selected().id)
        A.ToggleUI(true)
    elseif command == "history" then
        A.view.historySection = "History"
        A.view.tab = 3
        A.view.page = 1
        A.ToggleUI(true)
    elseif command == "sound" then
        if value == "test" then
            A.PlayRecordSound()
        else
            settings.recordSound = not settings.recordSound
            A.Say(
                A.T("Record sounds")
                    .. " : "
                    .. A.T(settings.recordSound and "Enabled" or "Disabled")
            )
            A.RefreshUI()
        end
    elseif command == "help" then
        A.Say(
            "/azstats show, hide, history, report, compare, journal, data, coop, favorites, favorite, nemesis, diagnose, bar, hud, minimap, lock, resetpos, class all|CLASS, scale 0.65..1.5, opacity 0.45..1, lang auto|CODE, sound [test], retention 10..1000"
        )
    else
        A.Say(A.T("Unknown command") .. " · /azstats help")
    end
end

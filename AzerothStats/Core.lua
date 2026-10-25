local A = AzerothStats

local f = CreateFrame("Frame", "AzerothStatsDriver", UIParent)

A.driver = f

for _, e in ipairs({"ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "CHAT_MSG_ADDON"}) do f:RegisterEvent(e) end

local function initialize()

 if A.initialized then return end

 A.initialized = true

 A.DetectLocale()

 if A.InitDB() then

  A.DetectLocale()

  local v = A.db.settings.view

  if type(v) == "table" then

   A.view.tab = math.max(1, math.min(9, math.floor(A.Number(v.tab) or 1)))

   if A.sources[v.mode] then A.view.mode = v.mode end

   if type(v.class) == "string" then A.view.class = v.class end

   A.view.cumulative = v.cumulative == true

   if v.usageTab=="Jewelry" then A.view.usageTab="Jewelry" end
   if v.characterTab=="Equipment" or v.characterTab=="Attributes" or v.characterTab=="Timeline" then A.view.characterTab=v.characterTab end

  end

  A.BuildUI(); A.Say(A.T("Loaded").." · "..A.version.." · /azstats")

 end

end

f:SetScript("OnEvent", function()

 if (event == "ADDON_LOADED" and arg1 == "AzerothStats") or event == "VARIABLES_LOADED" then initialize()

 elseif event == "CHAT_MSG_ADDON" then A.Packet(arg1, arg2)

 elseif event == "PLAYER_LOGOUT" then A.Sample(); if A.run then A.Event(A.run, "checkpoint", "Sortie normale du client") end

 elseif event == "PLAYER_ENTERING_WORLD" and A.db then A.DetectLocale();A.ApplyUI()

 end

end)

local tick,languageTick = 0,0

f:SetScript("OnUpdate", function()

 tick = tick + (A.Number(arg1) or 0)

 languageTick=languageTick+(A.Number(arg1) or 0)

 if tick < 1 then return end

 tick = 0

 if A.db then

  if languageTick>=10 then

   languageTick=0;local old=A.Locale();A.DetectLocale();if A.Locale()~=old then A.ApplyUI() end

  end

  A.Sample(); A.RefreshUI()

 end

end)

SLASH_AZEROTHSTATS1 = "/azstats"

SlashCmdList["AZEROTHSTATS"] = function(msg)

 if not A.db then A.Say(A.T("Unavailable")); return end

 msg = string.lower(string.gsub(string.gsub(msg or "", "^%s+", ""), "%s+$", ""))

 local _, _, cmd, value = string.find(msg, "^(%S+)%s*(.-)$")

 local s = A.db.settings

 if not cmd or cmd == "toggle" then A.ToggleUI()

 elseif cmd == "show" then A.ToggleUI(true)

 elseif cmd == "hide" then A.ToggleUI(false)

 elseif cmd == "bar" then s.bar = not s.bar; A.ApplyUI()

 elseif cmd == "minimap" then s.minimap = not s.minimap; A.ApplyUI()

 elseif cmd == "lock" then s.locked = not s.locked; A.Say(A.T("Lock position").." : "..A.T(s.locked and "Enabled" or "Disabled"))

 elseif cmd == "resetpos" then A.ResetPosition()

 elseif cmd == "scale" and A.Number(value) then s.scale = math.max(0.65, math.min(1.5, tonumber(value))); A.ApplyUI()

 elseif cmd == "retention" and A.Number(value) then s.maxRuns = math.max(10, math.min(1000, math.floor(tonumber(value)))); A.Trim(); A.RefreshUI()

 elseif cmd == "opacity" and A.Number(value) then s.opacity=math.max(0.45,math.min(1,tonumber(value)));A.ApplyUI();A.RefreshUI()

 elseif cmd == "lang" then if not A.SetLanguage(value) then A.Say(A.T("Unknown command")) end

 elseif cmd == "class" then

  A.view.class = nil

  if value ~= "all" then for cls in pairs(A.db.classes) do if string.lower(cls) == value then A.view.class = cls end end end

  A.view.page = 1; A.RefreshUI()

 elseif cmd == "diagnose" or cmd == "debug" then A.view.tab = 7; A.view.page = 1; A.ToggleUI(true); for _, line in ipairs(A.Diagnostics()) do A.Say(line) end

 elseif cmd == "history" then A.view.tab = 3; A.view.page = 1; A.ToggleUI(true)

 elseif cmd == "help" then A.Say("/azstats show, hide, history, diagnose, bar, minimap, lock, resetpos, class all|CLASS, scale 0.65..1.5, opacity 0.45..1, lang auto|CODE, retention 10..1000")

 else A.Say(A.T("Unknown command").." · /azstats help") end

end


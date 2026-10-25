local A = AzerothStats
A.languages = {
 {"auto", "Automatic"}, {"en", "English"}, {"pl", "Polski"}, {"cs", "Čeština"}, {"de", "Deutsch"},
 {"pt", "Português (Brasil)"}, {"es", "Español"}, {"fr", "Français"}, {"ro", "Română"}, {"tr", "Türkçe"},
 {"ru", "Русский"}, {"uk", "Українська"}, {"zh", "简体中文"}, {"ja", "日本語"}, {"ko", "한국어"}
}
local aliases = {enUS="en",enGB="en",plPL="pl",csCZ="cs",deDE="de",ptBR="pt",esES="es",esMX="es",frFR="fr",roRO="ro",trTR="tr",ruRU="ru",ukUA="uk",zhCN="zh",jaJP="ja",koKR="ko"}
function A.Locale()
 return A.locale or "en"
end
function A.T(key)
 local d = A.uiText[A.Locale()] or A.uiText.en
 return d[key] or (A.uiText.en[key]) or key
end
function A.G(key)
 local d = A.gameText[A.Locale()] or A.gameText.en
 return d[key] or A.gameText.en[key]
end
function A.ClassName(cls) return A.G("class." .. tostring(cls) .. ".name") or A.T("Unknown") end
function A.ZoneName(r) return r and (A.G("zone." .. tostring(r.zone) .. ".name") or r.zoneName or r.zone) or A.T("Unknown") end
function A.Status(value)
 local map = {active="Live",playing="Live",ready="Ready",choosing="Choosing",paused="Paused",dead="Dead",victory="Victory",defeat="Defeat",left="Left",interrupted="Interrupted",ended="Ended",terminal="Ended",endless="Continued"}
 return A.T(map[value] or "Out of run")
end
function A.ModeName(mode)
 local map = {damage="Damage",healing="Effective healing",taken="Damage taken",boss="Last boss fight"}
 return A.T(map[mode] or "Unknown")
end
function A.Metric(key)
 local game = {duration="end.survived",kills="hud.kills",gold="hud.gold",damage="end.damage_dealt",taken="end.damage_taken",bosses="end.bosses",elites="end.elites",guardians="end.guardians",chests="end.caches_opened",level="end.level"}
 if game[key] then return A.G(game[key]) end
 return A.T(key == "healing" and "Effective healing" or key == "magnets" and "Magnets" or "Unknown")
end
function A.Reason(reason)
 local map = {["attente d'un paquet frais"]="No fresh packet",["API absente"]="API unavailable",["aucun paquet recu"]="No packet received",["paquet invalide"]="Invalid packet",["compteur en baisse : dernier echantillon conserve"]="Counter decreased; last sample kept"}
 local key = map[reason] or reason
 if key == "API unavailable" then return A.T("API") .. " : " .. A.T("Unavailable") end
 return A.T(key or "Unavailable")
end
function A.DetectLocale()
 local setting = A.db and A.db.settings.language
 if setting and A.uiText[setting] then A.locale = setting; A.localeSource = "Settings"; return setting end
 local clsName = A.Call(UnitClass, "player")
 local classCandidate,classCount=nil,0
 for _, lang in ipairs(A.languages) do
  local d = A.gameText[lang[1]]
  if d then for key, value in pairs(d) do
   if string.find(key, "^class%.") and value == clsName then classCandidate = lang[1];classCount=classCount+1 end
  end end
 end
 if classCount~=1 then classCandidate=nil end
 -- The client can report enUS while the game's own tooltip is French, etc.
 -- Only standard 1.12 GameTooltip methods verified in the installed client are used.
 local candidates
 if not A.localeTip and CreateFrame then A.localeTip = CreateFrame("GameTooltip", "AzerothStatsLocaleTooltip", UIParent, "GameTooltipTemplate") end
 local tip = A.localeTip
 if tip and tip.SetHyperlink and tip.ClearLines then
  for _, probe in ipairs({{133,"fireball"},{116,"frostbolt"},{686,"shadow_bolt"}}) do
   tip:SetOwner(UIParent, "ANCHOR_NONE"); tip:ClearLines()
   local ok = pcall(function() tip:SetHyperlink("enchant:" .. probe[1]) end)
   local fs = getglobal("AzerothStatsLocaleTooltipTextLeft1")
   local name = ok and fs and fs:GetText()
   tip:Hide()
   if name and name ~= "" then
    local found, count, single = {}, 0, nil
    for lg, d in pairs(A.gameText) do
     if d["ability." .. probe[2] .. ".name"] == name and (not candidates or candidates[lg]) then found[lg] = true; count = count + 1; single = lg end
    end
    if count == 1 then A.locale = single; A.localeSource = "GameTooltip"; return single end
    if count > 0 then candidates = found end
   end
  end
 end
 if classCandidate and (not candidates or candidates[classCandidate]) then A.locale = classCandidate; A.localeSource = "UnitClass"; return classCandidate end
 local locale = A.Call(GetLocale)
 local fallback = aliases[locale] or "en"
 if candidates and not candidates[fallback] then fallback = "en" end
 A.locale = fallback; A.localeSource = "GetLocale"; return fallback
end
function A.SetLanguage(code)
 if code ~= "auto" and not A.uiText[code] then return false end
 A.db.settings.language = code; A.DetectLocale()
 if A.ApplyUI then A.ApplyUI(); A.RefreshUI() end
 return true
end
function A.Font(title, locale)
 local lg = locale or A.Locale()
 local root = "Interface\\AddOns\\AzerothStats\\media\\"
 if lg == "zh" or lg == "ja" or lg == "ko" then return root .. "AzerothSans-" .. lg .. ".otf" end
 return root .. (title and "AzerothSerif.ttf" or "AzerothSans.ttf")
end
function A.SpellName(sp)
 return A.G("ability." .. tostring(sp.key) .. ".name") or tostring(sp.name or sp.spell or A.T("Spells"))
end
function A.SourceName(name)
 local map = {["boss melee"]="Boss melee",["boss spell"]="Boss spells",elite="Elites",["mob melee"]="Creature melee",["mob spell"]="Creature spells",area="Ground",Melee="Melee"}
 if map[name] then return A.T(map[name]) end
 -- Meter names are localized game data. Translate recognized ability names by stable key.
 if not A.abilityKeys then
  A.abilityKeys = {}
  for _, d in pairs(A.gameText) do for key, value in pairs(d) do if string.find(key,"^ability%.") then A.abilityKeys[value] = key end end end
 end
 local key = A.abilityKeys[name]
 return key and A.G(key) or tostring(name or A.T("Unknown"))
end

-- Locale selection, translated labels and bundled font paths.
-- Automatic detection probes three fixed native spell tooltips; it sends no request.
-- Labels are reference data, never executable templates.

local A = AzerothStats
A.languages = {
    { "auto", "Automatic" },
    { "en", "English" },
    { "pl", "Polski" },
    { "cs", "Čeština" },
    { "de", "Deutsch" },
    { "pt", "Português (Brasil)" },
    { "es", "Español" },
    { "fr", "Français" },
    { "ro", "Română" },
    { "tr", "Türkçe" },
    { "ru", "Русский" },
    { "uk", "Українська" },
    { "zh", "简体中文" },
    { "ja", "日本語" },
    { "ko", "한국어" },
}
local aliases = {
    enUS = "en",
    enGB = "en",
    plPL = "pl",
    csCZ = "cs",
    deDE = "de",
    ptBR = "pt",
    esES = "es",
    esMX = "es",
    frFR = "fr",
    roRO = "ro",
    trTR = "tr",
    ruRU = "ru",
    ukUA = "uk",
    zhCN = "zh",
    jaJP = "ja",
    koKR = "ko",
}

--- Return the active addon language, with English as a safe fallback.
function A.Locale()
    return A.locale or "en"
end

--- Look up a UI label, falling back to English and then the literal key.
function A.T(key)
    local d = A.uiText[A.Locale()] or A.uiText.en
    return d[key] or A.uiText.en[key] or key
end

--- Look up static reference game text in the active language and then English.
function A.G(key)
    local d = A.gameText[A.Locale()] or A.gameText.en
    return d[key] or A.gameText.en[key]
end

--- Translate a canonical class key for display; unsupported classes remain unknown.
function A.ClassName(cls)
    return A.G("class." .. tostring(cls) .. ".name") or A.T("Unknown")
end

--- Prefer a recognized static zone label, otherwise the sanitized observed zone name.
function A.ZoneName(r)
    return r and (A.G("zone." .. tostring(r.zone) .. ".name") or r.zoneName or r.zone)
        or A.T("Unknown")
end

--- Translate a known run/result state without turning an unknown state into a death.
function A.Status(value)
    local map = {
        active = "Live",
        playing = "Live",
        ready = "Ready",
        choosing = "Choosing",
        paused = "Paused",
        dead = "Dead",
        victory = "Victory",
        defeat = "Defeat",
        left = "Left",
        interrupted = "Interrupted",
        ended = "Ended",
        terminal = "Ended",
        endless = "Continued",
    }
    return A.T(map[value] or "Out of run")
end

--- Translate one supported combat-meter mode.
function A.ModeName(mode)
    local map = {
        damage = "Damage",
        healing = "Effective healing",
        taken = "Damage taken",
        boss = "Last boss fight",
    }
    return A.T(map[mode] or "Unknown")
end

--- Resolve the display label for a tracked metric, separating UI and native reference catalogs.
function A.Metric(key)
    if key == "peakDps" then
        return A.T("Peak observed DPS")
    end
    local game = {
        duration = "end.survived",
        kills = "hud.kills",
        gold = "hud.gold",
        damage = "end.damage_dealt",
        taken = "end.damage_taken",
        bosses = "end.bosses",
        elites = "end.elites",
        guardians = "end.guardians",
        chests = "end.caches_opened",
        level = "end.level",
    }
    if game[key] then
        return A.G(game[key])
    end
    return A.T(
        key == "healing" and "Effective healing" or key == "magnets" and "Magnets" or "Unknown"
    )
end

--- Translate known API-read failures while retaining unknown diagnostic reasons verbatim.
function A.Reason(reason)
    local map = {
        ["attente d'un paquet frais"] = "No fresh packet",
        ["API absente"] = "API unavailable",
        ["aucun paquet recu"] = "No packet received",
        ["paquet invalide"] = "Invalid packet",
        ["compteur en baisse : dernier echantillon conserve"] = "Counter decreased; last sample kept",
    }
    local key = map[reason] or reason
    if key == "API unavailable" then
        return A.T("API") .. " : " .. A.T("Unavailable")
    end
    return A.T(key or "Unavailable")
end

--- Build reverse class-name and ability-name indexes once; DetectLocale used to walk GameText every 10s.
local function localeIndexes()
    if A.classLocaleIndex and A.abilityLocaleIndex then
        return
    end
    A.classLocaleIndex, A.abilityLocaleIndex = {}, {}
    for _, lang in ipairs(A.languages) do
        local code, d = lang[1], A.gameText[lang[1]]
        if d then
            for key, value in pairs(d) do
                if type(value) == "string" then
                    if string.find(key, "^class%.", 1, false) then
                        local list = A.classLocaleIndex[value]
                        if not list then
                            list = {}
                            A.classLocaleIndex[value] = list
                        end
                        table.insert(list, code)
                    elseif string.find(key, "^ability%..+%.name$", 1, false) then
                        local list = A.abilityLocaleIndex[value]
                        if not list then
                            list = {}
                            A.abilityLocaleIndex[value] = list
                        end
                        table.insert(list, { code, key })
                    end
                end
            end
        end
    end
end

--- Honor a manual preference, otherwise combine native class/spell-tooltip evidence and locale fallback.
function A.DetectLocale()
    local setting = A.db and A.db.settings.language
    if setting and A.uiText[setting] then
        A.locale = setting
        A.localeSource = "Settings"
        return setting
    end
    localeIndexes()
    local clsName = A.Call(UnitClass, "player")
    local classHits = clsName and A.classLocaleIndex[clsName]
    local classCandidate = classHits and table.getn(classHits) == 1 and classHits[1] or nil
    -- The client can report enUS while the game's own tooltip is French, etc.
    -- Only standard 1.12 GameTooltip methods verified in the installed client are used.
    local candidates
    if not A.localeTip and CreateFrame then
        A.localeTip =
            CreateFrame("GameTooltip", "AzerothStatsLocaleTooltip", UIParent, "GameTooltipTemplate")
    end
    local tip = A.localeTip
    if tip and tip.SetHyperlink and tip.ClearLines then
        for _, probe in ipairs({ { 133, "fireball" }, { 116, "frostbolt" }, { 686, "shadow_bolt" } }) do
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            tip:ClearLines()
            local ok = pcall(function()
                tip:SetHyperlink("enchant:" .. probe[1])
            end)
            local fs = getglobal("AzerothStatsLocaleTooltipTextLeft1")
            local name = ok and fs and fs:GetText()
            tip:Hide()
            if name and name ~= "" then
                local found, count, single = {}, 0, nil
                local abilityKey = "ability." .. probe[2] .. ".name"
                local hits = A.abilityLocaleIndex[name]
                if hits then
                    for _, hit in ipairs(hits) do
                        local lg, key = hit[1], hit[2]
                        if key == abilityKey and (not candidates or candidates[lg]) then
                            found[lg] = true
                            count = count + 1
                            single = lg
                        end
                    end
                end
                if count == 1 then
                    A.locale = single
                    A.localeSource = "GameTooltip"
                    return single
                end
                if count > 0 then
                    candidates = found
                end
            end
        end
    end
    if classCandidate and (not candidates or candidates[classCandidate]) then
        A.locale = classCandidate
        A.localeSource = "UnitClass"
        return classCandidate
    end
    local locale = A.Call(GetLocale)
    local fallback = aliases[locale] or "en"
    if candidates and not candidates[fallback] then
        fallback = "en"
    end
    A.locale = fallback
    A.localeSource = "GetLocale"
    return fallback
end

--- Validate and save a manual language selection, then repaint owned widgets.
function A.SetLanguage(code)
    if code ~= "auto" and not A.uiText[code] then
        return false
    end
    A.db.settings.language = code
    A.DetectLocale()
    if A.ApplyUI then
        A.ApplyUI()
        A.RefreshUI()
    end
    return true
end

--- Choose a bundled Latin/CJK font path; no path comes from received data.
function A.Font(title, locale)
    local lg = locale or A.Locale()
    local root = "Interface\\AddOns\\AzerothStats\\media\\"
    if lg == "zh" or lg == "ja" or lg == "ko" then
        return root .. "AzerothSans-" .. lg .. ".otf"
    end
    return root .. (title and A.theme.serif and "AzerothSerif.ttf" or "AzerothSans.ttf")
end

--- Resolve a known spell key, otherwise show the recorded name/ID.
function A.SpellName(sp)
    return A.G("ability." .. tostring(sp.key) .. ".name")
        or tostring(sp.name or sp.spell or A.T("Spells"))
end

--- Translate recognized meter source labels and lazily cache ability-name keys.
function A.SourceName(name)
    local map = {
        ["boss melee"] = "Boss melee",
        ["boss spell"] = "Boss spells",
        elite = "Elites",
        ["mob melee"] = "Creature melee",
        ["mob spell"] = "Creature spells",
        area = "Ground",
        Melee = "Melee",
    }
    if map[name] then
        return A.T(map[name])
    end
    -- Meter names are localized game data. Translate recognized ability names by stable key.
    if not A.abilityKeys then
        A.abilityKeys = {}
        for _, d in pairs(A.gameText) do
            for key, value in pairs(d) do
                if string.find(key, "^ability%.") then
                    A.abilityKeys[value] = key
                end
            end
        end
    end
    local key = A.abilityKeys[name]
    return key and A.G(key) or tostring(name or A.T("Unknown"))
end

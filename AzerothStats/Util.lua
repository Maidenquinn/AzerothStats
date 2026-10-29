-- Shared primitives and formatting. Copies/signatures have explicit work budgets.
-- Native calls are protected by pcall; chat output is local to DEFAULT_CHAT_FRAME.

AzerothStats = { version = "1.7.0-dev.2", schema = 1 }
local A = AzerothStats

--- Accept finite non-negative counters; return nil for absent, negative or non-finite input.
function A.Number(v)
    local n = tonumber(v)
    if n and n == n and n >= 0 and n < 1e100 then
        return n
    end
end

--- Call an optional native reader with one argument; retain an error for Diagnostics instead of throwing.
function A.Call(fn, a)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, x, y, z = pcall(fn, a)
    if ok then
        return x, y, z
    end
    A.apiError = tostring(x)
end
-- Copy data, never behavior. Shared budgets bound recursive work even when an
-- API table is cyclic, too deep or unexpectedly wide. A truncated copy is flagged.

--- Keep a bounded UTF-8 prefix without splitting a final multibyte character.
function A.PrefixText(value, limit)
    if string.len(value) <= limit then
        return value
    end
    local last = limit
    while last > 0 do
        local byte = string.byte(value, last)
        if byte < 128 or byte >= 192 then
            break
        end
        last = last - 1
    end
    if last > 0 then
        local lead = string.byte(value, last)
        local width = lead < 128 and 1 or (lead < 224 and 2 or (lead < 240 and 3 or 4))
        if last + width - 1 > limit then
            limit = last - 1
        end
    else
        limit = 0
    end
    return string.sub(value, 1, limit)
end

--- Return a bounded data-only copy. Functions, metatables, cycles and excessive depth are excluded.
function A.Copy(value, depth)
    local remaining = 8192
    local ancestors = {}

    --- Recursive data-only worker sharing one node budget and ancestor set.
    local function copy(v, level)
        remaining = remaining - 1
        if remaining < 0 then
            return nil
        end
        local kind = type(v)
        if kind == "number" then
            return A.Number(v)
        end
        if kind == "string" then
            return A.PrefixText(v, 500)
        end
        if kind == "boolean" then
            return v
        end
        if kind ~= "table" or level <= 0 or ancestors[v] or getmetatable(v) then
            return nil
        end
        ancestors[v] = true
        local result, count = {}, 0
        for key, child in pairs(v) do
            count = count + 1
            if count > 256 or remaining < 1 then
                result._truncated = true
                break
            end
            if type(key) == "string" or type(key) == "number" then
                result[key] = copy(child, level - 1)
            end
        end
        ancestors[v] = nil
        return result
    end
    return copy(value, math.min(depth or 5, 16))
end
-- Deterministic equality marker, NOT a cryptographic hash or server identity.
-- Sorting keys makes repeated samples comparable; budgets prevent pathological
-- recursive tables from blocking the UI. Exceeding a budget is diagnosed.

--- Build a deterministic equality marker with cycle/work guards; this is not a cryptographic hash.
function A.Sign(value)
    local remaining = 32768
    local ancestors = {}

    --- Recursive equality worker; all branches share the same finite work budget.
    local function sign(v, depth)
        remaining = remaining - 1
        if remaining < 0 or depth > 32 then
            A.signatureLimited = true
            return "!limit"
        end
        if type(v) ~= "table" then
            if type(v) == "string" then
                return "string:" .. string.sub(v, 1, 1500)
            end
            return type(v) .. ":" .. tostring(v)
        end
        if ancestors[v] or getmetatable(v) then
            A.signatureLimited = true
            return "!cycle"
        end
        ancestors[v] = true
        local keys, out = {}, {}
        local count = 0
        for key in pairs(v) do
            count = count + 1
            if count > 4096 then
                A.signatureLimited = true
                break
            end
            if type(key) == "string" or type(key) == "number" then
                table.insert(keys, key)
            end
        end
        table.sort(keys, function(x, y)
            return tostring(x) < tostring(y)
        end)
        for _, key in ipairs(keys) do
            if remaining < 1 then
                table.insert(out, "!limit")
                A.signatureLimited = true
                break
            end
            table.insert(out, tostring(key) .. "=" .. sign(v[key], depth + 1))
        end
        ancestors[v] = nil
        return "{" .. table.concat(out, ";") .. "}"
    end
    return sign(value, 0)
end

--- Write a status line to the local chat frame only; never transmit chat or addon messages.
function A.Say(s)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffedbd62Azeroth Stats|r : " .. s)
    end
end

--- Format a counter with locale-specific grouping; absence remains an unavailable value.
function A.Format(v)
    if v == nil then
        return A.T and A.T("Unavailable") or "--"
    end
    if type(v) ~= "number" then
        return tostring(v)
    end
    local s = string.format("%.0f", v)
    local sep = ","
    local lg = A.Locale and A.Locale() or "en"
    if lg == "fr" or lg == "pl" or lg == "cs" or lg == "ru" or lg == "uk" then
        sep = " "
    elseif lg == "de" or lg == "es" or lg == "pt" or lg == "tr" or lg == "ro" then
        sep = "."
    end
    local n = 1
    while n > 0 do
        s, n = string.gsub(s, "^(%-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
    end
    return s
end

--- Format bounded server seconds as a duration without overflowing the native integer formatter.
function A.Duration(t)
    if not A.Number(t) or t > 7730941129200 then
        return A.T and A.T("Unavailable") or "--"
    end
    if t < 3600 then
        return string.format("%02d:%02d", math.floor(t / 60), math.mod(math.floor(t), 60))
    end
    return string.format(
        "%d:%02d:%02d",
        math.floor(t / 3600),
        math.mod(math.floor(t / 60), 60),
        math.mod(math.floor(t), 60)
    )
end

--- Format a finite decimal for display, applying the selected decimal separator.
function A.Decimal(v, places)
    if type(v) ~= "number" or v ~= v then
        return A.T("Unavailable")
    end
    local s = string.format("%." .. (places or 1) .. "f", v)
    local lg = A.Locale()
    if
        lg == "fr"
        or lg == "de"
        or lg == "es"
        or lg == "pt"
        or lg == "pl"
        or lg == "cs"
        or lg == "ro"
        or lg == "tr"
        or lg == "ru"
        or lg == "uk"
    then
        s = string.gsub(s, "%.", ",")
    end
    return s
end

--- Abbreviate a large available counter for rows/cards; exact values remain in model tooltips.
function A.Short(v)
    if not A.Number(v) then
        return A.T("Unavailable")
    end
    if v >= 1000000000 then
        return A.Decimal(v / 1000000000, 2) .. " G"
    end
    if v >= 1000000 then
        return A.Decimal(v / 1000000, 2) .. " M"
    end
    if v >= 10000 then
        return A.Decimal(v / 1000, 1) .. " k"
    end
    return A.Format(v)
end

--- Render an available per-second value without manufacturing a zero for missing data.
function A.Rate(v)
    return v and A.Decimal(v, 1) or A.T("Unavailable")
end

--- Resolve a static icon or a bounded native spellbook cache; never scan beyond 512 spell slots.
function A.SpellIcon(name)
    if A.SourceName then
        A.SourceName(name)
    end
    local key = A.abilityKeys and A.abilityKeys[name]
    if not key and type(name) == "string" then
        local _, _, tail = string.find(name, ":%s*(.+)$")
        key = tail and A.abilityKeys and A.abilityKeys[tail]
    end
    local builtin = key and A.gameSpellIcons and A.gameSpellIcons[key]
    if builtin then
        return builtin
    end
    if name == "Melee" then
        return "INV_Sword_04"
    end
    local now = A.Number(A.Call(GetTime)) or 0
    if not A.spellIcons or not A.iconScanAt or now > A.iconScanAt + 10 then
        A.spellIcons = {}
        A.iconScanAt = now
        local n = A.Number(A.Call(GetNumSpellTabs)) or 0
        for tab = 1, math.min(n, 12) do
            if type(GetSpellTabInfo) == "function" then
                local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
                if
                    ok
                    and A.Number(offset)
                    and A.Number(count)
                    and offset == math.floor(offset)
                    and count == math.floor(count)
                then
                    for i = offset + 1, math.min(offset + count, 512) do
                        local spell, texture
                        if type(GetSpellName) == "function" then
                            local good, value = pcall(GetSpellName, i, BOOKTYPE_SPELL or "spell")
                            if good then
                                spell = value
                            end
                        end
                        if type(GetSpellTexture) == "function" then
                            local good, value = pcall(GetSpellTexture, i, BOOKTYPE_SPELL or "spell")
                            if good then
                                texture = value
                            end
                        end
                        if type(spell) == "string" and A.TexturePath(texture) then
                            A.spellIcons[spell] = A.TexturePath(texture)
                        end
                    end
                end
            end
        end
    end
    return A.spellIcons[name] or "INV_Misc_Book_09"
end

--- Read the native wall clock if available. It is metadata, not a run timer or a stable identity.
function A.Wall()
    return A.Call(time)
end

--- Format saved wall time via pcall; an out-of-range native date remains unavailable.
function A.Date(t)
    if not t or not date then
        return A.T("Unavailable")
    end
    local lg = A.Locale()
    local format = (lg == "en" and "%m/%d %H:%M")
        or ((lg == "zh" or lg == "ja" or lg == "ko") and "%Y/%m/%d %H:%M")
        or "%d/%m %H:%M"
    local ok, value = pcall(date, format, t)
    return ok and value or A.T("Unavailable")
end

--- Append one bounded local run event and discard the oldest after the 120-entry cap.
function A.Event(r, kind, text)
    if not r then
        return
    end
    table.insert(r.events, { t = r.values.duration, kind = kind, text = A.Text(text) or "" })
    if table.getn(r.events) > 120 then
        table.remove(r.events, 1)
        r.eventsTruncated = true
    end
end

--- Compact presentation only; callers retain exact native values in their tooltip.
function A.CompactRate(number)
    local value = A.Number(number)
    if value and value >= 10000 then
        return A.Short(value)
    end
    return A.Rate(value)
end

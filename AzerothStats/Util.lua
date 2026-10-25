AzerothStats = { version = "1.5.0-dev.1", schema = 1, importers = {} }

local A = AzerothStats

function A.Number(v)

 local n = tonumber(v)

 if n and n == n and n >= 0 and n < 1e100 then return n end

end

function A.Call(fn, a)

 if type(fn) ~= "function" then return nil end

 local ok, x, y, z = pcall(fn, a)

 if ok then return x, y, z end

 A.apiError = tostring(x)

end

function A.Copy(v, depth)

 if type(v) == "number" then return A.Number(v) end

 if type(v) == "string" then return string.sub(v, 1, 500) end

 if type(v) == "boolean" then return v end

 if type(v) ~= "table" or (depth or 5) <= 0 then return nil end

 local t, n = {}, 0

 for k, x in pairs(v) do

  n = n + 1

  if n > 256 then t._truncated = true; break end

  if type(k) == "string" or type(k) == "number" then t[k] = A.Copy(x, (depth or 5) - 1) end

 end

 return t

end

function A.Sign(v)

 if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end

 local keys, out = {}, {}

 for k in pairs(v) do table.insert(keys, k) end

 table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)

 for _, k in ipairs(keys) do table.insert(out, tostring(k) .. "=" .. A.Sign(v[k])) end

 return "{" .. table.concat(out, ";") .. "}"

end

function A.Say(s)

 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffedbd62Azeroth Stats|r : " .. s) end

end

function A.Format(v)

 if v == nil then return A.T and A.T("Unavailable") or "--" end

 if type(v) ~= "number" then return tostring(v) end

 local s=string.format("%.0f",v);local sep=",";local lg=A.Locale and A.Locale() or "en"

 if lg=="fr" or lg=="pl" or lg=="cs" or lg=="ru" or lg=="uk" then sep=" " elseif lg=="de" or lg=="es" or lg=="pt" or lg=="tr" or lg=="ro" then sep="." end

 local n=1

 while n>0 do s,n=string.gsub(s,"^(%-?%d+)(%d%d%d)","%1"..sep.."%2") end

 return s

end

function A.Duration(t)

 if not A.Number(t) then return A.T and A.T("Unavailable") or "--" end

 if t<3600 then return string.format("%02d:%02d",math.floor(t/60),math.mod(math.floor(t),60)) end

 return string.format("%d:%02d:%02d",math.floor(t/3600),math.mod(math.floor(t/60),60),math.mod(math.floor(t),60))

end

function A.Decimal(v,places)

 if type(v)~="number" or v~=v then return A.T("Unavailable") end

 local s=string.format("%."..(places or 1).."f",v)

 local lg=A.Locale()

 if lg=="fr" or lg=="de" or lg=="es" or lg=="pt" or lg=="pl" or lg=="cs" or lg=="ro" or lg=="tr" or lg=="ru" or lg=="uk" then s=string.gsub(s,"%.",",") end

 return s

end

function A.Short(v)

 if not A.Number(v) then return A.T("Unavailable") end

 if v>=1000000000 then return A.Decimal(v/1000000000,2).." G" end

 if v>=1000000 then return A.Decimal(v/1000000,2).." M" end

 if v>=10000 then return A.Decimal(v/1000,1).." k" end

 return A.Format(v)

end

function A.Rate(v) return v and A.Decimal(v,1) or A.T("Unavailable") end

function A.SpellIcon(name)

 if A.SourceName then A.SourceName(name) end

 local key=A.abilityKeys and A.abilityKeys[name]

 if not key and type(name)=="string" then local _,_,tail=string.find(name,":%s*(.+)$");key=tail and A.abilityKeys and A.abilityKeys[tail] end

 local builtin=key and A.gameSpellIcons and A.gameSpellIcons[key]

 if builtin then return builtin end

 if name=="Melee" then return "INV_Sword_04" end

 local now=A.Call(GetTime) or 0

 if not A.spellIcons or not A.iconScanAt or now>A.iconScanAt+10 then

  A.spellIcons=A.spellIcons or {};A.iconScanAt=now

  local n=A.Call(GetNumSpellTabs) or 0

  for tab=1,math.min(n,12) do

   if type(GetSpellTabInfo)=="function" then

    local ok,_,_,offset,count=pcall(GetSpellTabInfo,tab)

    if ok and type(offset)=="number" and type(count)=="number" then

     for i=offset+1,math.min(offset+count,512) do

      local spell,texture

      if type(GetSpellName)=="function" then local good,value=pcall(GetSpellName,i,BOOKTYPE_SPELL or "spell");if good then spell=value end end

      if type(GetSpellTexture)=="function" then local good,value=pcall(GetSpellTexture,i,BOOKTYPE_SPELL or "spell");if good then texture=value end end

      if spell and texture then A.spellIcons[spell]=texture end

     end

    end

   end

  end

 end

 return A.spellIcons[name] or "INV_Misc_Book_09"

end

function A.Wall() return A.Call(time) end

function A.Date(t)

 if not t or not date then return A.T("Unavailable") end

 local lg=A.Locale()

 return date((lg=="en" and "%m/%d %H:%M") or ((lg=="zh" or lg=="ja" or lg=="ko") and "%Y/%m/%d %H:%M") or "%d/%m %H:%M",t)

end

function A.Event(r, kind, text)

 if not r then return end

 table.insert(r.events, {t = r.values.duration, kind = kind, text = text})

 if table.getn(r.events) > 120 then table.remove(r.events, 1); r.eventsTruncated = true end

end


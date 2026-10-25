local A=AzerothStats
A.jewelSlots={2,11,12,13,14}
function A.InventorySignature()
 local t={}
 for _,slot in ipairs(A.jewelSlots) do
  if type(GetInventoryItemLink)=="function" then local ok,link=pcall(GetInventoryItemLink,"player",slot);if ok then t[slot]=link or "" end end
 end
 return A.Sign(t)
end
function A.JewelKey(link,cls)
 local _,_,name=string.find(link or "","%[(.-)%]")
 if not name then return nil end
 local _,_,base=string.find(name,"^(.-) [IVXLCDM]+$");name=base or name
 if not A.jewelKeys then
  A.jewelKeys={};A.jewelAbilityKeys={};A.amuletPrefixes={}
  for _,lang in pairs(A.gameText) do
   for k,v in pairs(lang) do
    if string.find(k,"^jewel%.") or string.find(k,"^amulet%.") then A.jewelKeys[v]=k end
    if string.find(k,"^ability%.") and string.find(k,"%.name$") then A.jewelAbilityKeys[v]=k end
   end
   for _,prefix in ipairs({"The Eternal Talisman","The Reaper's Amulet"}) do
    if lang[prefix] then table.insert(A.amuletPrefixes,{label=lang[prefix],kind=prefix,lang=lang}) end
   end
  end
 end
 if A.jewelKeys[name] then return A.jewelKeys[name],name end
 if not cls then local _,file=A.Call(UnitClass,"player");cls=string.lower(tostring(file or "")) end
 for _,prefix in ipairs(A.amuletPrefixes) do
  if string.sub(name,1,string.len(prefix.label))==prefix.label then
   local ability=string.gsub(string.sub(name,string.len(prefix.label)+1),"^%s*:%s*","")
   for key,value in pairs(prefix.lang) do
    if value==ability and string.find(key,"^ability%.") and string.find(key,"%.name$") and (not A.abilityClasses[string.sub(key,9,-6)] or A.abilityClasses[string.sub(key,9,-6)]==cls) then
     return (prefix.kind=="The Eternal Talisman" and "eternal:" or "reaper:")..key,name
    end
   end
  end
 end
 -- Synthetic inventory IDs are reused. The base name is safer than the numeric link ID.
 return "name:"..name,name
end
function A.JewelName(key,fallback)
 local prefix=string.sub(key,1,8)=="eternal:" and "The Eternal Talisman" or (string.sub(key,1,7)=="reaper:" and "The Reaper's Amulet")
 if prefix then
  local _,_,ability=string.find(key,"^[^:]+:(.+)$")
  return (A.G(prefix) or prefix)..": "..(A.G(ability) or fallback or "?")
 end
 return A.G(key) or fallback
end
local function aggregate(r,kind,key,entry)
 local u=r.usage;u.accounted=u.accounted or {};u.accounted[kind]=u.accounted[kind] or {}
 local old=u.accounted[kind][key] or {}
 for _,g in ipairs({A.db.totals,A.db.classes[r.class]}) do
  g.usage=g.usage or {};g.usage[kind]=g.usage[kind] or {}
  local rec=g.usage[kind][key] or {runs=0,gains=0,changes=0,maxRank=0}
  if not old.seen then rec.runs=rec.runs+1 end
  rec.gains=rec.gains+(entry.gains or 0)-(old.gains or 0)
  rec.changes=rec.changes+(entry.changes or 0)-(old.changes or 0)
  rec.maxRank=math.max(rec.maxRank,entry.maxRank or 0)
  rec.name=entry.name;rec.spell=entry.spell;rec.link=entry.link;rec.tooltip=entry.tooltip;rec.icon=entry.icon
  g.usage[kind][key]=rec
 end
 u.accounted[kind][key]={seen=true,gains=entry.gains or 0,changes=entry.changes or 0}
end
function A.ObserveBuild(r)
 if not A.db.classes[r.class] then A.db.classes[r.class]={} end
 r.usage=r.usage or {spells={},jewelry={},slots={}}
 local u=r.usage
 local fresh=not r.spellsBaseline or A.Sign(A.Copy(AZS_SPELLS))~=r.spellsBaseline or A.spellPacket
 if fresh and type(AZS_SPELLS)=="table" then
  for _,sp in ipairs(AZS_SPELLS) do
   local rank=A.Number(sp.rank)
   if type(sp.key)=="string" and rank and rank>0 then
    local e=u.spells[sp.key]
    if not e then e={name=sp.key,spell=sp.spell,maxRank=rank,lastRank=rank,gains=0};u.spells[sp.key]=e
    else
     if rank>e.maxRank then e.gains=e.gains+rank-e.maxRank end
     e.lastRank=rank;e.maxRank=math.max(e.maxRank,rank)
    end
    aggregate(r,"spells",sp.key,e)
   end
  end
 end
 local inventory=A.InventorySignature()
 if not r.inventoryBaseline or inventory~=r.inventoryBaseline then
  for _,slot in ipairs(A.jewelSlots) do
   local ok,link=false,nil
   if type(GetInventoryItemLink)=="function" then ok,link=pcall(GetInventoryItemLink,"player",slot) end
   if ok and type(link)=="string" then
    local key,name=A.JewelKey(link,r.class)
    if key then
     local lines=A.CaptureItem(slot);local sig=A.Sign(lines or link)
     local e=u.jewelry[key]
     if not e then e={name=name,changes=0};u.jewelry[key]=e end
     local old=u.slots[slot]
     if old and (old.key~=key or old.sig~=sig) then e.changes=e.changes+1 end
     e.link=link;e.tooltip=lines or e.tooltip;e.slot=slot
     if type(GetInventoryItemTexture)=="function" then local good,ic=pcall(GetInventoryItemTexture,"player",slot);if good then e.icon=ic end end
     u.slots[slot]={key=key,sig=sig};aggregate(r,"jewelry",key,e)
    end
   elseif ok then u.slots[slot]={key="",sig=""} end
  end
 end
 A.spellPacket=nil
end

function A.NormalizeJewelry()
 local d=A.db;d.migrations=d.migrations or {}
 if d.migrations.jewelry14 then return end
 local groups={d.totals};for _,g in pairs(d.classes) do table.insert(groups,g) end
 for _,g in ipairs(groups) do
  g.usage=g.usage or {};g.legacyJewelry14=g.usage.jewelry;g.usage.jewelry={}
 end
 for _,r in ipairs(d.runs) do
  local u=r.usage
  if u and u.jewelry then
   local old=u.jewelry;local merged={};local mapped={}
   for key,e in pairs(old) do
    local canonical,name=A.JewelKey(e.link or ("["..tostring(e.name or key).."]"),r.class);mapped[key]=canonical
    local out=merged[canonical]
    if not out then out={name=name,changes=0};merged[canonical]=out end
    out.changes=out.changes+(e.changes or 0)
    out.link=e.link;out.tooltip=e.tooltip or out.tooltip;out.icon=e.icon or out.icon;out.slot=e.slot
   end
   -- Prefer the last observed slot's description over arbitrary hash-table iteration order.
   for _,slot in pairs(u.slots or {}) do
    local entry=old[slot.key];local key=mapped[slot.key]
    if entry and key then local out=merged[key];out.link=entry.link;out.tooltip=entry.tooltip or out.tooltip;out.icon=entry.icon or out.icon end
    if key then slot.key=key end
   end
   u.jewelry=merged;u.accounted=u.accounted or {};u.accounted.jewelry={}
   if not d.classes[r.class] then d.classes[r.class]={} end
   for key,e in pairs(merged) do aggregate(r,"jewelry",key,e) end
  end
  if not r.zone and r.summary and type(r.summary.zone)=="string" then r.zone=r.summary.zone end
 end
 d.migrations.jewelry14={version=A.version,pruned=d.pruned or 0}
end

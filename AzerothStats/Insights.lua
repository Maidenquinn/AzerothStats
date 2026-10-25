local A=AzerothStats
local function partyState(r)
 r.coop=r.coop or {peers={},latest={},accounted={}}
 return r.coop
end
function A.BeginInsights(r)
 A.partySession={run=r,generation=A.partyGeneration or 0,stamp=AZS_PARTY_UPDATED,signature=A.Sign(A.Copy(AZS_PARTY))}
end
function A.PlayRecordSound()
 if type(PlaySoundFile)~="function" then return false end
 local ok,result=pcall(PlaySoundFile,"Sound\\interface\\LevelUp.wav")
 return ok and result~=false
end
local function dps(r,raw,ph)
 if r.status~="active" or (ph~="playing" and ph~="endless") then return end
 local elapsed,damage=A.Number(raw.t),A.Number(raw.dealt)
 if not elapsed or elapsed<10 or not damage then return end
 if r.dpsLastTime and (elapsed<r.dpsLastTime or damage<r.dpsLastDamage) then
  r.dpsCounterDecreased=true;return
 end
 if elapsed==r.dpsLastTime and damage==r.dpsLastDamage then return end
 r.dpsLastTime=elapsed;r.dpsLastDamage=damage
 if r.dpsBaseline==nil then
  local g=A.db.classes[r.class];local record=g and g.records and g.records.peakDps
  r.dpsBaseline=record and record.value or false
 end
 local rate=damage/elapsed
 if not A.Number(rate) then return end
 if rate>(r.values.peakDps or -1) then
  r.values.peakDps=rate;r.dpsSample={damage=damage,elapsed=elapsed,rate=rate}
 end
 if r.dpsBaseline and rate>r.dpsBaseline and not r.dpsRecordNotified then
  -- Saved before notification: reloads cannot replay the same milestone.
  r.dpsRecordNotified=true
  A.Say(A.T("New class DPS record").." · "..A.ClassName(r.class).." : "..A.Rate(rate))
  A.Event(r,"dps",tostring(rate))
  if A.db.settings.recordSound then A.PlayRecordSound() end
 end
end
local function party(r)
 local c=partyState(r)
 if type(AZS_PARTY)~="table" then c.unavailable="Party API unavailable";return end
 local session=A.partySession
 if not session or session.run~=r then A.BeginInsights(r);session=A.partySession end
 local signature=A.Sign(A.Copy(AZS_PARTY));local generation=A.partyGeneration or 0
 if generation==session.generation and AZS_PARTY_UPDATED==session.stamp and signature==session.signature then
  if not c.sampledAt then c.unavailable="No fresh party sample" end
  return
 end
 if AZS_PARTY_UPDATED==nil and generation==0 then c.unavailable="No fresh party sample";return end
 session.generation=generation;session.stamp=AZS_PARTY_UPDATED;session.signature=signature
 local latest,rows,seen={},{},{}
 local partial=table.getn(AZS_PARTY)>32
 local selfIncluded=false
 for i=1,math.min(table.getn(AZS_PARTY),32) do
  local item=AZS_PARTY[i]
  if type(item)=="table" and type(item.name)=="string" and string.len(item.name)>0 and string.len(item.name)<=80 and type(item.class)=="string" then
   local name=string.gsub(item.name,"[|%c]","");local cls=string.lower(item.class)
   if name~="" then
    local key=name..":"..cls
    if seen[key] then partial=true
    else
     seen[key]=true
     local own=name==r.hero and cls==r.class
     local clean={name=name,class=cls,damage=A.Number(item.dmg),dps=A.Number(item.dps),top=type(item.top)=="string" and item.top~="" and item.top or nil,topdps=A.Number(item.topdps),isSelf=own}
     table.insert(rows,clean)
     if own then selfIncluded=true
     else
      local e=c.peers[key]
      if not e then
       local count=0;for _ in pairs(c.peers) do count=count+1 end
       if count<64 then e={name=name,class=cls,firstSeen=r.values.duration};c.peers[key]=e else c.truncated=true end
      end
      if e then
       e.lastSeen=r.values.duration;e.damage=clean.damage;e.dps=clean.dps;e.top=clean.top;e.topdps=clean.topdps
       table.insert(latest,A.Copy(clean))
      end
     end
    end
   end
  else partial=true end
 end
 -- Keep the last actual multi-player sample after empty/out-of-party packets.
 if table.getn(latest)>0 then
  c.comparison={rows=rows,selfIncluded=selfIncluded,partial=partial,observedTime=r.values.duration,sampledAt=A.Wall(),source="AZSPARTY"}
 end
 c.latest=latest;c.sampledAt=A.Wall();c.unavailable=nil
end
function A.ObserveInsights(r,raw,ph)
 A.ObserveNemesis(r,raw,ph)
 dps(r,raw,ph)
 if r.status=="active" or r.status=="terminal" or r.status=="ended" then party(r) end
end
function A.AccountInsights(r)
 local c=r.coop
 if not c then return end
 for key,e in pairs(c.peers) do
  local old=c.accounted[key] or {}
  for _,g in ipairs({A.db.totals,A.db.classes[r.class]}) do
   g.companions=g.companions or {}
   local rec=g.companions[key]
   if not rec then
    local count=0;for _ in pairs(g.companions) do count=count+1 end
    if count<1024 then rec={name=e.name,class=e.class,runs=0,wins=0};g.companions[key]=rec else g.companionsTruncated=true end
   end
   if rec then
    if not old.seen then rec.runs=rec.runs+1 end
    if r.winCounted and not old.win then rec.wins=rec.wins+1 end
   end
  end
  c.accounted[key]={seen=true,win=r.winCounted or old.win}
 end
end

local function personalRow(r)
 local value,time,rate,source
 if r.status=="ended" and r.summary then value=A.Number(r.summary.dmg);time=A.Number(r.summary.t);source="Official result" end
 if not value and r.progress then value=A.Number(r.progress.dealt);time=A.Number(r.progress.t);source="Last sample" end
 if value and time and time>0 then rate=value/time end
 if not value and r.meters and r.meters.damage then value=A.Number(r.meters.damage.total);rate=A.Number(r.meters.damage.rate);source="Last sample" end
 local top,topdps,best=nil,nil,-1
 local meter=r.meters and r.meters.damage
 for _,e in ipairs(meter and meter.rows or {}) do
  local damage=A.Number(e.dmg)
  if damage and damage>best and type(e.name)=="string" then best=damage;top=e.name;topdps=A.Number(e.dps) end
 end
 return {name=r.hero or "?",class=r.class,isSelf=true,damage=value,dps=rate,top=top,topdps=topdps,observedTime=time,source=source or "Unavailable"}
end
function A.CoopComparison(r)
 local out={rows={},synchronized=false,ranked=false}
 if not r or not r.coop then return out end
 local c=r.coop;local sample=c.comparison
 if sample and type(sample.rows)=="table" and table.getn(sample.rows)>0 then
  out.rows=A.Copy(sample.rows);out.observedTime=sample.observedTime;out.synchronized=true;out.partial=sample.partial
  if not sample.selfIncluded then table.insert(out.rows,personalRow(r));out.synchronized=false;out.partial=true end
 else
  if not c.peers or not next(c.peers) then return out end
  -- Legacy 1.5-dev saved peers separately and discarded the player's matching party row.
  -- These are independent source samples: show their real values, but no team total/share/rank.
  table.insert(out.rows,personalRow(r));out.partial=true
  for _,e in pairs(c.peers) do
   table.insert(out.rows,{name=e.name,class=e.class,damage=e.damage,dps=e.dps,top=e.top,topdps=e.topdps,source="Last group snapshot",observedTime=e.lastSeen})
  end
 end
 local damage,rate=0,0;local completeDamage,completeRate=true,true
 for _,e in ipairs(out.rows) do
  if A.Number(e.damage) then damage=damage+e.damage else completeDamage=false end
  if A.Number(e.dps) then rate=rate+e.dps else completeRate=false end
  e.source=e.source or "Last group snapshot";e.observedTime=e.observedTime or out.observedTime
 end
 if not completeDamage or not completeRate then out.partial=true end
 if out.synchronized and not (sample and sample.partial) then
  if completeDamage then out.total=damage;out.ranked=true end
  if completeRate then out.rate=rate end
 end
 table.sort(out.rows,function(a,b)
  if out.ranked and a.damage~=b.damage then return a.damage>b.damage end
  if not out.ranked and a.isSelf~=b.isSelf then return a.isSelf and true or false end
  return tostring(a.name)<tostring(b.name)
 end)
 if out.ranked and damage>0 then for _,e in ipairs(out.rows) do e.fraction=e.damage/damage end end
 return out
end

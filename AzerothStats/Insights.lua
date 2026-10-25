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
 local latest={}
 for i=1,math.min(table.getn(AZS_PARTY),32) do
  local item=AZS_PARTY[i]
  if type(item)=="table" and type(item.name)=="string" and string.len(item.name)>0 and string.len(item.name)<=80 and type(item.class)=="string" and A.Number(item.dmg) and A.Number(item.dps) then
   local name=string.gsub(item.name,"[|%c]","");local cls=string.lower(item.class)
   if name~=r.hero and name~="" then
    local key=name..":"..cls
    local e=c.peers[key]
    if not e then
     local count=0;for _ in pairs(c.peers) do count=count+1 end
     if count<64 then e={name=name,class=cls,firstSeen=r.values.duration};c.peers[key]=e else c.truncated=true end
    end
    if e then
     e.lastSeen=r.values.duration;e.damage=item.dmg;e.dps=item.dps;e.top=item.top
     table.insert(latest,{name=name,class=cls,damage=item.dmg,dps=item.dps,top=item.top})
    end
   end
  end
 end
 c.latest=latest;c.sampledAt=A.Wall();c.unavailable=nil
end
function A.ObserveInsights(r,raw,ph)
 dps(r,raw,ph)
 if r.status=="active" then party(r) end
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

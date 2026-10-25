local A=AzerothStats
-- Audited legacy client chat templates, not the modern combat-log API.
local templates={
 {"COMBATHITOTHERSELF","%s hits you for %d.",1,2},
 {"COMBATHITCRITOTHERSELF","%s crits you for %d.",1,2},
 {"SPELLLOGOTHERSELF","%s's %s hits you for %d.",1,3},
 {"SPELLLOGCRITOTHERSELF","%s's %s crits you for %d.",1,3},
 {"PERIODICAURADAMAGEOTHERSELF","You suffer %d %s damage from %s's %s.",3,1}}
local function clean(s)
 if type(s)~="string" then return nil end
 s=string.gsub(s,"|c%x%x%x%x%x%x%x%x","");s=string.gsub(s,"|r","");s=string.gsub(s,"[%c|]","")
 return string.sub(s,1,140)
end
local function pattern(format)
 local out="^";local order={};local pos,index=1,0
 while pos<=string.len(format) do
  local _,finish,token=string.find(format,"^%%([sd])",pos)
  local number
  if not token then _,finish,number,token=string.find(format,"^%%(%d+)%$([sd])",pos) end
  if token then
   index=index+1;table.insert(order,tonumber(number) or index)
   out=out..(token=="d" and "([%d,]+)" or "(.-)");pos=finish+1
  else
   local ch=string.sub(format,pos,pos)
   if string.find("^$()%.[]*+-?",ch,1,true) then out=out.."%" end
   out=out..ch;pos=pos+1
  end
 end
 return out.."$",order
end
local function parse(message,format)
 if type(format)~="string" or string.len(format)>500 then return nil end
 local p,order=pattern(format);local found={string.find(message,p)}
 if not found[1] then return nil end
 local fields={};for i,n in ipairs(order) do fields[n]=found[i+2] end;return fields
end
function A.BeginDeathWatch(r)
 A.deathWatch={run=r,hits={},armed=false,closed=false}
end
function A.DeathEvidence(ev,message)
 local w=A.deathWatch
 if not A.db or not w or w.run~=A.run or not w.armed or type(message)~="string" or string.len(message)>1000 then return end
 local fields
 if ev=="UI_ERROR_MESSAGE" or ev=="CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
  -- This explicit native template is stronger evidence than a final observed hit.
  fields=parse(message,ERR_KILLED_BY_S)
  if fields and fields[1] and fields[1]~="" then
   w.explicit={source=clean(fields[1]),at=GetTime(),raw=clean(message)}
   if w.closed and w.last and GetTime()-w.lastClock<=2 then A.UpgradeDeath(w) end
  end
  return
 end
 if w.closed then return end
 for _,t in ipairs(templates) do
  fields=parse(message,getglobal(t[1]) or t[2])
  if fields then
   local source=clean(fields[t[3]]);local n=A.Number(string.gsub(fields[t[4]] or "",",",""))
   if source and source~="" and n and n>0 then
    table.insert(w.hits,{source=source,amount=n,at=GetTime(),raw=clean(message),event=ev})
    if table.getn(w.hits)>8 then table.remove(w.hits,1) end
   end
   return
  end
 end
 w.unparsed=w.unparsed or {};table.insert(w.unparsed,clean(message));if table.getn(w.unparsed)>8 then table.remove(w.unparsed,1) end
end
local function account(r,e,delta)
 for _,g in ipairs({A.db.totals,A.db.classes[r.class]}) do
  g.deathEvidence=g.deathEvidence or {deaths=0,sources={}}
  local t=g.deathEvidence
  if e.source then
   local key=e.source;local s=t.sources[key]
   if not s then
    local n=0;for _ in pairs(t.sources) do n=n+1 end
    if n>=512 then t.truncated=true
    else s={confirmed=0,probable=0};t.sources[key]=s end
   end
   if s then s[e.confidence]=math.max(0,(s[e.confidence] or 0)+delta) end
  end
 end
end
function A.UpgradeDeath(w)
 local r,e=w.run,w.last
 if not e or e.confidence=="confirmed" then return end
 account(r,e,-1);e.source=w.explicit.source;e.confidence="confirmed";e.explicit=w.explicit.raw;account(r,e,1)
end
function A.MarkDeath()
 local w=A.deathWatch
 if not w or not A.db or w.run~=A.run or not w.armed or w.closed then return end
 local r=w.run;local now=GetTime();w.closed=true;w.lastClock=now
 local e={at=A.Wall(),t=r.values.duration,confidence="unknown",hits={}}
 for _,h in ipairs(w.hits) do if now-h.at<=10 then local hit=A.Copy(h);hit.age=now-h.at;table.insert(e.hits,hit) end end
 local hit=w.hits[table.getn(w.hits)]
 if w.explicit and now-w.explicit.at<=2 then e.source=w.explicit.source;e.confidence="confirmed";e.explicit=w.explicit.raw
 elseif hit and now-hit.at<=2 then e.source=hit.source;e.confidence="probable" end
 e.unparsed=A.Copy(w.unparsed);r.deaths=r.deaths or {};table.insert(r.deaths,e);if table.getn(r.deaths)>20 then table.remove(r.deaths,1);r.deathsTruncated=true end
 w.last=e
 if not A.db.classes[r.class] then A.db.classes[r.class]={} end
 for _,g in ipairs({A.db.totals,A.db.classes[r.class]}) do g.deathEvidence=g.deathEvidence or {deaths=0,sources={}};g.deathEvidence.deaths=g.deathEvidence.deaths+1 end
 account(r,e,1)
end
function A.ObserveNemesis(r,raw,ph)
 local w=A.deathWatch
 if not w or w.run~=r then A.BeginDeathWatch(r);w=A.deathWatch end
 if ph=="dead" then A.MarkDeath()
 elseif ph=="playing" or ph=="endless" then
  if not w.closed then w.armed=true
  elseif A.Number(raw.hp) and tonumber(raw.hp)>0 and GetTime()-w.lastClock>2 then w.armed=true;w.closed=false;w.hits={};w.explicit=nil;w.unparsed=nil end
 end
end
function A.NemesisModel(m,g)
 m.rowHeight=43;m.capacity=9
 local t=g.deathEvidence or {deaths=0,sources={}};local sorted={}
 for name,s in pairs(t.sources) do if (s.confirmed or 0)+(s.probable or 0)>0 then table.insert(sorted,{name=name,s=s}) end end
 table.sort(sorted,function(x,y) local a=x.s.confirmed+x.s.probable;local b=y.s.confirmed+y.s.probable;if a==b then return x.name<y.name end;return a>b end)
 for _,v in ipairs(sorted) do
  table.insert(m.rows,{label=v.name,value=A.Format(v.s.confirmed).." · "..A.T("Confirmed").." / "..A.Format(v.s.probable).." · "..A.T("Probable"),detail=A.T("Last attacker is not proof of a killing blow"),icon=A.metricIcons.bosses})
 end
 for i=table.getn(A.db.runs),1,-1 do
  local r=A.db.runs[i]
  if not A.view.class or r.class==A.view.class then for j=table.getn(r.deaths or {}),1,-1 do
   local e=r.deaths[j];local id=r.id
   local evidence=A.T("Last attacker is not proof of a killing blow")
   if e.explicit then evidence=evidence.."\n"..e.explicit end
   for _,h in ipairs(e.hits or {}) do evidence=evidence.."\n"..(h.raw or h.source or "") end
   for _,raw in ipairs(e.unparsed or {}) do evidence=evidence.."\n"..raw end
   table.insert(m.rows,{exact=evidence,label=A.Date(e.at).." · "..(e.source or A.T("Unknown")),value=A.Duration(e.t),detail=A.ClassName(r.class).." · "..A.T(e.confidence=="confirmed" and "Confirmed" or e.confidence=="probable" and "Probable" or "Unknown"),action=function() A.SelectRun(id) end,favorite=A.RunFavorite(r)})
  end end
 end
 m.subtitle=A.T("Observed deaths").." : "..A.Format(t.deaths);m.note=A.T("Last attacker is not proof of a killing blow");m.emptyText=A.T((t.deaths or 0)>0 and "Unavailable" or "No death evidence recorded");if t.truncated then m.note=m.note.." · "..A.T("Partial") end
end

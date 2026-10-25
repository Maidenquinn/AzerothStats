local A = AzerothStats

A.tabs = {"Overview","Classes","History","Combat","Character","Records","Diagnostics","Settings","Usage","Favorites","Nemesis"}

A.view = {tab=1,page=1,mode="damage",characterTab="Spells",combatTab="Spells"}

A.metricIcons = {duration="INV_Misc_PocketWatch_01",kills="Ability_Warrior_Cleave",gold="INV_Misc_Coin_01",damage="Ability_Warrior_SavageBlow",healing="Spell_Holy_Heal",taken="INV_Shield_05",bosses="Ability_Creature_Cursed_02",elites="Ability_Creature_Cursed_01",guardians="Spell_Nature_ProtectionformNature",chests="INV_Box_01",magnets="Spell_Nature_Purge",level="INV_Misc_Book_09",peakDps="Spell_Nature_Lightning"}

local function row(out,label,value,detail,action,icon,fraction)

 local r={label=label,value=value or "",detail=detail or "",action=action,icon=icon,fraction=fraction}

 table.insert(out,r);return r

end

local function card(m,label,value,detail,icon,action)

 local c={label=label,value=value,detail=detail or "",icon=icon,action=action}

 table.insert(m.cards,c);return c

end

function A.Selected()

 if A.view.selected then

  for _,r in ipairs(A.db.runs) do if r.id==A.view.selected then return r end end

  A.view.selected=nil -- retention may have removed this detailed run

 end

 return A.run or A.db.runs[table.getn(A.db.runs)]

end

function A.Group() return A.view.class and (A.db.classes[A.view.class] or {}) or A.db.totals end

function A.SelectRun(id)

 A.view.selected=id;A.view.tab=4;A.view.cumulative=false;A.view.combatTab="Spells";A.view.page=1

end

function A.SelectCoopRun(id)
 A.view.selected=id;A.view.tab=9;A.view.usageTab="Co-op";A.view.cumulative=false;A.view.coopPartner=nil;A.view.page=1
end
function A.Coverage(g,key)

 return A.T("Coverage").." : "..A.Format(g.coverage and g.coverage[key] or 0).." / "..A.Format(g.runs or 0)

end

function A.EventLabel(e,r)

 local keys={dps="New class DPS record",start="Observed runs",resume="Probable resume; no server run ID",level="Rank",phase="Activity",summary="Official result",terminal="Ended",continue="Continued",boundary="Interrupted",checkpoint="Local storage"}

 local label=A.T(keys[e.kind] or "Activity");local detail=""

 if e.kind=="dps" then detail=A.Rate(A.Number(e.text))
 elseif e.kind=="level" then local _,_,n=string.find(e.text or "","(%d+)$");detail=n or ""

 elseif e.kind=="phase" then

  local _,_,before,after=string.find(e.text or "","^(%w+) %-> (%w+)$")

  if before then detail=A.Status(before).." > "..A.Status(after) end

 elseif e.kind=="summary" then local _,_,result=string.find(e.text or "",": (%w+)$");detail=A.Status(result)

 elseif e.kind=="start" and r.partial then detail=A.T("Partial observation") end

 return label,detail

end

local function overview(m,g)

 for _,e in ipairs({{"Observed runs",g.runs or 0,"INV_Misc_Book_09"},{"Wins",g.wins or 0,"INV_Misc_Coin_02"}}) do card(m,A.T(e[1]),A.Format(e[2]),A.T("Collected since installation"),e[3]) end

 for _,key in ipairs({"duration","kills","damage","gold"}) do

  local v=g.sum and g.sum[key]

  local c=card(m,key=="duration" and A.T("Play time") or A.Metric(key),key=="duration" and A.Duration(v) or A.Short(v),A.Coverage(g,key),A.metricIcons[key])

  c.exact=key=="duration" and A.Duration(v) or A.Format(v)

 end

 for _,key in ipairs({"healing","taken","bosses","elites","guardians","chests","magnets"}) do row(m.rows,A.Metric(key),A.Format(g.sum and g.sum[key]),A.Coverage(g,key),nil,A.metricIcons[key]) end

 m.note=A.T("Values from available samples")

end

local function classes(m)

 m.layout="classes"

 local keys={};for cls in pairs(A.db.classes) do table.insert(keys,cls) end;table.sort(keys)

 for _,cls in ipairs(keys) do

  local b=A.db.classes[cls];local chosen=cls

   local c=card(m,A.ClassName(cls),A.Format(b.runs or 0),A.T("Observed runs").." · "..A.Format(b.wins or 0).." "..A.T("Wins"),nil,function() A.view.class=chosen;A.view.tab=1;A.view.page=1 end)

  c.class=cls

 end

end

local function history(m)

 m.rowHeight=43;m.rowY=164;m.capacity=9

 for i=table.getn(A.db.runs),1,-1 do

  local r=A.db.runs[i];local id=r.id

  if not A.view.class or A.view.class==r.class then

   local item=row(m.rows,(r.hero or "?").." · "..A.ClassName(r.class),A.Duration(r.values.duration),A.Date(r.startedAt).." · "..A.ZoneName(r).." · "..A.Status(r.result or r.status)..(r.partial and " · "..A.T("Partial") or ""),function() A.SelectRun(id) end)

   item.favorite=A.RunFavorite(r);item.class=r.class;item.exact=r.id.." · "..A.Metric("kills").." "..A.Format(r.values.kills).." · "..A.Metric("level").." "..A.Format(r.values.level)

  end

 end

end

local function combat(m,r,g)

 m.rowY=301;m.rowHeight=28;m.capacity=10

 local mode=A.view.mode

 if A.view.combatTab=="Activity" then

  if A.view.cumulative then m.note=A.T("Current run");return end

  m.rowY=191;m.rowHeight=34;m.capacity=11

  if r then

   if r.official then row(m.rows,A.T("Official result"),A.Status(r.official.result),A.Duration(r.official.t)) end

   for _,key in ipairs({"bosses","elites","guardians","chests","magnets"}) do row(m.rows,A.Metric(key),A.Format(r.values[key]),key=="chests" and not r.summary and A.T("Chest count available in final summary") or "",nil,A.metricIcons[key]) end

   for i=table.getn(r.events),1,-1 do

   local e=r.events[i];local label,detail=A.EventLabel(e,r);row(m.rows,label,A.Duration(e.t),detail)

  end end

  return

 end

 local rows,total,rate={}

 if A.view.cumulative then

  if mode=="boss" then m.note=A.T("The last boss fight only");m.emptyText=A.T("Select a run for its last boss fight");return end

  for name,value in pairs(g.spells and g.spells[mode] or {}) do table.insert(rows,{name=name,dmg=value});total=(total or 0)+value end

  m.note=A.T("Values from available samples")

 elseif r then

  local meter=r.meters[mode]

  if meter then rows=meter.rows;total=meter.total;rate=meter.rate end

  m.note=mode=="boss" and A.T("The last boss fight only") or A.T("Values from available samples")

  if r.unavailable and r.unavailable[mode] then m.note=A.Reason(r.unavailable[mode]) end

 end

 card(m,A.T("Total"),A.Short(total),A.ModeName(mode),A.metricIcons[mode] or A.metricIcons.bosses).exact=A.Format(total)

 card(m,A.T("Per second"),A.Rate(rate),A.view.cumulative and A.T("Unavailable") or A.T("Last sample"),"Spell_Nature_Lightning")

 card(m,A.T("Play time"),A.view.cumulative and A.Duration(g.sum and g.sum.duration) or A.Duration(r and r.values.duration),A.T("Server time"),A.metricIcons.duration)

 local sorted={};for _,sp in ipairs(rows) do table.insert(sorted,sp) end

 table.sort(sorted,function(a,b) return a.dmg>b.dmg end)

 for i,sp in ipairs(sorted) do

  local share=total and total>0 and sp.dmg/total or 0

  local detail=A.T("Share").." "..A.Decimal(share*100,1).."%"

  if sp.dps then detail=detail.." · "..A.T("Per second").." "..A.Rate(sp.dps) end

  if sp.proc==1 then detail=detail.." · "..A.T("Proc") end

  local item=row(m.rows,A.SourceName(sp.name or sp.source),A.Short(sp.dmg),detail,nil,A.SpellIcon(sp.name),share)

  item.favorite={kind="spell",key=(not A.view.cumulative and r and (r.id..":") or "")..mode..":"..tostring(sp.name or sp.source),label=item.label,tab=4,mode=mode,class=A.view.cumulative and A.view.class or (r and r.class),cumulative=A.view.cumulative==true,runId=not A.view.cumulative and r and r.id or nil}
  item.rank=i;item.exact=A.Format(sp.dmg)

 end

end

local function character(m,r)

 m.rowY=193;m.rowHeight=31;m.capacity=12

 if not r then return end

 local section=A.view.characterTab or "Spells"

 if section=="Spells" then

  for _,sp in ipairs(r.spells or {}) do local item=row(m.rows,A.SpellName(sp),A.T("Rank").." "..A.Format(sp.rank),"",nil,A.SpellIcon(A.SpellName(sp)));item.favorite={kind="spell",key=sp.key or tostring(sp.spell or item.label),label=item.label,tab=9,section="Spells",class=r.class} end

 elseif section=="Equipment" then

  local extra={[2]="Neck",[4]="Shirt",[11]="Finger",[12]="Finger",[13]="Trinket",[14]="Trinket",[19]="Tabard"}

  local fallback={"INV_Helmet_03","INV_Jewelry_Necklace_01","INV_Shoulder_01","INV_Shirt_01","INV_Chest_Chain_04","INV_Belt_03","INV_Pants_06","INV_Boots_05","INV_Bracer_01","INV_Gauntlets_05","INV_Jewelry_Ring_03","INV_Jewelry_Ring_03","INV_Misc_Gem_Pearl_04","INV_Misc_Gem_Pearl_04","INV_Misc_Cape_03","INV_Sword_04","INV_Shield_05","INV_Weapon_Bow_01","INV_Shirt_01"}

  for slot=1,19 do if r.equipment and r.equipment[slot] then

   local jewel=slot==2 or (slot>=11 and slot<=14)

   local item=row(m.rows,r.equipment[slot],A.G("slot."..(slot-1)) or A.T(extra[slot] or "Slot"),A.T(jewel and "Run jewelry" or "Collection equipment"),nil,r.equipmentIcons and r.equipmentIcons[slot] or fallback[slot])

   item.link=r.equipment[slot];item.tooltip=r.equipmentTooltips and r.equipmentTooltips[slot];item.slot=slot;item.run=r;item.collection=not jewel;item.class=r.class

  end end

 elseif section=="Attributes" then

  -- Names and conversions audited against the installed MASH stat table.

  local known={{"hp","Health","number"},{"dmg","Damage","mult"},{"cd","Haste","cooldown"},{"crit","Crit","pct"},{"cm","Crit Dmg","pct"},{"arm","Armor","pct"},{"area","Area","mult"},{"cnt","Targets","number"},{"spd","Speed","mult"},{"reg","Regen","number"},{"lch","Lifesteal","pct"},{"heal","Kill Heal","number"},{"xp","Experience","mult"},{"gold","Gold","mult"},{"luck","Luck","pct"}}

  for _,def in ipairs(known) do

   local value=r.stats and A.Number(r.stats[def[1]])

   if value then

    local formatted=A.Decimal(value,1)

    if def[3]=="mult" then formatted=A.Decimal((value-1)*100,1).."%" elseif def[3]=="cooldown" then formatted=A.Decimal((1-value)*100,1).."%" elseif def[3]=="pct" then formatted=A.Decimal(value*100,1).."%" end

    row(m.rows,A.G(def[2]) or def[2],formatted,A.T("Last sample"))

   end

  end

 else

  for _,v in ipairs(r.timeline or {}) do row(m.rows,A.Duration(v.t),A.Metric("level").." "..A.Format(v.level),A.Metric("kills").." "..A.Format(v.kills).." · "..A.Metric("gold").." "..A.Format(v.gold)) end

 end

 m.note=A.T("Last sample").." · "..A.T("Values from available samples")

end

function A.PageModel()

 local tab,r,g=A.view.tab,A.Selected(),A.Group()

 local m={title=A.T(A.tabs[tab]),subtitle=A.T("Collected since installation"),cards={},rows={},rowY=164,rowHeight=31,capacity=12,layout="list"}

 if tab==1 then m.layout="overview";m.rowY=386;m.rowHeight=26;m.capacity=7;overview(m,g)

 elseif tab==2 then classes(m)

 elseif tab==3 then history(m)

 elseif tab==4 then

  m.layout="combat"

  m.subtitle=A.view.cumulative and (A.T("All runs").." · "..A.ModeName(A.view.mode).." · "..(A.view.class and A.ClassName(A.view.class) or A.T("All classes"))) or (A.Metric("level").." "..A.Format(r and r.values.level).." · "..A.Metric("kills").." "..A.Format(r and r.values.kills).." · "..A.Metric("gold").." "..A.Format(r and r.values.gold))

  combat(m,r,g)

 elseif tab==5 then m.subtitle=A.T("Last sample");character(m,r)

 elseif tab==6 then

  for _,key in ipairs(A.metrics) do

   local rec=g.records and g.records[key]

   local action

   if rec then for _,run in ipairs(A.db.runs) do if run.id==rec.id then local id=rec.id;action=function() A.SelectRun(id) end;break end end end

   row(m.rows,A.Metric(key),rec and (key=="duration" and A.Duration(rec.value) or (key=="peakDps" and A.Rate(rec.value) or A.Format(rec.value))) or A.T("Unavailable"),rec and (A.Date(rec.at).." · "..rec.id..(key=="peakDps" and (" · "..A.T("Server-sample run average (10s+)")) or "")) or "",action,A.metricIcons[key])

  end

  m.note=A.T("Values from available samples")

 elseif tab==7 then

  m.subtitle=A.T("Raw API identifiers are not translated")

  for _,d in ipairs(A.DiagnosticRows()) do row(m.rows,d[1],d[2],d[3]) end

  if r then

   row(m.rows,A.T("Quality"),r.partial and A.T("Partial observation") or A.T("Available"),r.resumeHeuristic and A.T("Probable resume; no server run ID") or "")

   for k,v in pairs(r.summary or {}) do if type(v)~="table" then row(m.rows,"AZS_END."..k,A.Format(v)) end end

   for k,v in pairs(r.progress or {}) do if type(v)~="table" then row(m.rows,"AZS_RUN."..k,A.Format(v)) end end

  end

 elseif tab==8 then m.layout="settings";m.subtitle=A.T("Changes apply immediately")

 elseif tab==9 then

  m.rowY=200;m.rowHeight=46;m.capacity=8

  if A.view.usageTab=="Co-op" then
   if A.view.cumulative then
    if A.view.coopPartner then
     local name=A.view.coopPartner
     for i=table.getn(A.db.runs),1,-1 do
      local run=A.db.runs[i];local peer=run.coop and run.coop.peers and run.coop.peers[name]
      if peer and (not A.view.class or run.class==A.view.class) then
       local id=run.id
       local item=row(m.rows,A.Date(run.startedAt).." · "..A.ZoneName(run),A.Duration(run.values.duration).." · "..A.Status(run.result or run.status),peer.name.." · "..A.Short(peer.damage).." · "..A.Rate(peer.dps).." DPS",function() A.SelectCoopRun(id) end)
       item.class=run.class
      end
     end
     m.subtitle=A.T("History").." · "..A.view.coopPartner
     m.note=A.T("Historical details may be pruned")
    else
     local sorted={};for key,e in pairs(g.companions or {}) do table.insert(sorted,{key=key,e=e}) end
     table.sort(sorted,function(a,b) if (a.e.runs or 1)==(b.e.runs or 1) then return a.key<b.key end;return (a.e.runs or 1)>(b.e.runs or 1) end)
     for _,v in ipairs(sorted) do
      local e,key=v.e,v.key
      local item=row(m.rows,e.name,A.Format(e.runs or 1).." · "..A.T("Runs observed"),A.ClassName(e.class).." · "..A.T("Victories in observed runs").." "..A.Format(e.wins).." · "..A.T("History"),function() A.view.coopPartner=key;A.view.page=1 end)
      item.class=e.class;item.favorite={kind="companion",key=key,label=e.name}
     end
     m.subtitle=A.T("All runs");m.note=A.T("Observed names only").." · "..A.T("Click to inspect")
    end
   else
    local comparison=A.CoopComparison(r)
    m.layout="combat";m.rowY=301;m.capacity=6
    card(m,A.T("Group damage"),A.Short(comparison.total),A.T("Last group snapshot"),A.metricIcons.damage).exact=A.Format(comparison.total)
    card(m,A.T("Group DPS"),A.Rate(comparison.rate),A.T("Last group snapshot"),"Spell_Nature_Lightning")
    card(m,A.T("Players in sample"),A.Format(table.getn(comparison.rows)),A.T("Last sample").." · "..A.Duration(comparison.observedTime),A.metricIcons.duration)
    for i,e in ipairs(comparison.rows) do
     local label=(comparison.ranked and (i..". ") or "")..e.name..(e.isSelf and (" · "..A.T("You")) or "")
     local detail=A.ClassName(e.class)
     if e.fraction then detail=detail.." · "..A.T("Share of sampled damage").." "..A.Decimal(e.fraction*100,1).."%" end
     detail=detail.." · "..A.T("Top spell").." : "..(e.top and A.SourceName(e.top) or A.T("Unavailable"))
     if e.topdps then detail=detail.." ("..A.Rate(e.topdps).." DPS)" end
     if not comparison.synchronized then detail=detail.." · "..A.T(e.source).." · "..A.Duration(e.observedTime) end
     local item=row(m.rows,label,A.Short(e.damage).." · "..A.Rate(e.dps).." DPS",detail,nil,nil,e.fraction)
     item.class=e.class;item.player=e.name;item.exact=A.T("Damage").." "..A.Format(e.damage).." · "..A.Rate(e.dps).." DPS"
    end
    m.subtitle=comparison.ranked and A.T("Party damage ranking") or A.T("Co-op")
    m.note=A.T(comparison.synchronized and "Last group snapshot" or "Partial comparison: independent samples").." · "..A.T("Other players' healing and kills are unavailable")
    if comparison.partial and comparison.synchronized then m.note=A.T("Partial").." · "..m.note end
    if table.getn(comparison.rows)==0 then
     m.cards={};m.emptyText=A.T("No group snapshot recorded");m.note=r and r.coop and r.coop.unavailable and A.T(r.coop.unavailable) or A.T("No group snapshot recorded")
    end
   end
   if g.companionsTruncated or (r and r.coop and r.coop.truncated) then m.note=m.note.." · "..A.T("Partial") end
  else
  local kind=A.view.usageTab=="Jewelry" and "jewelry" or "spells"

  local source=A.view.cumulative and g or r

  local entries=source and source.usage and source.usage[kind] or {}

  local sorted={};for key,e in pairs(entries) do table.insert(sorted,{key=key,e=e}) end

  table.sort(sorted,function(a,b)
   if (a.e.runs or 1)~=(b.e.runs or 1) then return (a.e.runs or 1)>(b.e.runs or 1) end
   local av,bv=a.e.gains or a.e.changes or 0,b.e.gains or b.e.changes or 0
   if av~=bv then return av>bv end;return a.key<b.key
  end)

  for _,v in ipairs(sorted) do

   local e,key=v.e,v.key

   local label=kind=="spells" and A.SpellName({key=key,spell=e.spell}) or A.JewelName(key,e.name)

   local detail=kind=="spells" and (A.T("Observed rank gains").." "..A.Format(e.gains).." · "..A.T("Maximum rank").." "..A.Format(e.maxRank)) or (A.T("Observed item changes").." "..A.Format(e.changes))

   local item=row(m.rows,label,A.Format(e.runs or 1).." · "..A.T("Runs observed"),detail,nil,kind=="spells" and A.SpellIcon(label) or e.icon)

   item.favorite={kind=kind=="spells" and "spell" or "jewelry",key=key,label=label,tab=9,section=kind=="spells" and "Spells" or "Jewelry",class=A.view.class,display={link=e.link,tooltip=e.tooltip,icon=e.icon,label=label}}
   if kind=="jewelry" then item.link=e.link;item.tooltip=e.tooltip end

  end

  m.subtitle=A.T(A.view.cumulative and "All runs" or "Current run").." · "..(A.view.class and A.ClassName(A.view.class) or A.T("All classes"))

  m.note=A.T("Build observations since 1.3; not clicks or casts")
  end

 end

 if tab==10 then A.FavoritesModel(m) elseif tab==11 then A.NemesisModel(m,g) end
 A.DecorateFavorites(m,tab,r)
 if table.getn(m.rows)==0 and table.getn(m.cards)==0 and tab~=8 then m.empty=true end

 return m

end

function A.Rows() return A.PageModel().rows end


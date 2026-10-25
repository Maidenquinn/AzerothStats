local A=AzerothStats
A.favoriteCategories={{"run","History"},{"combat","Combat"},{"spell","Spells"},{"item","Equipment"},{"jewelry","Jewelry"},{"companion","Co-op"}}
function A.FavoriteCategory(e)
 if e.kind=="spell" and e.tab==4 then return "combat" end
 return e.kind
end
function A.FavoriteCategoryLabel(key)
 for _,c in ipairs(A.favoriteCategories) do if c[1]==key then return c[2] end end
 return "History"
end
function A.FavoriteCounts()
 local counts={}
 for _,e in pairs(A.db.favorites.entries) do
  if not A.view.class or e.class==A.view.class then local key=A.FavoriteCategory(e);counts[key]=(counts[key] or 0)+1 end
 end
 return counts
end
function A.IsRunProtected(id)
 for _,e in pairs(A.db.favorites.entries) do
  if (e.kind=="run" and e.key==id) or (A.FavoriteCategory(e)=="combat" and e.runId==id) then return true end
 end
 return false
end
local kinds={run=true,spell=true,jewelry=true,item=true,companion=true}
function A.FavoriteId(kind,key) return kind..":"..key end
function A.IsFavorite(kind,key)
 return A.db and A.db.favorites and A.db.favorites.entries[A.FavoriteId(kind,key)]~=nil
end
function A.ToggleFavorite(d)
 if not d or not kinds[d.kind] or type(d.key)~="string" or string.len(d.key)>600 then return false end
 local entries=A.db.favorites.entries;local id=A.FavoriteId(d.kind,d.key)
 if entries[id] then entries[id]=nil;return false end
 local count,runs,protected=0,0,{}
 for _,e in pairs(entries) do
  count=count+1
  local id=e.kind=="run" and e.key or (A.FavoriteCategory(e)=="combat" and e.runId)
  if id and not protected[id] then protected[id]=true;runs=runs+1 end
 end
 local pin=d.kind=="run" and d.key or (A.FavoriteCategory(d)=="combat" and d.runId)
 if count>=300 or (pin and not protected[pin] and runs>=200) then A.Say(A.T("Favorite limit reached"));return false end
 local saved=A.Copy(d,8);saved.key=d.key;saved.at=A.Wall();entries[id]=saved;return true
end
function A.RunFavorite(r)
 if not r then return nil end
 return {kind="run",key=r.id,label=(r.hero or "?").." · "..A.ClassName(r.class),class=r.class,runId=r.id,startedAt=r.startedAt,tab=4,mode="damage"}
end
function A.OpenFavorite(e)
 if e.runId then
  local exists=false;for _,r in ipairs(A.db.runs) do if r.id==e.runId then exists=true;break end end
  if not exists then A.Say(A.T("Source run no longer retained"));return end
 end
 if e.kind=="run" then A.SelectRun(e.key)
 elseif e.kind=="companion" then A.view.tab=9;A.view.usageTab="Co-op";A.view.cumulative=true;A.view.coopPartner=e.key;A.view.class=nil
 else
  A.view.tab=e.tab or 9;A.view.mode=e.mode or "damage";A.view.usageTab=e.section or "Spells";A.view.characterTab="Equipment"
  if e.tab==4 then A.view.cumulative=e.cumulative~=false;A.view.combatTab="Spells" else A.view.cumulative=e.tab~=5 end
  A.view.selected=e.runId;A.view.class=e.class
 end
 A.view.page=1;A.view.focusFavorite=A.FavoriteId(e.kind,e.key);A.view.highlightFavorite=A.view.focusFavorite
end
function A.FavoritesModel(m)
 m.rowHeight=46;m.rowY=200;m.capacity=8
 local category=A.view.favoriteCategory or "run"
 local sorted={}
 for _,e in pairs(A.db.favorites.entries) do if A.FavoriteCategory(e)==category and (not A.view.class or e.class==A.view.class) then table.insert(sorted,e) end end
 table.sort(sorted,function(x,y) if x.kind~=y.kind then return x.kind<y.kind end;return x.at>y.at end)
 for _,e in ipairs(sorted) do
  local entry=e;local d=A.Copy(e.display or {})
  if e.kind=="run" then
   for _,r in ipairs(A.db.runs) do if r.id==e.key then d.detail=A.Date(r.startedAt).." · "..A.ZoneName(r).." · "..A.Status(r.result or r.status);d.value=A.Duration(r.values.duration);break end end
  end
  d.label=e.kind=="run" and (A.T("Run").." · "..A.Date(e.startedAt or e.at)) or e.label
  if e.kind=="spell" then d.label=A.G("ability."..e.key..".name") or A.SourceName(e.label) elseif e.kind=="jewelry" then d.label=A.JewelName(e.key,e.label) end
  if category=="combat" then
   local _,_,source=string.find(e.key,e.runId and "^[^:]+:[^:]+:(.+)$" or "^[^:]+:(.+)$")
   d.label=A.SourceName(source or e.label)
   d.detail=A.ModeName(e.mode or "damage").." · "..A.T("All runs");d.value=A.T("All runs")
   if e.runId then for _,r in ipairs(A.db.runs) do if r.id==e.runId then d.detail=A.Date(r.startedAt).." · "..A.ClassName(r.class).." · "..A.ZoneName(r).." · "..A.ModeName(e.mode or "damage");d.value=A.Duration(r.values.duration);break end end end
  end
  d.value=d.value or A.T(category=="combat" and "Combat" or e.kind=="run" and "Run" or e.kind=="companion" and "Co-op" or e.kind=="spell" and "Spells" or e.kind=="jewelry" and "Jewelry" or "Equipment")
  d.detail=d.detail or (e.class and A.ClassName(e.class).." · " or "")..A.T("Click to inspect")
  d.favorite=e;d.action=function() A.OpenFavorite(entry) end;d.class=e.class or d.class
  table.insert(m.rows,d)
 end
 m.subtitle=A.T(A.FavoriteCategoryLabel(category)).." · "..A.Format(table.getn(sorted));m.note=A.T("Favorite runs are protected from history pruning");m.emptyText=A.T("No favorites in this category").."\n"..A.T("Use the heart to save a favorite")
end
function A.DecorateFavorites(m,tab,r)
 for _,d in ipairs(m.rows) do
  if not d.favorite and d.link then
   local _,_,id=string.find(d.link,"item:(%d+)")
   local jewelKey,base;if not d.collection then jewelKey,base=A.JewelKey(d.link,d.class or (r and r.class)) end
   d.favorite={kind=d.collection and "item" or "jewelry",key=d.favoriteKey or jewelKey or id or d.link,label=jewelKey and A.JewelName(jewelKey,base) or d.label,class=d.class or (r and r.class),tab=5,runId=r and r.id,display={label=d.label,link=d.link,tooltip=d.tooltip,icon=d.icon,class=d.class,collection=d.collection}}
  end
 end
end

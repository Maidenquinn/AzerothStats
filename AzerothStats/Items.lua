local A=AzerothStats
local function readLines(tip)
 local lines={};local count=tip.NumLines and A.Number(tip:NumLines()) or 0
 for i=1,math.min(count or 0,40) do
  local left=getglobal("AzerothStatsItemScanTextLeft"..i);local right=getglobal("AzerothStatsItemScanTextRight"..i)
  local text=left and left:GetText()
  if type(text)=="string" and text~="" then
   local r,g,b=1,1,1;if left.GetTextColor then r,g,b=left:GetTextColor() end
   table.insert(lines,{text=string.sub(text,1,1500),right=right and right:GetText(),r=r,g=g,b=b})
  end
 end
 tip:Hide();if table.getn(lines)>0 then return lines end
end
function A.CaptureItem(slot,link)
 if not A.itemTip then A.itemTip=CreateFrame("GameTooltip","AzerothStatsItemScan",UIParent,"GameTooltipTemplate") end
 local tip=A.itemTip
 local ok=pcall(function()
  tip:SetOwner(UIParent,"ANCHOR_NONE");tip:ClearLines()
  if link then tip:SetHyperlink(link) else tip:SetInventoryItem("player",slot) end
 end)
 if ok then return readLines(tip) end
 tip:Hide()
end
local function itemId(link)
 local _,_,id=string.find(link or "","item:(%d+)");return id
end
function A.CollectionReference(link)
 local id=itemId(link)
 if not id then return nil end
 -- Old runs may lack descriptions: reuse a newer observation of this static collection item.
 for i=table.getn(A.db.runs),1,-1 do
  local r=A.db.runs[i]
  for slot,value in pairs(r.equipment or {}) do
   if slot~=2 and (slot<11 or slot>14) and itemId(value)==id then
    local lines=r.equipmentTooltips and r.equipmentTooltips[slot]
    if lines and table.getn(lines)>1 then return lines end
   end
  end
 end
 local lines=A.CaptureItem(nil,link)
 if lines and table.getn(lines)>1 then return lines end
end
local function dropSources(d)
 if not d.collection then return end
 local _,_,name=string.find(d.link or "","%[(.-)%]")
 local aliases=A.collectionAliases[d.class] or {}
 local canonical=aliases[name or ""] or name
 local sources=A.collectionSources[d.class] and A.collectionSources[d.class][canonical or ""]
 if not sources then return end
 GameTooltip:AddLine(A.T("Loot catalog"),.9,.75,.4)
 for _,source in ipairs(sources) do
  local boss=A.G(source.boss) or source.boss
  GameTooltip:AddLine(boss.." · "..A.ZoneName({zone=source.zone}).." · "..A.Duration((source.minute or 0)*60),.85,.75,.55,true)
  GameTooltip:AddLine(A.T("Base drop chance").." : "..A.Format(source.chance).."%",.7,.7,.6,true)
 end
end
function A.ItemTooltip(frame,d)
 if not d.link then return false end
 GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:ClearLines()
 if d.run==A.run and d.slot and type(GetInventoryItemLink)=="function" then
  local ok,link=pcall(GetInventoryItemLink,"player",d.slot)
  if ok and link==d.link then
   local good,has=pcall(function() return GameTooltip:SetInventoryItem("player",d.slot) end)
   if good and has then dropSources(d);GameTooltip:Show();return true end
  end
 end
 local lines=d.tooltip;local reference=false
 if (not lines or table.getn(lines)==0) and d.collection then lines=A.CollectionReference(d.link);reference=lines~=nil end
 if lines and table.getn(lines)>0 then
  for _,line in ipairs(lines) do
   if line.right and line.right~="" and GameTooltip.AddDoubleLine then GameTooltip:AddDoubleLine(line.text,line.right,line.r or 1,line.g or 1,line.b or 1,1,1,1)
   else GameTooltip:AddLine(line.text,line.r or 1,line.g or 1,line.b or 1,true) end
  end
  GameTooltip:AddLine(A.T(reference and "Current collection reference" or "Captured item description"),.6,.6,.6,true)
 else
  GameTooltip:AddLine(d.label or "",1,.82,.4)
  GameTooltip:AddLine(A.T("Item description unavailable"),.7,.7,.7,true)
 end
 dropSources(d);GameTooltip:Show();return true
end

local A = AzerothStats

local U = {fonts={},solids={},cards={},rows={},nav={},controls={}}

A.ui=U

local C={gold={0.91,0.74,0.43},text={0.87,0.84,0.77},muted={0.56,0.54,0.48},green={0.5,0.76,0.5}}

local coords={warrior={0,.25,0,.25},mage={.25,.496,0,.25},rogue={.496,.742,0,.25},druid={.742,.988,0,.25},hunter={0,.25,.25,.5},shaman={.25,.496,.25,.5},priest={.496,.742,.25,.5},warlock={.742,.988,.25,.5},paladin={0,.25,.5,.75}}

local function font(parent,x,y,w,h,size,color,title)

 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")

 t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);t:SetWidth(w);t:SetHeight(h);t:SetJustifyH("LEFT");t:SetJustifyV("MIDDLE")

 t.baseSize=size or 12;t.titleFont=title;t.fontWidth=w

 color=color or C.text;t:SetTextColor(color[1],color[2],color[3])

 table.insert(U.fonts,t);return t

end

local function put(t,value)

 value=tostring(value or "")

 local size=t.baseSize*(t.titleFont and 1 or ((A.db and A.db.settings.textSize or 12)/12))

 local path=A.Font(t.titleFont,t.localeFont)

 if t.fullText==value and t.paintFont==path and t.paintBase==size then return end

 t.fullText=value;t.paintFont=path;t.paintBase=size

 if t.activeFont~=path or t.activeSize~=size then t:SetFont(path,size,"") end

 t:SetText(value)

 if t.GetStringWidth then

  while size>10 and t:GetStringWidth()>t.fontWidth do size=size-0.5;t:SetFont(path,size,"") end

 end

 t.activeFont=path;t.activeSize=size

end

local function solid(parent,r,g,b,alpha,layer)

 local t=parent:CreateTexture(nil,layer or "BACKGROUND");t:SetAllPoints(parent);t:SetTexture(r,g,b);t:SetAlpha(alpha or 1);return t

end

local function surface(f,kind)

 local base=solid(f,kind=="card" and .075 or .028,kind=="card" and .061 or .023,kind=="card" and .038 or .018,1)

 table.insert(U.solids,{texture=base,main=kind=="main"})

 f:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Gold-Border",edgeSize=kind=="main" and 20 or 10,insets={left=1,right=1,top=1,bottom=1}})

 f:SetBackdropBorderColor(.46,.35,.18,1);f.base=base

 return base

end

local function icon(tex,name,cls)

 if cls and coords[cls] then

  tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes");tex:SetTexCoord(unpack(coords[cls]))

 else

  name=name or "INV_Misc_Book_09"

  if not string.find(name,"\\",1,true) and not string.find(name,"/",1,true) then name="Interface\\Icons\\"..name end

  tex:SetTexture(name);tex:SetTexCoord(.07,.93,.07,.93)

 end

end

local function tooltip(f)

 if not f.item then return end

 local d=f.item

 if A.ItemTooltip(f,d) then return end

 GameTooltip:SetOwner(f,"ANCHOR_RIGHT");GameTooltip:AddLine(d.label or "Azeroth Stats",.95,.8,.5)

 if d.value then GameTooltip:AddLine(d.exact or d.value,.94,.92,.87) end

 if d.detail and d.detail~="" then GameTooltip:AddLine(d.detail,.7,.68,.61,true) end

 if d.action then GameTooltip:AddLine(A.T("Click to inspect"),.5,.8,.5) end

 GameTooltip:Show()

end

local function selected(b,active)

 b.selected=active and true or false

 b.base:SetTexture(active and .22 or .028,active and .12 or .023,active and .035 or .018)

 b.base:SetAlpha(A.db.settings.opacity)

 b:SetBackdropBorderColor(active and 1 or .46,active and .72 or .35,active and .28 or .18,1)

 if b.marker then if active then b.marker:Show() else b.marker:Hide() end end

end

local function dropdown(b)

 b.arrow=b:CreateTexture(nil,"ARTWORK");b.arrow:SetPoint("RIGHT",b,"RIGHT",-5,0);b.arrow:SetWidth(20);b.arrow:SetHeight(20)

 b.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")

 b.label:SetWidth(b:GetWidth()-40);b.label.fontWidth=b:GetWidth()-40

end

local function button(parent,x,y,w,h,label,fn)

 local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);b:SetWidth(w);b:SetHeight(h or 27)

 surface(b,"button");b.label=font(b,10,0,w-20,h or 27,12,C.gold)

 b.key=label;b.callback=fn

 b:SetScript("OnClick",function() if this.callback then this.callback(this) end end)

 b:SetScript("OnEnter",function() this:SetBackdropBorderColor(.9,.7,.34,1) end)

 b:SetScript("OnLeave",function() selected(this,this.selected) end)

 table.insert(U.controls,b);return b

end

local function selectTab(i)

 A.view.tab=i;A.view.page=1;if i==9 then A.view.cumulative=true end

 if U.menu then U.menu:Hide() end

 A.RefreshUI()

end

local function drag(f,key)

 f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")

 if f.SetClampedToScreen then f:SetClampedToScreen(true) end

 f:SetScript("OnDragStart",function() if not A.db.settings.locked then this:StartMoving() end end)

 f:SetScript("OnDragStop",function()

  this:StopMovingOrSizing();local p,_,rel,x,y=this:GetPoint();A.db.settings[key]={p,rel,x,y}

 end)

end

local function place(f,key,p,x,y)

 local s=A.db.settings[key];f:ClearAllPoints()

 if type(s)=="table" and type(s[1])=="string" and type(s[2])=="string" and type(s[3])=="number" and type(s[4])=="number" then

  f:SetPoint(s[1],UIParent,s[2],math.max(-600,math.min(600,s[3])),math.max(-450,math.min(450,s[4])))

 else f:SetPoint(p,UIParent,p,x,y) end

end

function A.ShowMenu(anchor,options,offset)

 if not offset and U.menu and U.menu.anchor==anchor and U.menu:IsShown() then U.menu:Hide();return end

 if not U.menu then

  U.menu=CreateFrame("Frame","AzerothStatsMenu",A.window);surface(U.menu,"main");U.menu:SetFrameStrata("DIALOG");U.menu:SetFrameLevel(A.window:GetFrameLevel()+30);U.menu.items={}

 end

 local menu=U.menu

 if menu.SetClampedToScreen then menu:SetClampedToScreen(true) end

 local all=options;offset=offset or 1

 if table.getn(all)>15 then

  options={}

  if offset>1 then table.insert(options,{label="<  "..A.T("Page"),action=function() A.ShowMenu(anchor,all,math.max(1,offset-12)) end}) end

  for i=offset,math.min(table.getn(all),offset+11) do table.insert(options,all[i]) end

  if offset+12<=table.getn(all) then table.insert(options,{label=A.T("Page").."  >",action=function() A.ShowMenu(anchor,all,offset+12) end}) end

 end

 menu.anchor=anchor;menu:ClearAllPoints();menu:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-3);menu:SetWidth(268);menu:SetHeight(table.getn(options)*24+12)

 for i,entry in ipairs(options) do

  local b=menu.items[i]

  if not b then

   b=button(menu,6,6+(i-1)*24,256,24,"",function(self)

    local action=self.option.action;menu:Hide();action();A.RefreshUI()

   end);menu.items[i]=b

  end

  b.option=entry;b.label.localeFont=entry.locale;put(b.label,entry.label);b:Show()

 end

 for i=table.getn(options)+1,table.getn(menu.items) do menu.items[i]:Hide() end

 menu:Show()

end

function A.CycleClass()

 local options={{label=A.T("All classes"),action=function() A.view.class=nil;A.view.page=1 end}}

 local keys={};for cls in pairs(A.db.classes) do table.insert(keys,cls) end;table.sort(keys)

 for _,cls in ipairs(keys) do local c=cls;table.insert(options,{label=A.ClassName(c),action=function() A.view.class=c;A.view.page=1 end}) end

 A.ShowMenu(U.classButton,options)

end

function A.RunMenu(anchor)

 local options={{label=A.T(A.run and A.run.status=="active" and "Current run" or "Latest run"),action=function() A.view.selected=nil;A.view.cumulative=false;A.view.page=1 end}}

 for i=table.getn(A.db.runs),1,-1 do

  local r=A.db.runs[i];local id=r.id

  if r~=(A.run or A.db.runs[table.getn(A.db.runs)]) then

  table.insert(options,{label=A.Date(r.startedAt).." · "..A.ClassName(r.class).." · "..A.Duration(r.values.duration),action=function() A.view.selected=id;A.view.cumulative=false;A.view.page=1 end})

  end

 end

 A.ShowMenu(anchor,options)

end

function A.CommitSliders()

 local changed=false

 for _,sl in ipairs(U.sliders or {}) do

  if sl.pending then A.db.settings[sl.setting]=sl.pending;sl.pending=nil;sl.pendingAt=nil;changed=true end

  sl.dragging=nil

 end

 if changed then A.ApplyUI();A.RefreshUI() end

end

function A.ApplyUI()

 if not A.window then return end

 local s=A.db.settings

 local fit=math.min(s.scale,math.max(.45,(UIParent:GetWidth()-24)/960),math.max(.45,(UIParent:GetHeight()-40)/650))

 U.effectiveScale=fit

 local old=A.window:GetScale()

 if old~=fit then

  -- Keep the saved physical anchor stable while changing the window's coordinate scale.

  local p,parent,rel,x,y=A.window:GetPoint()

  A.window:SetScale(fit)

  if p and x and y then

   A.window:ClearAllPoints();A.window:SetPoint(p,parent,rel,x*old/fit,y*old/fit)

   if s.windowPos then s.windowPos={p,rel,x*old/fit,y*old/fit} end

  end

 end

 for _,t in ipairs(U.fonts) do put(t,t.fullText or "") end

 for _,v in ipairs(U.solids) do v.texture:SetAlpha(s.opacity) end

 if U.menu then U.menu.base:SetAlpha(1) end

 if s.bar then A.bar:Show() else A.bar:Hide() end

 if s.minimap then A.mini:Show() else A.mini:Hide() end

end

function A.ResetPosition()

 A.db.settings.windowPos=nil;A.db.settings.barPos=nil;A.db.settings.miniAngle=.785398

 place(A.window,"windowPos","CENTER",0,0);place(A.bar,"barPos","TOP",0,-2)

 A.mini:ClearAllPoints();A.mini:SetPoint("CENTER",Minimap or UIParent,"CENTER",56,56)

end

local function show(f,yes) if yes then f:Show() else f:Hide() end end

local function settingsRefresh()

 local s=A.db.settings

 for _,b in ipairs(U.checks) do b:SetChecked(s[b.setting]);put(b.caption,A.T(b.key)) end

 for _,sl in ipairs(U.sliders) do

  local value=sl.pending or s[sl.setting];if not sl.dragging then sl.syncing=true;sl:SetValue(value);sl.syncing=nil end

  put(sl.caption,A.T(sl.key));put(sl.number,sl.setting=="opacity" and (math.floor(value*100+.5).."%") or A.Decimal(value,sl.setting=="textSize" and 0 or 2))

 end

 put(U.scaleHint,A.T("Applied on release")..(s.scale>(U.effectiveScale or s.scale)+.001 and (" · "..A.T("Screen limit").." "..A.Decimal(U.effectiveScale,2)) or ""))

 put(U.textHint,A.T("Applied on release"))

 local chosen=s.language or "auto"

 local label=A.T("Automatic")

 for _,lg in ipairs(A.languages) do if lg[1]==chosen then label=lg[1]=="auto" and A.T("Automatic") or lg[2] end end

 if chosen=="auto" then for _,lg in ipairs(A.languages) do if lg[1]==A.Locale() then label=label.." · "..lg[2] end end end

 U.language.label.localeFont=chosen=="auto" and A.Locale() or chosen;put(U.language.label,label)

 put(U.languageCaption,A.T("Language"));put(U.retentionCaption,A.T("Retained runs"));put(U.retention.label,A.Format(s.maxRuns))

 put(U.appearance,A.T("Appearance"));put(U.behaviour,A.T("Behaviour"));put(U.storage,A.T("Storage"));put(U.saveNote,A.T("Saved on normal game exit"))

end

function A.RefreshUI()

 if not A.window then return end

 local s=A.db.settings

 s.view={tab=A.view.tab,mode=A.view.mode,class=A.view.class,cumulative=A.view.cumulative,characterTab=A.view.characterTab,usageTab=A.view.usageTab}

 local live=A.run;local r=A.Selected()

 put(A.bar.label,not live and ("|cffd9b66fAZEROTH STATS|r  ·  "..A.T("Out of run")) or "|cffd9b66fAZEROTH STATS|r  ·  "..(live and A.ClassName(live.class) or A.T("Out of run")).."  ·  "..A.Duration(live and live.values.duration).."  ·  "..A.Metric("kills").." "..A.Short(live and live.values.kills).."  ·  "..A.Metric("gold").." "..A.Short(live and live.values.gold))

 if not A.window:IsShown() then return end

 local m=A.PageModel();U.model=m

 put(U.title,"AZEROTH STATS");put(U.version,A.version)

 put(U.breadcrumb,(A.view.tab==4 or A.view.tab==9) and A.view.cumulative and (A.T("All runs").." · "..(A.view.class and A.ClassName(A.view.class) or A.T("All classes"))) or r and ((r.hero or "?").." · "..A.ClassName(r.class).." · "..A.ZoneName(r).." · "..A.Status(r.result or r.status)) or A.T("Start a run to begin"))

 put(U.sectionTitle,m.title);put(U.subtitle,m.subtitle)

 put(U.sidebarNote,A.T("Collected since installation"))

 for i,b in ipairs(U.nav) do

  put(b.label,A.T(A.tabs[i]));selected(b,i==A.view.tab)

 end

 local tab=A.view.tab

 show(U.classButton,tab==1 or tab==2 or tab==3 or tab==6)

 put(U.classButton.label,(A.view.class and A.ClassName(A.view.class) or A.T("All classes")))

 show(U.latest,tab==5);put(U.latest.label,A.view.selected and (A.T("History").." · "..A.Date(r and r.startedAt)) or A.T("Latest run"))

 for _,b in ipairs(U.modeButtons) do

  show(b,tab==4);put(b.label,b.mode and A.ModeName(b.mode) or A.T("Activity"))

  local active=(b.mode and b.mode==A.view.mode and A.view.combatTab~="Activity") or (not b.mode and A.view.combatTab=="Activity")

  selected(b,active)

 end

 for _,b in ipairs(U.usageButtons) do show(b,tab==9);put(b.label,A.T(b.key));selected(b,b.key==(A.view.usageTab or "Spells")) end

 for _,b in ipairs(U.characterButtons) do show(b,tab==5);put(b.label,A.T(b.key));selected(b,b.key==A.view.characterTab) end

 show(U.scopeRun,tab==4 or tab==9);show(U.scopeAll,tab==4 or tab==9)

 put(U.scopeRun.label,A.view.selected and (A.T("History").." · "..A.Date(r and r.startedAt)) or A.T(A.run and A.run.status=="active" and "Current run" or "Latest run"));put(U.scopeAll.label,A.T("All runs"))

 selected(U.scopeRun,not A.view.cumulative);selected(U.scopeAll,A.view.cumulative)

 show(U.settings,tab==8);if tab==8 then settingsRefresh() end

 -- Two-line rows keep a real gap even at the largest accessibility font size.

 if m.layout~="overview" and m.layout~="classes" and m.layout~="settings" then

  local hasDetail=false;for _,d in ipairs(m.rows) do if d.detail and d.detail~="" then hasDetail=true;break end end

  if hasDetail then m.rowHeight=math.max(m.rowHeight,46);m.capacity=math.max(1,math.floor((580-m.rowY)/m.rowHeight)) end

 end

 local per=m.capacity;local pages=math.max(1,math.ceil(table.getn(m.rows)/per));A.view.page=math.max(1,math.min(pages,A.view.page))

 for i,c in ipairs(U.cards) do

  local d=m.cards[i]

  if d then

   c.item=d;c:ClearAllPoints()

   local tall=m.layout=="classes";local top=m.layout=="combat" and 195 or 163

   local h=tall and 116 or (m.layout=="combat" and 76 or 94)

   c:SetPoint("TOPLEFT",A.window,"TOPLEFT",218+math.mod(i-1,3)*238,-top-math.floor((i-1)/3)*(h+10));c:SetHeight(h)

   c.detail:ClearAllPoints();c.detail:SetPoint("TOPLEFT",c,"TOPLEFT",13,m.layout=="combat" and -58 or -69)

   c.value:SetHeight(m.layout=="combat" and 27 or 34)

   icon(c.icon,d.icon,d.class);put(c.label,d.label);put(c.value,d.value);put(c.detail,d.detail);c:Show()

  else c:Hide();c.item=nil end

 end

 for i,f in ipairs(U.rows) do

  local d=i<=per and m.rows[(A.view.page-1)*per+i] or nil

  if d then

   f.item=d;f:ClearAllPoints();f:SetPoint("TOPLEFT",A.window,"TOPLEFT",218,-m.rowY-(i-1)*m.rowHeight);f:SetHeight(m.rowHeight-1)

   local compact=m.layout=="overview"

   f.detail:ClearAllPoints();f.detail:SetPoint("TOPLEFT",f,"TOPLEFT",35,-(m.rowHeight>=40 and 24 or 16));f.detail:SetHeight(m.rowHeight>=40 and 20 or 12)

   f.label:SetHeight(m.rowHeight>=40 and 22 or 22)

   f.icon:SetWidth(compact and 17 or 22);f.icon:SetHeight(compact and 17 or 22);icon(f.icon,d.icon,d.class)

   put(f.label,d.label);put(f.value,d.value);put(f.detail,compact and "" or d.detail)

   f.fill:SetWidth(math.max(1,710*math.max(0,math.min(1,d.fraction or 0))));f.fill:SetAlpha(d.fraction and .15 or 0)

   f:Show()

  else f.item=nil;f:Hide() end

 end

 show(U.empty,m.empty);put(U.empty,m.emptyText or (A.T("No data yet")..(table.getn(A.db.runs)==0 and ("\n"..A.T("Start a run to begin")) or "")))

 put(U.note,m.note or "");put(U.paging,A.T("Page").." "..A.view.page.." / "..pages)

 show(U.previous,pages>1);show(U.next,pages>1);show(U.paging,pages>1)

 for _,b in ipairs(U.controls) do if b.key and b.key~="" then put(b.label,A.T(b.key)) end end

end

function A.ToggleUI(value)

 if not A.window then return end

 if value==true or (value==nil and not A.window:IsShown()) then A.window:Show();A.RefreshUI() else A.window:Hide();if U.menu then U.menu:Hide() end end

 A.db.settings.open=A.window:IsShown() and true or false

end

local function buildSettings(f)

 local p=CreateFrame("Frame",nil,f);p:SetPoint("TOPLEFT",f,"TOPLEFT",218,-158);p:SetWidth(712);p:SetHeight(421);U.settings=p

 U.appearance=font(p,0,0,690,24,16,C.gold,true)

 U.behaviour=font(p,0,205,320,24,16,C.gold,true)

 U.storage=font(p,370,205,320,24,16,C.gold,true)

 U.saveNote=font(p,0,388,710,30,11,C.muted)

 U.sliders={};U.checks={}

 local definitions={{"opacity","Background opacity",0,55,.45,1,.05},{"scale","Window scale",370,55,.65,1.5,.05},{"textSize","Font size",0,135,11,16,1}}

 for _,def in ipairs(definitions) do

  local sl=CreateFrame("Slider","AzerothStatsSlider"..def[1],p,"OptionsSliderTemplate")

  sl.setting=def[1];sl.key=def[2];sl:SetPoint("TOPLEFT",p,"TOPLEFT",def[3]+8,-def[4]-25);sl:SetWidth(310);sl:SetHeight(18);sl:SetMinMaxValues(def[5],def[6]);sl:SetValueStep(def[7])

  for _,suffix in ipairs({"Text","Low","High"}) do local t=getglobal(sl:GetName()..suffix);if t then t:Hide() end end

  sl.caption=font(p,def[3],def[4]-10,245,22,12,C.text);sl.number=font(p,def[3]+250,def[4]-10,90,22,12,C.gold);sl.number:SetJustifyH("RIGHT")

  sl:SetScript("OnMouseDown",function() this.dragging=true end)

  sl:SetScript("OnMouseUp",function() A.CommitSliders() end)

  sl:SetScript("OnHide",function() A.CommitSliders() end)

  sl:SetScript("OnUpdate",function()

   -- Native click/value script ordering may differ; never resize synchronously from OnValueChanged.

   if this.pending and not this.dragging and GetTime()-(this.pendingAt or 0)>.25 then A.CommitSliders() end

  end)

  sl:SetScript("OnValueChanged",function()

   if this.syncing then return end

   local value=this:GetValue()

   if this.setting=="scale" or this.setting=="textSize" then

    this.pending=value;this.pendingAt=GetTime();settingsRefresh()

   else A.db.settings[this.setting]=value;A.ApplyUI();A.RefreshUI() end

  end)

  table.insert(U.sliders,sl)

 end

 U.scaleHint=font(p,370,104,330,18,9,C.muted)

 U.textHint=font(p,0,183,330,18,9,C.muted)

 U.languageCaption=font(p,370,125,332,24,12,C.text)

 U.language=button(p,370,153,330,28,"",function(self)

  local options={}

  for _,lg in ipairs(A.languages) do local code=lg[1];table.insert(options,{label=code=="auto" and A.T("Automatic") or lg[2],locale=code=="auto" and A.Locale() or code,action=function() A.SetLanguage(code) end}) end

  A.ShowMenu(self,options)

 end)

 for i,def in ipairs({{"bar","Top bar"},{"minimap","Minimap button"},{"locked","Lock position"},{"recordSound","Record sounds"}}) do

  local b=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",p,"TOPLEFT",0,-237-(i-1)*39);b:SetWidth(24);b:SetHeight(24);b.setting=def[1];b.key=def[2]

  b.caption=font(p,32,237+(i-1)*39,310,24,12,C.text)

  b:SetScript("OnClick",function() A.db.settings[this.setting]=not A.db.settings[this.setting];A.ApplyUI();A.RefreshUI() end)

  table.insert(U.checks,b)

 end

 U.retentionCaption=font(p,370,235,330,22,12,C.text)

 U.retention=button(p,370,263,330,28,"",function(self)

  local options={}

  for _,n in ipairs({50,100,200,500,1000}) do local value=n;table.insert(options,{label=A.Format(value),action=function() A.db.settings.maxRuns=value;A.Trim() end}) end

  A.ShowMenu(self,options)

 end)

 dropdown(U.language);dropdown(U.retention)

 button(p,370,317,330,28,"Reset position",function() A.ResetPosition() end)

end

function A.BuildUI()

 local f=CreateFrame("Frame","AzerothStatsWindow",UIParent);A.window=f

 f:SetWidth(960);f:SetHeight(650);f:SetFrameStrata("DIALOG");surface(f,"main");drag(f,"windowPos");place(f,"windowPos","CENTER",0,0)

 f:SetScript("OnHide",function() A.CommitSliders();A.db.settings.open=false;if U.menu then U.menu:Hide() end end)

 f:SetScript("OnMouseDown",function() if U.menu then U.menu:Hide() end end)

 local emblem=f:CreateTexture(nil,"ARTWORK");emblem:SetPoint("TOPLEFT",f,"TOPLEFT",24,-22);emblem:SetWidth(34);emblem:SetHeight(34);icon(emblem,"INV_Misc_Book_09")

 U.title=font(f,72,19,370,28,23,C.gold,true);U.version=font(f,448,23,200,20,11,C.muted)

 U.breadcrumb=font(f,72,49,810,18,11,C.muted)

 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-7,-6);close:SetWidth(30);close:SetHeight(30);close:SetScript("OnClick",function() A.ToggleUI(false) end)

 local divider=f:CreateTexture(nil,"ARTWORK");divider:SetPoint("TOPLEFT",f,"TOPLEFT",22,-79);divider:SetWidth(914);divider:SetHeight(1);divider:SetTexture(.42,.32,.16)

 U.sidebarNote=font(f,29,541,152,49,10,C.muted)

 local navIcons={"INV_Misc_Book_09","Ability_Warrior_BattleShout","INV_Misc_PocketWatch_01","INV_Sword_04","INV_Chest_Chain_04","INV_Misc_Coin_02","INV_Misc_Gear_01","Trade_Engineering","INV_Misc_Book_09"}

 for i,key in ipairs(A.tabs) do

  local index=i;local b=button(f,23,97+(i-1)*49,170,40,"",function() selectTab(index) end)

  b.marker=solid(b,1,.68,.2,1,"ARTWORK");b.marker:ClearAllPoints();b.marker:SetPoint("TOPLEFT",b,"TOPLEFT",1,-3);b.marker:SetWidth(3);b.marker:SetHeight(34)

  b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",39,0);b.label:SetWidth(123);b.label.fontWidth=123;b.label.baseSize=13

  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("LEFT",b,"LEFT",10,0);b.icon:SetWidth(21);b.icon:SetHeight(21);icon(b.icon,navIcons[i]);U.nav[i]=b

 end

 U.sectionTitle=font(f,218,96,285,28,21,C.gold,true);U.subtitle=font(f,218,128,710,22,11,C.muted)

 U.classButton=button(f,714,100,218,26,"",function() A.CycleClass() end);dropdown(U.classButton)

 U.latest=button(f,714,100,218,26,"",function(self) A.RunMenu(self) end);dropdown(U.latest)

 U.modeButtons={};U.characterButtons={}

 for i,mode in ipairs({"damage","healing","taken","boss","activity"}) do

  local key=mode;local b=button(f,218+(i-1)*144,160,136,26,"",function()

   A.view.combatTab=key=="activity" and "Activity" or "Spells";if key=="activity" then A.view.cumulative=false end;if key~="activity" then A.view.mode=key end;A.view.page=1;A.RefreshUI()

  end);b.mode=mode~="activity" and mode or nil;table.insert(U.modeButtons,b)

 end

 for i,key in ipairs({"Spells","Equipment","Attributes","Timeline"}) do

  local section=key;local b=button(f,218+(i-1)*180,160,172,26,"",function() A.view.characterTab=section;A.view.page=1;A.RefreshUI() end);b.key=key;table.insert(U.characterButtons,b)

 end

 U.usageButtons={}

 for i,key in ipairs({"Spells","Jewelry","Co-op"}) do

  local section=key;local b=button(f,218+(i-1)*240,160,232,26,"",function() A.view.usageTab=section;A.view.page=1;A.RefreshUI() end);b.key=key;table.insert(U.usageButtons,b)

 end

 U.scopeRun=button(f,518,100,198,26,"",function(self) A.RunMenu(self) end);dropdown(U.scopeRun)

 U.scopeAll=button(f,724,100,208,26,"",function() A.view.cumulative=true;A.view.combatTab="Spells";A.view.page=1;A.RefreshUI() end)

 for i=1,9 do

  local c=CreateFrame("Button",nil,f);c:SetWidth(224);surface(c,"card")

  c.icon=c:CreateTexture(nil,"ARTWORK");c.icon:SetPoint("TOPRIGHT",c,"TOPRIGHT",-12,-12);c.icon:SetWidth(22);c.icon:SetHeight(22)

  c.label=font(c,13,9,176,20,11,C.text);c.value=font(c,13,32,199,34,23,C.gold,true);c.detail=font(c,13,69,199,18,9,C.muted)

  c:SetScript("OnEnter",function() tooltip(this) end);c:SetScript("OnLeave",function() GameTooltip:Hide() end)

  c:SetScript("OnClick",function() if this.item and this.item.action then this.item.action();A.RefreshUI() end end);U.cards[i]=c

 end

 for i=1,12 do

  local r=CreateFrame("Button",nil,f);r:SetWidth(714)

  r.shade=solid(r,.14,.115,.07,math.mod(i,2)==0 and .28 or .11)

  r.fill=r:CreateTexture(nil,"ARTWORK");r.fill:SetPoint("LEFT",r,"LEFT",0,0);r.fill:SetHeight(27);r.fill:SetTexture(.65,.42,.13)

  r.icon=r:CreateTexture(nil,"ARTWORK");r.icon:SetPoint("LEFT",r,"LEFT",6,0);r.icon:SetWidth(22);r.icon:SetHeight(22)

  r.label=font(r,35,1,412,22,12,C.text);r.value=font(r,455,0,250,23,13,C.gold);r.value:SetJustifyH("RIGHT")

  r.detail=font(r,35,19,670,15,9,C.muted)

  r:SetScript("OnEnter",function() tooltip(this) end);r:SetScript("OnLeave",function() GameTooltip:Hide() end)

  r:SetScript("OnClick",function() if this.item and this.item.action then this.item.action();A.RefreshUI() end end);U.rows[i]=r

 end

 U.empty=font(f,268,293,608,80,16,C.muted,true)

 U.note=font(f,218,589,714,19,10,C.muted)

 U.previous=button(f,218,615,38,24,"<",function() A.view.page=math.max(1,A.view.page-1);A.RefreshUI() end)

 U.next=button(f,265,615,38,24,">",function() local m=A.PageModel();A.view.page=math.min(math.ceil(table.getn(m.rows)/m.capacity),A.view.page+1);A.RefreshUI() end)

 U.paging=font(f,320,616,400,23,11,C.muted)

 if f.EnableMouseWheel then f:EnableMouseWheel(true);f:SetScript("OnMouseWheel",function() A.view.page=A.view.page-(arg1 or 0);A.RefreshUI() end) end

 buildSettings(f)

 if UISpecialFrames then table.insert(UISpecialFrames,"AzerothStatsWindow") end

 A.tabButtons=U.nav;A.uiRows=U.rows;A.classButton=U.classButton

 local bar=CreateFrame("Button","AzerothStatsBar",UIParent);A.bar=bar;bar:SetWidth(700);bar:SetHeight(27);bar:SetFrameStrata("MEDIUM");surface(bar,"main");drag(bar,"barPos");place(bar,"barPos","TOP",0,-2)

 bar.label=font(bar,12,2,676,23,11,C.text);bar:SetScript("OnClick",function() A.ToggleUI() end)

 local mini=CreateFrame("Button","AzerothStatsMinimap",Minimap or UIParent);A.mini=mini

 mini:SetWidth(30);mini:SetHeight(30);mini:SetFrameStrata("MEDIUM");surface(mini,"main")

 mini.icon=mini:CreateTexture(nil,"ARTWORK");mini.icon:SetPoint("CENTER",mini,"CENTER",0,0);mini.icon:SetWidth(21);mini.icon:SetHeight(21);icon(mini.icon,"INV_Misc_Book_09")

 mini:RegisterForClicks("LeftButtonUp","RightButtonUp");mini:RegisterForDrag("LeftButton")

 mini:SetScript("OnClick",function() if arg1=="RightButton" then selectTab(8);A.ToggleUI(true) else A.ToggleUI() end end)

 mini:SetScript("OnDragStart",function() if not A.db.settings.locked then this.dragging=true end end)

 mini:SetScript("OnDragStop",function() this.dragging=nil end)

 mini:SetScript("OnUpdate",function()

  if not this.dragging or not GetCursorPosition then return end

  local x,y=GetCursorPosition();local cx,cy=(Minimap or UIParent):GetCenter();local scale=(Minimap or UIParent):GetEffectiveScale()

  local angle=math.atan2(y/scale-cy,x/scale-cx);A.db.settings.miniAngle=angle

  this:ClearAllPoints();this:SetPoint("CENTER",Minimap or UIParent,"CENTER",math.cos(angle)*80,math.sin(angle)*80)

 end)

 local angle=tonumber(A.db.settings.miniAngle) or .785398

 if angle~=angle or math.abs(angle)>100 then angle=.785398 end

 mini:SetPoint("CENTER",Minimap or UIParent,"CENTER",math.cos(angle)*80,math.sin(angle)*80)

 mini:SetScript("OnEnter",function() GameTooltip:SetOwner(this,"ANCHOR_LEFT");GameTooltip:AddLine("Azeroth Stats",.95,.8,.5);GameTooltip:AddLine(A.T("Open").." / "..A.T("Settings"),.85,.82,.75);GameTooltip:Show() end)

 mini:SetScript("OnLeave",function() GameTooltip:Hide() end)

 if not A.db.settings.open then f:Hide() end

 A.ApplyUI();A.RefreshUI()

end


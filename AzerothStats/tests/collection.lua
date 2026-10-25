local A=AzerothStats
local function check(ok,msg) assert(ok,msg);TEST_COUNT=TEST_COUNT+1 end
local saved,run=AzerothStatsDB,A.run
local function entry(name,id,n)
 return {name=name,link="|Hitem:"..id..":0:0:0|h["..name.."]|h",changes=n,tooltip={{text=name}}}
end
local function fixture(id,jewelry)
 return {id=id,class="rogue",values={},accounted={},meters={},events={},usage={spells={},jewelry=jewelry,slots={},accounted={jewelry={}}}}
end
local one=fixture("one",{["item:900001"]=entry("Accessory",900001,0),["item:900002"]=entry("Accessory II",900002,1)})
one.usage.slots[13]={key="item:900002",sig="last"}
local two=fixture("two",{["item:900003"]=entry("Accessory III",900003,3),["item:900001"]=entry("Another Accessory",900001,1)})
AzerothStatsDB={schema=1,sequence=2,settings={},migrations={chestPrice13=true},pruned=1,runs={one,two},totals={runs=3,sum={damage=700},usage={jewelry={old={runs=8}}}},classes={rogue={runs=3,sum={damage=700}}}}
A.InitDB()
local merged=A.db.totals.usage.jewelry["name:Accessory"]
check(merged.runs==2 and merged.changes==4,"variant migration counts each run once, sums observed changes")
check(one.usage.slots[13].key=="name:Accessory" and one.usage.jewelry["name:Accessory"].tooltip[1].text=="Accessory II","migration prefers last known slot description")
check(A.db.totals.usage.jewelry["name:Another Accessory"].runs==1,"reused synthetic item ID does not merge different accessories")
check(A.db.totals.legacyJewelry14.old.runs==8 and A.db.totals.sum.damage==700,"previous aggregates archived and damage unaffected")
local signature=A.Sign(A.db);A.InitDB();check(signature==A.Sign(A.db),"variant migration idempotent")
for _,lg in ipairs(A.languages) do
 if lg[1]~="auto" then
  local lang=A.gameText[lg[1]]
  local label=lang["The Eternal Talisman"]..": "..lang["ability.slice_and_dice.name"].." IV"
  local key=A.JewelKey("|Hitem:900010|h["..label.."]|h")
  check(key=="eternal:ability.slice_and_dice.name","multilingual talisman normalization "..lg[1])
  local kelp=lang["amulet.south_seas_kelp"]
  check(A.JewelKey("["..kelp.." III]")=="amulet.south_seas_kelp","multilingual amulet normalization "..lg[1])
 end
end
-- An old collection item can use a newer exact-ID native observation, with a reference label.
one.equipment={[1]="|Hitem:104020|h[Couvre-chef de Tueur de la nuit]|h"}
two.equipment=one.equipment;two.equipmentTooltips={[1]={{text="Nightslayer Cover"},{text="+21 Health"},{text="Crit 1.8%"}}}
local lines=A.CollectionReference(one.equipment[1])
check(lines and lines[3].text=="Crit 1.8%","old collection item receives newer native reference bonuses, without rounding from external catalog")
check(A.CollectionReference("item:999999")==nil,"unknown collection item never borrows another item description")
local methods=getmetatable(GameTooltip).__index;local oldAdd=methods.AddLine
local added={};methods.AddLine=function(self,text) table.insert(added,text) end
A.run=nil;A.ItemTooltip(GameTooltip,{collection=true,class="rogue",link=one.equipment[1],label="Head"})
local reference,source=false,false
for _,text in ipairs(added) do if text==A.T("Current collection reference") then reference=true end;if string.find(text,"Kovork",1,true) then source=true end end
check(reference and source,"reference tooltip includes native bonuses and audited boss source")
methods.AddLine=oldAdd
A.view.tab=4;A.view.combatTab="Spells";A.view.mode="boss";A.view.cumulative=true;A.RefreshUI()
check(A.ui.model.emptyText==A.T("Select a run for its last boss fight"),"cumulative boss page explains its actual limitation")
A.view.mode="damage";A.view.cumulative=false;A.view.selected="one";A.run=nil;A.RefreshUI()
check(not string.find(A.bar.label.fullText,A.T("Unavailable"),1,true),"out-of-run bar is compact")
-- Summary data repairs a missing zone, without creating another run on a delayed zone packet.
local oldSummary=one.summary;one.summary={zone="feralas"};one.zone=nil;A.db.migrations.jewelry14=nil;A.NormalizeJewelry()
check(one.zone=="feralas","official summary supplies missing historical zone")
one.summary=oldSummary
-- A late or temporarily missing zone packet must not manufacture another run.
AzerothStatsDB=nil;A.db=nil;A.run=nil;A.newBoundary=nil;A.boundaryGate=nil;A.inReady=nil;A.buildBaseline=nil;A.packetReady=nil;A.packetSummary=nil;A.inventoryBaseline=nil
AZS_ZONE={};AZS_RUN={ph="playing",t=1,lvl=1,kills=0};AZS_END={};A.InitDB();A.Sample()
local current=A.run
AZS_ZONE={zone="feralas",class="rogue"};A.Sample()
check(A.run==current and A.db.totals.runs==1 and current.zone=="feralas","late zone enriches existing run instead of splitting it")
AZS_ZONE={};A.Sample();check(A.run==current and A.db.totals.runs==1,"temporarily absent zone does not split run")
AZS_ZONE={zone="duskwood",class="rogue"};A.Sample();check(A.run~=current and A.db.totals.runs==2,"real zone change remains a run boundary")
AzerothStatsDB=saved;A.db=saved;A.run=run;A.view.tab=1;A.view.selected=nil;A.view.cumulative=false
print("COLLECTION AND VARIANT REGRESSIONS PASSED",TEST_COUNT)

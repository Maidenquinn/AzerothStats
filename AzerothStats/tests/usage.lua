local A=AzerothStats
local function check(ok,msg) assert(ok,msg);TEST_COUNT=TEST_COUNT+1 end
local saved,oldrun=AzerothStatsDB,A.run
local oldLink,oldTexture=GetInventoryItemLink,GetInventoryItemTexture
local methods=getmetatable(GameTooltip).__index
local oldInventory,oldNum,oldAdd=methods.SetInventoryItem,methods.NumLines,methods.AddLine
-- Legacy price correction, including stale/pruned lifetime records.
AzerothStatsDB={schema=1,sequence=2,settings={},migrations={},pruned=3,totals={runs=5,sum={damage=900,chests=206},coverage={chests=5},records={chests={value=155}}},classes={rogue={runs=5,sum={damage=900,chests=206},coverage={chests=5},records={chests={value=155}}}},runs={
 {id="old1",class="rogue",startedAt=1,values={chests=31,damage=100},accounted={chests=31},events={},meters={}},
 {id="old2",class="rogue",startedAt=2,values={chests=2,damage=800},accounted={chests=2},events={},meters={},summary={chests=2,result="defeat"}}
}}
check(A.InitDB(),"legacy price fixture loads")
check(A.db.runs[1].values.chests==nil and A.db.runs[1].legacyChestPrice13==31,"old price quarantined instead of treated as count")
check(A.db.totals.sum.chests==2 and A.db.totals.coverage.chests==1 and A.db.totals.records.chests.value==2,"chest totals rebuilt only from retained official summaries")
check(A.db.totals.sum.damage==900 and A.db.totals.runs==5,"chest correction preserves other metrics")
local signature=A.Sign(A.db);A.InitDB();check(A.Sign(A.db)==signature,"chest migration idempotent")
-- Use the actual client parser and packet handling for collection.
AzerothStatsDB=nil;A.db=nil;A.run=nil;A.inReady=nil;A.newBoundary=nil;A.boundaryGate=nil;A.buildBaseline=nil;A.packetReady=nil;A.inventoryBaseline=nil;A.packetSummary=nil;A.spellPacket=nil
AZS_RUN={};AZS_ZONE={class="rogue",zone="feralas"};AZS_END={};AZS_SPELLS={};AZS_STATS={};AZS_METER={};AZS_HEALING={};AZS_TAKEN={};AZS_BOSSMETER={}
A.InitDB()
local inventory={};local descriptions={};local scanSlot
GetInventoryItemLink=function(unit,slot) return inventory[slot] end
GetInventoryItemTexture=function(unit,slot) return inventory[slot] and "Interface\\Icons\\INV_Misc_Book_09" end
methods.SetInventoryItem=function(self,unit,slot)
 scanSlot=slot
 if self==GameTooltip then self.liveSlot=slot;return inventory[slot]~=nil end
 local first=getglobal("AzerothStatsItemScanTextLeft1") or CreateFrame("FontString","AzerothStatsItemScanTextLeft1")
 first:SetText(descriptions[slot]);return inventory[slot]~=nil
end
methods.NumLines=function(self) return descriptions[scanSlot] and 1 or 0 end
methods.AddLine=function(self,text) self.lastAdded=text end
local function packet(prefix,text)
 NOW=NOW+1;event="CHAT_MSG_ADDON";arg1=prefix;arg2=text;AZS_ApiOnEvent();A.Packet(prefix,text);A.Sample()
end
packet("AZSRUN","ph=ready;t=0")
packet("AZSRUN","ph=playing;t=1;chest=31;kills=0;lvl=1")
local r=A.run
check(r.values.chests==nil,"next chest price 31 is not an opening count")
packet("AZSRUN","ph=playing;t=2;chest=45;kills=1;lvl=1")
check(r.values.chests==nil and A.db.totals.sum.chests==nil,"price jump 31 to 45 never inflates openings")
packet("AZSSPELLS","backstab,53,1,0,3")
check(r.usage.spells.backstab.maxRank==1 and r.usage.spells.backstab.gains==0,"first observed rank is a baseline, not a click")
packet("AZSSPELLS","backstab,53,3,0,3")
for i=1,20 do A.Sample() end
check(A.db.totals.usage.spells.backstab.runs==1 and A.db.totals.usage.spells.backstab.gains==2,"rank growth counted once despite polling")
packet("AZSSPELLS","backstab,53,2,0,3");packet("AZSSPELLS","backstab,53,3,0,3")
check(A.db.totals.usage.spells.backstab.gains==2,"rank rollback and replay do not double count gains")
inventory[13]="|cffffffff|Hitem:100:0:0:0|h[Mark of the Chosen]|h|r";descriptions[13]="Luck +22%";A.Sample()
check(r.usage.jewelry["jewel.chosen"]~=nil,"run jewelry recognized by stable multilingual key")
local first=r.usage.jewelry["jewel.chosen"]
check(first.tooltip[1].text=="Luck +22%","native tooltip description captured")
A.Sample();check(A.db.totals.usage.jewelry["jewel.chosen"].runs==1,"equipped item presence counted once per run")
descriptions[13]="Luck +48%";A.Sample()
check(first.changes==1 and first.tooltip[1].text=="Luck +48%","same item stat changes observed without fabricating pick counts")
A.ItemTooltip(GameTooltip,{link=inventory[13],slot=13,run=r})
check(GameTooltip.liveSlot==13,"live item hover uses native inventory tooltip")
A.ItemTooltip(GameTooltip,{link=first.link,tooltip=first.tooltip})
check(GameTooltip.lastAdded==A.T("Captured item description"),"historical item tooltip uses saved description")
packet("AZSEND","result=defeat;t=2;chests=2;hero=Player;zone=feralas")
check(r.values.chests==2 and A.db.totals.sum.chests==2,"official chest count overrides missing live count")
A.view.tab=9;A.view.cumulative=true;A.view.usageTab="Spells";A.RefreshUI()
check(table.getn(A.ui.model.rows)==1 and A.ui.nav[9].selected,"usage page exposes observed spell popularity")
A.view.usageTab="Jewelry";A.RefreshUI();check(A.ui.model.rows[1].tooltip[1].text=="Luck +48%","usage jewelry row preserves tooltip")
packet("AZSRUN","ph=ready;t=0");inventory[13]=nil;packet("AZSRUN","ph=playing;t=0;chest=20")
check(not A.run.usage or not A.run.usage.spells.backstab,"new run excludes stale spell baseline")
packet("AZSSPELLS","backstab,53,1,0,3")
check(A.db.totals.usage.spells.backstab.runs==2 and A.db.classes.rogue.usage.spells.backstab.runs==2,"second run increments global and class popularity once")
local counts=A.db.totals.usage.spells.backstab.runs
A.run=nil;A.Sample()
check(A.db.totals.usage.spells.backstab.runs==counts,"heuristic resume does not recount popularity")
-- Restore the original persistence fixture.
GetInventoryItemLink=oldLink;GetInventoryItemTexture=oldTexture
methods.SetInventoryItem=oldInventory;methods.NumLines=oldNum;methods.AddLine=oldAdd
AzerothStatsDB=saved;A.db=saved;A.run=oldrun;A.view.tab=1;A.view.cumulative=false
print("CHESTS, BUILD USAGE AND TOOLTIPS PASSED",TEST_COUNT)

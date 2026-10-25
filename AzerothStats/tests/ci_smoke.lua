local A=AzerothStats
local checks=0
local function check(ok,msg) assert(ok,msg);checks=checks+1 end
this=A.driver;event="ADDON_LOADED";arg1="AzerothStats";A.driver:GetScript("OnEvent")()
check(A.db and table.getn(A.db.runs)==0,"clean event-driven initialization")
this=A.driver;event="VARIABLES_LOADED";arg1=nil;A.driver:GetScript("OnEvent")()
check(table.getn(A.db.runs)==0,"duplicate load does not create games")
local r={id="ci-1",class="rogue",hero="Fixture",zone="feralas",startedAt=1,status="ended",result="defeat",values={duration=10,damage=100,kills=5,chests=2},accounted={},events={},timeline={},meters={damage={rows={{name="Melee",dmg=100,dps=10}},total=100,rate=10}}}
table.insert(A.db.runs,r);A.Account(r);A.Account(r)
check(A.db.totals.runs==1 and A.db.totals.sum.damage==100,"idempotent metric ledger")
check(A.db.classes.rogue.sum.chests==2 and A.db.totals.spells.damage.Melee==100,"class and spell ledgers")
AZS_SPELLS={{key="backstab",rank=1,spell=53}};A.ObserveBuild(r)
AZS_SPELLS[1].rank=3;A.ObserveBuild(r);A.ObserveBuild(r)
check(A.db.totals.usage.spells.backstab.runs==1 and A.db.totals.usage.spells.backstab.gains==2,"observed rank ledger")
for _,lg in ipairs(A.languages) do
 if lg[1]~="auto" then
  for key in pairs(A.uiText.en) do check(type(A.uiText[lg[1]][key])=="string" and A.uiText[lg[1]][key]~="","translation "..lg[1].." "..key) end
  A.SetLanguage(lg[1])
  for tab=1,9 do A.view.tab=tab;A.view.selected=r.id;A.ToggleUI(true);A.RefreshUI();check(A.ui.model.title==A.T(A.tabs[tab]),"page title "..lg[1]..tab) end
  local language=A.gameText[lg[1]]
  local link="["..language["amulet.south_seas_kelp"].." IV]"
  check(A.JewelKey(link,"rogue")=="amulet.south_seas_kelp","accessory normalization "..lg[1])
 end
end
A.view.tab=4;A.view.mode="boss";A.view.combatTab="Spells";A.view.cumulative=true;A.RefreshUI()
check(A.ui.model.emptyText==A.T("Select a run for its last boss fight"),"honest last-boss limitation")
A.view.tab=8;A.RefreshUI()
local slider=A.ui.sliders[2];local old=A.window:GetScale()
this=slider;slider:GetScript("OnMouseDown")();slider:SetValue(.85);slider:GetScript("OnValueChanged")();A.RefreshUI()
check(A.window:GetScale()==old,"scale stays stable during dragging")
this=slider;slider:GetScript("OnMouseUp")();check(A.window:GetScale()==.85,"scale commits on release")
local source=SNAPSHOT(AzerothStatsDB);local signature=A.Sign(AzerothStatsDB.totals)
AzerothStatsDB=nil;assert(loadstring("AzerothStatsDB="..source))();A.db=nil;A.InitDB()
check(A.Sign(A.db.totals)==signature,"offline serialization roundtrip")
CI_CHECKS=checks
print("OFFLINE MODEL/UI CHECKS PASSED",checks)

local A=AzerothStats
local function check(ok,text) assert(ok,text);TEST_COUNT=TEST_COUNT+1 end
local saved,oldrun=AzerothStatsDB,A.run
local session,generation=A.partySession,A.partyGeneration
local oldSound=PlaySoundFile;local sounds=0
PlaySoundFile=function(path) check(path=="Sound\\interface\\LevelUp.wav","audited game sound path");sounds=sounds+1;return true end
AzerothStatsDB=nil;A.db=nil;A.run=nil;A.newBoundary=nil;A.boundaryGate=nil;A.buildBaseline=nil;A.inventoryBaseline=nil;A.packetReady=nil;A.packetSummary=nil;A.inReady=nil;A.meterPackets=nil;A.partyGeneration=0;A.partySession=nil
AZS_RUN={};AZS_ZONE={zone="feralas",class="rogue"};AZS_END={};AZS_SPELLS={};AZS_STATS={}
AZS_PARTY={{name="Stale",class="mage",dmg=999,dps=999}};AZS_PARTY_UPDATED=NOW
A.InitDB();A.db.classes.rogue={records={peakDps={value=50,id="historical",at=1}}}
local function packet(prefix,text)
 NOW=NOW+1;event="CHAT_MSG_ADDON";arg1=prefix;arg2=text;AZS_ApiOnEvent();A.Packet(prefix,text);A.Sample()
end
local function progress(t,damage,phase)
 packet("AZSRUN","ph="..(phase or "playing")..";t="..t..";dealt="..damage..";kills=2;lvl=2")
end
progress(0,10000);local run=A.run
progress(9,10000);check(run.values.peakDps==nil and sounds==0,"first 10 seconds excluded; no startup spike")
check(not next(run.coop.peers) and run.coop.unavailable=="No fresh party sample","stale initial party rejected")
progress(10,400);check(run.values.peakDps==40 and sounds==0,"server-sample average below historical class record")
progress(11,660);check(run.values.peakDps==60 and sounds==1 and run.dpsRecordNotified,"new class record notifies once")
for i=1,10 do A.Sample() end
check(sounds==1,"polling cannot repeat record sound")
progress(12,840);check(run.values.peakDps==70 and sounds==1,"new maxima persist without notification spam")
progress(13,10000,"paused");check(run.values.peakDps==70,"paused samples do not manufacture a peak")
progress(13,800);check(run.values.peakDps==70 and run.dpsCounterDecreased,"damage reset rejected")
progress(20,1000);check(run.values.peakDps==70 and run.dpsSample.elapsed==12 and run.dpsSample.damage==840,"peak retains its actual evidence pair")
check(A.db.totals.sum.peakDps==nil and A.db.classes.rogue.sum.peakDps==nil,"DPS rates are never added into totals")
check(A.db.classes.rogue.records.peakDps.value==70 and A.db.totals.records.peakDps.value==70,"global and class peak records")
packet("AZSPARTY","Player,rogue,1000,50,0.5,Backstab,50;Friend,mage,600,30,0.3,Fireball,30")
check(A.db.totals.companions["Friend:mage"].runs==1 and A.db.classes.rogue.companions["Friend:mage"].runs==1,"observed group presence counted globally and by class")
check(not A.db.totals.companions["Player:rogue"] and not A.db.totals.companions["Stale:mage"],"self and stale peers excluded")
packet("AZSPARTY","")
check(table.getn(run.coop.latest)==0 and run.coop.peers["Friend:mage"],"empty packet clears latest roster, retains observed history")
packet("AZSPARTY","Friend,mage,650,31,1,Fireball,31")
check(A.db.totals.companions["Friend:mage"].runs==1,"roster rejoin is not another run")
A.view.tab=9;A.view.usageTab="Co-op";A.view.cumulative=false;A.view.selected=nil;A.RefreshUI()
check(A.ui.model.rows[1].label=="Friend" and string.find(A.ui.model.rows[1].value,"650",1,true),"per-run co-op uses received party damage")
packet("AZSEND","result=victory;t=20;dmg=1000;kills=2;hero=Player;zone=feralas")
check(A.db.totals.companions["Friend:mage"].wins==1,"own victory associated with a run containing observed peer presence")
packet("AZSEND","result=victory;t=20;dmg=1000;kills=2;hero=Player;zone=feralas")
progress(21,1100)
packet("AZSEND","result=left;t=25;dmg=1200;kills=2;hero=Player;zone=feralas")
check(A.db.totals.companions["Friend:mage"].wins==1 and A.db.totals.companions["Friend:mage"].runs==1,"duplicate summary and continuation preserve co-op ledger")
local restored=A.Copy(run);A.db.runs[1]=restored;A.run=restored;A.BeginInsights(restored)
progress(26,2000)
check(sounds==1 and restored.dpsRecordNotified,"saved notification flag prevents replay after resume")
A.view.cumulative=true;A.RefreshUI();check(string.find(A.ui.model.rows[1].detail,A.T("Victories in observed runs"),1,true)~=nil,"co-op wins labeled as co-occurrence, not shared achievements")
packet("AZSRUN","ph=ready;t=0");progress(0,0)
check(not next(A.run.coop.peers),"new run waits for a fresh party packet")
A.db.settings.recordSound=false
progress(10,3000);check(A.run.values.peakDps==300 and sounds==1,"muted setting still records peaks")
packet("AZSPARTY","Friend,mage,10,1,1,Fireball,1")
check(A.db.totals.companions["Friend:mage"].runs==2,"second observed run increments once")
packet("AZSEND","result=defeat;t=11;dmg=3000;hero=Player;zone=feralas")
check(A.db.totals.companions["Friend:mage"].wins==1,"defeat never becomes a co-op victory")
local before=A.db.settings.recordSound
SlashCmdList.AZEROTHSTATS("sound");check(A.db.settings.recordSound~=before,"record sound command toggles preference")
SlashCmdList.AZEROTHSTATS("sound test");check(sounds==2,"explicit sound preview")
packet("AZSRUN","ph=ready;t=0");progress(0,0);AZS_PARTY=nil;A.ObserveInsights(A.run,AZS_RUN,"playing")
check(A.run.coop.unavailable=="Party API unavailable","optional party API absence diagnosed")
check(not A.run.nemesis and not A.db.totals.nemesis,"no invented fatal attacker or Nemesis counter")
PlaySoundFile=oldSound;AzerothStatsDB=saved;A.db=saved;A.run=oldrun;A.partySession=session;A.partyGeneration=generation;A.view.tab=1;A.view.usageTab="Spells";A.view.cumulative=false
print("DPS RECORDS AND CO-OP PASSED",TEST_COUNT)

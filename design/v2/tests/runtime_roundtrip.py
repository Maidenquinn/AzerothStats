"""Real V2Data writer against frozen V1 ledgers, with synthetic data only.

Uses the existing probe helpers. This proves an offline module/format contract,
not the native client's SavedVariables serialization or the final V2 interface.
"""

from pathlib import Path
import json
from compatibility_probe import context, freeze

ROOT = Path(__file__).resolve().parents[3]
MODULE = "\n".join(
    (ROOT / "AzerothStats" / name).read_text(encoding="utf-8")
    for name in ["V2Data.lua", "V2Observe.lua", "V2Views.lua", "V2Personal.lua"]
)
results = []
for ref in ["v1.6.2-beta.1", "v1.7.0-beta.1", "v1.7.1-beta.1"]:
    original = context(ref)
    original.globals().ProbeRun(100)
    v2 = context(ref, freeze(original.globals().AzerothStats.db))
    second = v2.globals().ProbeRun(200)
    v2.execute(MODULE)
    v2.execute(
        """
        local A = AzerothStats
        local run = A.db.runs[2]
        run.status = 'active'
        AZS_STATS = { echo=0.12, pick=8.2, gpick=1.26, thn=0.15 }
        A.statsPacket = true
        A.ObserveV2(run)
        assert(A.V2Store(false).runs[run.id].latest.echo == 0.12)
        A.runPacketAt = NOW
        A.V2Packet('AZSZONE')
        AZS_ZONE = {zone='elwynn',class='warrior',affixes='sanguine,explosive'}
        A.ObserveV2World(run)
        assert(A.V2SetNote(run.id, 'Synthetic local note'))
        assert(A.V2AddGoal(run, 3))
        assert(A.V2CreateGoal({class='all',zone='all',heroic='all',metric='kills',title='My custom goal',target=1234}))
        A.V2Update(run, function(data)
            data.encounters = {{id=42,name='Synthetic boss',at=15,lastAt=30}}
            data.support = {{t=30,kind='attempt',name='Synthetic friend',seq=1}}
            data.summons = {imp={name='Imp',firstAt=15,lastAt=30,maximum=2,sampled=true}}
            data.buffs = {aura={name='Synthetic aura',firstAt=15,lastAt=30,maximum=1,sampled=true}}
        end)
        run.status = 'ended'
        assert(A.ValidateDatabase(A.db))
    """
    )
    # Exercise executable Lua serialization too, rather than only Python table copies.
    v2.execute((ROOT / "AzerothStats/tests/serialize.lua").read_text(encoding="utf-8"))
    serialized = v2.globals().SNAPSHOT(v2.globals().AzerothStats.db)
    saved = freeze(v2.execute("return " + serialized))
    extra = saved["extensions"]
    v1 = context(ref, saved)
    assert v1.globals().AzerothStats.db.totals.runs == 2
    assert v1.globals().AzerothStats.db.totals.sum.gold == 300
    assert freeze(v1.globals().AzerothStats.db.extensions) == extra
    v1.globals().ProbeRun(70)
    resumed = context(ref, freeze(v1.globals().AzerothStats.db))
    resumed.execute(MODULE)
    resumed.execute("AzerothStats.V2Reconcile()")
    db = freeze(resumed.globals().AzerothStats.db)
    assert db["totals"]["runs"] == 3 and db["totals"]["sum"]["gold"] == 370
    assert db["extensions"] == extra
    resumed.execute("table.remove(AzerothStats.db.runs, 2); AzerothStats.V2Reconcile()")
    assert second not in freeze(resumed.globals().AzerothStats.V2Store(False).runs)
    results.append({"reader": ref, "passed": True, "commonRuns": 3, "gold": 370})

report = {
    "scope": "actual V2Data module; synthetic offline roundtrip",
    "results": results,
    "realClientPersistenceTested": False,
}
out = ROOT / "design/v2/reports/runtime-roundtrip.json"
out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps(report, indent=2))

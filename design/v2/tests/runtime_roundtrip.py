"""Real V2Data writer against frozen V1 ledgers, with synthetic data only.

Uses the existing probe helpers. This proves an offline module/format contract,
not the native client's SavedVariables serialization or the final V2 interface.
"""

from pathlib import Path
import json
from compatibility_probe import context, freeze

ROOT = Path(__file__).resolve().parents[3]
MODULE = (ROOT / "AzerothStats/V2Data.lua").read_text(encoding="utf-8")
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
        run.status = 'ended'
        assert(A.ValidateDatabase(A.db))
    """
    )
    saved = freeze(v2.globals().AzerothStats.db)
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

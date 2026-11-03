"""Synthetic shared-format feasibility probe against frozen published V1 code.

This is NOT a production migration or a client SavedVariables integration test.
It reads the repository, never the player's save. The V2 common writer is the
existing frozen V1 ledger, intentionally reused rather than reimplemented here.
Run with the project's developer Lupa dependency available on PYTHONPATH.
"""

from pathlib import Path
import json
import subprocess
import argparse
import tempfile
from lupa.lua51 import LuaRuntime, lua_type

ROOT = Path(__file__).resolve().parents[3]
TAGS = ["v1.6.2-beta.1", "v1.7.0-beta.1", "0a3b414"]


def source(ref, name):
    return subprocess.check_output(
        ["git", "show", f"{ref}:AzerothStats/{name}"], cwd=ROOT
    ).decode("utf-8-sig")


def context(ref, database=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(source(ref, "tests/mock.lua"))
    for name in source(ref, "AzerothStats.toc").splitlines():
        if name.endswith(".lua"):
            lua.execute(source(ref, name))
    if database is not None:
        lua.globals().AzerothStatsDB = thaw(lua, database)
    lua.execute("assert(AzerothStats.InitDB(), 'V1 must accept the shared database')")
    lua.execute(
        """
        function ProbeRun(gold)
            local A = AzerothStats
            A.db.sequence = A.db.sequence + 1
            local run = { id = 'azstats-' .. A.db.sequence, class = 'warrior',
                hero = 'Synthetic', zone = 'elwynn', heroic = 1, status = 'ended',
                result = 'victory', startedAt = 1000 + A.db.sequence,
                values = { gold = gold, kills = 30, duration = 60, damage = 9000 },
                accounted = {}, events = {}, meters = {} }
            table.insert(A.db.runs, run)
            A.Account(run)
            A.Account(run) -- repeated observation must not count twice
            return run.id
        end
    """
    )
    return lua


def freeze(value):
    if lua_type(value) == "table":
        return {key: freeze(item) for key, item in value.items()}
    assert value is None or isinstance(value, (str, int, float, bool))
    return value


def thaw(lua, value):
    if isinstance(value, dict):
        table = lua.table()
        for key, item in value.items():
            table[key] = thaw(lua, item)
        return table
    return value


def run_probe(ref):
    v1 = context(ref)
    first = v1.globals().ProbeRun(100)
    baseline = freeze(v1.globals().AzerothStats.db)
    # Candidate V2 structure: the core schema remains 1. New strings/objects
    # cannot be placed inside the numeric sum/accounted maps read by V1.
    candidate = context(ref, baseline)
    second = candidate.globals().ProbeRun(200)
    candidate.globals().AzerothStats.db.extensions = thaw(
        candidate,
        {
            "azerothStatsV2": {
                "schema": 1,
                "runs": {
                    second: {
                        "affixes": {1: "sanguine"},
                        "encounters": {1: {"name": "Synthetic boss", "at": 30}},
                        "sampled": True,
                    }
                },
                "preferences": {"theme": "chroniques"},
            }
        },
    )
    candidate.execute("assert(AzerothStats.ValidateDatabase(AzerothStats.db))")
    snapshot = freeze(candidate.globals().AzerothStats.db)

    rollback = context(ref, snapshot)
    assert rollback.globals().AzerothStats.db.totals.runs == 2
    assert rollback.globals().AzerothStats.db.totals.sum.gold == 300
    assert rollback.globals().AzerothStats.db.runs[1].id == first
    assert rollback.globals().AzerothStats.db.runs[2].id == second
    assert (
        freeze(rollback.globals().AzerothStats.db.extensions) == snapshot["extensions"]
    )
    third = rollback.globals().ProbeRun(70)

    back_to_v2 = context(ref, freeze(rollback.globals().AzerothStats.db))
    assert back_to_v2.globals().AzerothStats.db.totals.runs == 3
    assert back_to_v2.globals().AzerothStats.db.totals.wins == 3
    assert back_to_v2.globals().AzerothStats.db.totals.sum.gold == 370
    assert back_to_v2.globals().AzerothStats.db.runs[3].id == third
    assert (
        freeze(back_to_v2.globals().AzerothStats.db.extensions)
        == snapshot["extensions"]
    )
    # An old version's explicit full-data reset is intentionally destructive.
    # New metadata is reconciled by IDs, not silently used to recreate deleted runs.
    back_to_v2.execute("table.remove(AzerothStats.db.runs, 2)")
    back_to_v2.execute("assert(AzerothStats.ValidateDatabase(AzerothStats.db))")
    ids = {r["id"] for r in freeze(back_to_v2.globals().AzerothStats.db.runs).values()}
    assert second not in ids
    return {
        "reader": ref,
        "passed": True,
        "roundTrip": "V1 -> candidate common writer -> frozen V1 -> candidate reader",
        "runs": 3,
        "gold": 370,
        "checks": 12,
        "ui": "simulated",
        "realClientPersistenceTested": False,
    }


def native_probe(ref, executable):
    def chunk(text):
        # Lua 5.0 has no [===[extended long string]===] syntax. This is
        # trusted repository source in a test only, never a runtime evaluator.
        return "assert(loadstring(" + json.dumps(text, ensure_ascii=False) + "))()\n"

    chunks = [chunk(source(ref, "tests/mock.lua"))]
    chunks += [
        chunk(source(ref, name))
        for name in source(ref, "AzerothStats.toc").splitlines()
        if name.endswith(".lua")
    ]
    chunks.append(
        """
local A = AzerothStats
assert(A.InitDB())
local function add(gold)
    A.db.sequence = A.db.sequence + 1
    local r = {id='azstats-'..A.db.sequence, class='warrior', hero='Synthetic',
      status='ended', result='victory', values={gold=gold,kills=30,duration=60},
      accounted={},events={},meters={}}
    table.insert(A.db.runs,r)
    A.Account(r); A.Account(r)
    return r
end
local first = add(100)
local second = add(200) -- candidate V2 uses the existing common ledger
A.db.extensions={azerothStatsV2={schema=1,runs={
  [second.id]={affixes={'sanguine'},encounters={{at=30,name='Synthetic boss'}}}}}}
assert(A.ValidateDatabase(A.db))
local function encode(v)
    if type(v)=='string' then return string.format('%q',v) end
    if type(v)~='table' then return tostring(v) end
    local out={'{'}
    for k,x in pairs(v) do table.insert(out,'['..encode(k)..']='..encode(x)..',') end
    table.insert(out,'}'); return table.concat(out)
end
local saved=encode(A.db)
AzerothStatsDB=assert(loadstring('return '..saved))()
assert(A.InitDB()) -- frozen V1 reads a saved candidate extended database
assert(A.db.totals.runs==2 and A.db.totals.sum.gold==300)
assert(A.db.runs[1].id==first.id and A.db.runs[2].id==second.id)
assert(A.db.extensions.azerothStatsV2.runs[second.id].affixes[1]=='sanguine')
add(70) -- continue playing after rollback
saved=encode(A.db)
AzerothStatsDB=assert(loadstring('return '..saved))()
assert(A.InitDB())
assert(A.db.totals.runs==3 and A.db.totals.wins==3 and A.db.totals.sum.gold==370)
assert(A.db.extensions.azerothStatsV2.runs[second.id].encounters[1].at==30)
print('NATIVE_SHARED_FORMAT_PROBE_PASSED')
"""
    )
    with tempfile.TemporaryDirectory(prefix="azstats-v2-format-") as tmp:
        path = Path(tmp) / "probe.lua"
        path.write_text("\n".join(chunks), encoding="utf-8", newline="\n")
        result = subprocess.run(
            [str(executable), str(path)], capture_output=True, text=True, timeout=30
        )
        assert (
            result.returncode == 0
            and "NATIVE_SHARED_FORMAT_PROBE_PASSED" in result.stdout
        ), (result.stdout + result.stderr)
    return {
        "reader": ref,
        "runtime": "Lua 5.0.3 native",
        "passed": True,
        "realClientPersistenceTested": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua50", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    results = [run_probe(ref) for ref in TAGS]
    native = [native_probe(ref, args.lua50) for ref in TAGS] if args.lua50 else []
    report = {
        "scope": "format feasibility only; no production V2 exists yet",
        "results": results,
        "native": native,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))

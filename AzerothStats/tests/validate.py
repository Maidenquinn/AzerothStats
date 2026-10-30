"""Run with Python 3 + lupa (Lua 5.1). Optional --deps points at site-packages.
Executes an explicitly selected trusted API fixture, or reads a local client for compatibility.
An optional trusted SavedVariables backup is read in memory; inputs and game files are never written.
"""

import argparse, hashlib, json, re, sys, subprocess, tempfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--deps")
parser.add_argument("--lua50", help="Optional path to the native Lua 5.0 interpreter")
parser.add_argument(
    "--legacy-saved", help="Optional existing V1 SavedVariables file, read only"
)
fixture_args = parser.add_mutually_exclusive_group(required=True)
fixture_args.add_argument("--client", help="Optional installed client, read only")
fixture_args.add_argument(
    "--api", help="Trusted API Lua file supplied by the game team"
)
args = parser.parse_args()
if args.deps:
    sys.path.insert(0, args.deps)
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parent.parent
toc = root.joinpath("AzerothStats.toc").read_text(encoding="utf-8")
files = [s.strip() for s in toc.splitlines() if s.strip() and not s.startswith("#")]
assert "## Interface: 11200" in toc and "## SavedVariables: AzerothStatsDB" in toc
assert set(files) == {p.name for p in root.glob("*.lua")}


# Parse Lua 5.1 bytecode prototypes to check Lua 5.0's 32-upvalue ceiling.
class Chunk:
    def __init__(self, b):
        self.b, self.pos, self.maximum, self.count = b, 12, 0, 0
        self.order = "little" if b[6] else "big"
        self.isize, self.ssize, self.ins, self.numsize = b[7:11]
        self.proto()

    def n(self, size):
        val = int.from_bytes(self.b[self.pos : self.pos + size], self.order)
        self.pos += size
        return val

    def integer(self):
        return self.n(self.isize)

    def string(self):
        size = self.n(self.ssize)
        self.pos += size

    def proto(self):
        self.count += 1
        self.string()
        self.integer()
        self.integer()
        self.maximum = max(self.maximum, self.n(1))
        self.pos += 3
        count = self.integer()
        self.pos += count * self.ins
        for _ in range(self.integer()):
            t = self.n(1)
            if t == 1:
                self.pos += 1
            elif t == 3:
                self.pos += self.numsize
            elif t == 4:
                self.string()
            else:
                assert t == 0
        for _ in range(self.integer()):
            self.proto()
        count = self.integer()
        self.pos += count * self.isize
        for _ in range(self.integer()):
            self.string()
            self.integer()
            self.integer()
        for _ in range(self.integer()):
            self.string()


compiler = LuaRuntime(encoding=None)
compile_lua = compiler.eval(
    b"function(s) local f,e=loadstring(s);assert(f,e);return string.dump(f) end"
)
report = {
    "runtime": "Lua 5.1 via lupa; NOT a Lua 5.0 VM or an in-game visual test",
    "files": {},
}
for name in files:
    raw = (root / name).read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), name
    # Production sources deliberately avoid post-5.0 syntax and library additions.
    assert not re.search(
        rb"(?m)^\s*[^-\n].*(?:\bgoto\b|\bstring\.gmatch\b|\btable\.unpack\b|\bselect\s*\(|(?<![<>=~])#)",
        raw,
    ), name
    code = re.sub(rb'"(?:[^"\\]|\\.)*"', b'""', raw)
    code = re.sub(rb"--[^\n]*", b"", code)
    assert b"..." not in code and b"%" not in code, name
    chunk = Chunk(compile_lua(raw))
    assert chunk.maximum <= 32, (name, chunk.maximum)
    report["files"][name] = {
        "sha256": hashlib.sha256(raw).hexdigest(),
        "prototypes": chunk.count,
        "maxUpvalues": chunk.maximum,
    }

sys.path.insert(0, str(root.parent / "tools"))
from client_fixture import read_fixture

api, fixture_metadata = read_fixture(args.client, args.api)
report["fixture"] = fixture_metadata


def runtime(saved=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((root / "tests/mock.lua").read_text(encoding="utf-8-sig"))
    lua.execute(
        'function time() return 1792668856 + NOW end; function date(f,t) return "22/10 12:00" end'
    )
    lua.execute(api, name="actual-client-api")
    if saved:
        lua.execute("AzerothStatsDB=" + saved)
    for name in files:
        lua.execute((root / name).read_text(encoding="utf-8"), name=name)
    return lua


lua = runtime()
lua.execute((root / "tests/scenarios.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/interface.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/usage.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/collection.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/insights.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/serialize.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/favorites_deaths.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/security.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/bar.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/heroic.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/reports.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/journal.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/ux_review.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/data_management.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/editing.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/themes.lua").read_text(encoding="utf-8"))
report["assertions"] = lua.globals().TEST_COUNT
lua.execute((root / "tests/serialize.lua").read_text(encoding="utf-8-sig"))
saved = lua.eval("SNAPSHOT(AzerothStatsDB)")
expected = lua.globals().PERSISTENCE_EXPECT
again = runtime(saved)
again.execute(
    "assert(AzerothStats.InitDB()); AzerothStats.BuildUI(); AzerothStats.Sample()"
)
assert again.eval("AzerothStatsDB.totals.runs") == expected.runs
assert again.eval("AzerothStatsDB.totals.sum.damage") == expected.damage
assert again.eval("AzerothStatsDB.sequence") == expected.sequence
report["persistenceRoundTrip"] = True
if args.legacy_saved:
    legacy_source = Path(args.legacy_saved).read_text(encoding="utf-8-sig")
    legacy = runtime()
    legacy.globals().LEGACY = legacy_source
    legacy.execute(
        "local env={};local f=assert(loadstring(LEGACY));setfenv(f,env);f();AzerothStatsDB=env.AzerothStatsDB;AzerothStats.db=AzerothStatsDB;AzerothStats.CorrectChests();AzerothStats.NormalizeJewelry();LEGACY_RUNS=AzerothStats.Sign(AzerothStatsDB.runs);LEGACY_TOTALS=AzerothStats.Sign(AzerothStatsDB.totals);LEGACY_CLASSES=AzerothStats.Sign(AzerothStatsDB.classes)"
    )
    legacy.execute(
        'assert(AzerothStats.InitDB());AzerothStats.DetectLocale();AzerothStats.BuildUI();AzerothStats.ToggleUI(true);for _,lg in ipairs(AzerothStats.languages) do if lg[1]~="auto" then AzerothStats.SetLanguage(lg[1]);for i=1,table.getn(AzerothStats.tabs) do AzerothStats.view.tab=i;AzerothStats.RefreshUI() end end end;assert(LEGACY_RUNS==AzerothStats.Sign(AzerothStatsDB.runs));assert(LEGACY_TOTALS==AzerothStats.Sign(AzerothStatsDB.totals));assert(LEGACY_CLASSES==AzerothStats.Sign(AzerothStatsDB.classes))'
    )
    report["existingV1Database"] = {
        "runs": legacy.eval("table.getn(AzerothStatsDB.runs)"),
        "runsTotalsClassesUnchangedAfterChestCorrection": True,
        "chestMigrationIdempotent": True,
        "inputSha256": hashlib.sha256(legacy_source.encode("utf-8")).hexdigest(),
    }
report["tocReferences"] = "all present, correct order, all production Lua included"
if args.lua50:
    with tempfile.TemporaryDirectory(prefix="azerothstats-test-") as temp:
        fixture = Path(temp) / "client-api.lua"
        fixture.write_text(api, encoding="utf-8")
        native = subprocess.run(
            [str(Path(args.lua50).resolve()), "tests/native50.lua", str(fixture)],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert native.returncode == 0, native.stdout + native.stderr
        assert "LUA50 PERSISTENCE OK" in native.stdout
        report["nativeLua50"] = {
            "version": "Lua 5.0.3",
            "exitCode": native.returncode,
            "output": native.stdout,
        }
(root / "tests/results.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))

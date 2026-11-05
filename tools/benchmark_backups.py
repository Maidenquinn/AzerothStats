"""Synthetic backup scaling benchmark. Never reads player SavedVariables."""

from pathlib import Path
from time import perf_counter
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parent.parent / "AzerothStats"
toc = (root / "AzerothStats.toc").read_text(encoding="utf-8")
modules = [
    line.strip()
    for line in toc.splitlines()
    if line.strip() and not line.startswith("#")
]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests/mock.lua").read_text(encoding="utf-8-sig"))
for name in modules:
    lua.execute((root / name).read_text(encoding="utf-8"))
lua.execute("assert(AzerothStats.InitDB())")
lua.execute(
    """
AzerothStatsBackup = nil
AzerothStatsAutoBackup = nil
AzerothStats.db.settings.autoBackupRetention = 2
AzerothStats.db.settings.autoBackupEveryRuns = 0
function AZS_BenchmarkFill(n)
    local A = AzerothStats
    A.db.runs = {}
    for i = 1, n do
        A.db.runs[i] = {
            id = "benchmark-" .. i, class = "warrior", hero = "Synthetic",
            zone = "feralas", heroic = 0, startedAt = i,
            status = "ended", result = "victory",
            values = { duration = 100, damage = i * 10 },
            events = {}, meters = {},
            accounted = { duration = 100, damage = i * 10 },
            counted = true, winCounted = true,
        }
    end
    A.db.sequence = n
end
function AZS_BenchmarkBackup()
    local ok, err = AzerothStats.CreateDataBackup(true)
    assert(ok, err)
    return #AzerothStatsAutoBackup.entries
end
"""
)
fill = lua.globals().AZS_BenchmarkFill
backup = lua.globals().AZS_BenchmarkBackup
for count in (100, 500, 1000):
    fill(count)
    start = perf_counter()
    entries = backup()
    elapsed_ms = (perf_counter() - start) * 1000
    assert entries <= 2, "retention exceeded"
    print(f"synthetic runs={count} backup_ms={elapsed_ms:.2f} auto_entries={entries}")
print("PASS: synthetic backup scaling and retention (not an in-game FPS benchmark)")

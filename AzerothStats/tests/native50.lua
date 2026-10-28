-- Run from the addon directory: lua50.exe tests/native50.lua <extracted-api-file>
assert(arg and arg[1], "Pass the read-only extracted client API path")
local files = {}
for line in io.lines("AzerothStats.toc") do
    if string.find(line, "%.lua$") then
        table.insert(files, line)
    end
end
local count = table.getn(files)
for _, name in ipairs({
    "tests/mock.lua",
    "tests/scenarios.lua",
    "tests/serialize.lua",
    "tests/native50.lua",
    "tests/interface.lua",
    "tests/usage.lua",
    "tests/collection.lua",
    "tests/release_case.lua",
    "tests/release_runner.lua",
    "tests/insights.lua",
    "tests/favorites_deaths.lua",
    "tests/security.lua",
    "tests/bar.lua",
    "tests/heroic.lua",
    "tests/reports.lua",
    "tests/journal.lua",
    "tests/ux_review.lua",
}) do
    table.insert(files, name)
end
for _, name in ipairs(files) do
    assert(loadfile(name))
    print("LUA50 SYNTAX OK", name)
end
dofile("tests/mock.lua")
function time()
    return 1792668856 + NOW
end
function date(f, t)
    return "22/10 12:00"
end
dofile(arg[1])
for i = 1, count do
    dofile(files[i])
end
dofile("tests/scenarios.lua")
dofile("tests/interface.lua")
dofile("tests/usage.lua")
dofile("tests/collection.lua")
dofile("tests/insights.lua")
dofile("tests/serialize.lua")
dofile("tests/favorites_deaths.lua")
dofile("tests/security.lua")
dofile("tests/bar.lua")
dofile("tests/heroic.lua")
dofile("tests/reports.lua")
dofile("tests/journal.lua")
dofile("tests/ux_review.lua")
dofile("tests/serialize.lua")
local source = "AzerothStatsDB=" .. SNAPSHOT(AzerothStatsDB)
local expected = AzerothStatsDB.totals.sum.damage
AzerothStatsDB = nil
assert(loadstring(source))()
assert(AzerothStatsDB.totals.sum.damage == expected)
print("LUA50 PERSISTENCE OK")

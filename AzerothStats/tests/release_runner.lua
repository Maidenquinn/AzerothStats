-- CLI: lua50 release_runner.lua addonDir apiPath savedIn savedOut stage class result index
local root, api, input, output = arg[1], arg[2], arg[3], arg[4]
RELEASE_STAGE = tonumber(arg[5])
RELEASE_CLASS = arg[6]
RELEASE_RESULT = arg[7]
RELEASE_INDEX = tonumber(arg[8])
dofile("tests/mock.lua")
function time()
    return 1792668856 + NOW
end
function date(f, t)
    return "22/10 12:00"
end
dofile(api)
if input ~= "-" then
    dofile(input)
end
for name in io.lines(root .. "/AzerothStats.toc") do
    name = string.gsub(name, "\r$", "")
    if string.find(name, "%.lua$") then
        dofile(root .. "/" .. name)
    end
end
dofile("tests/release_case.lua")
dofile("tests/serialize.lua")
if output ~= "-" then
    local file = assert(io.open(output, "wb"))
    file:write("AzerothStatsDB=" .. SNAPSHOT(AzerothStatsDB))
    file:close()
end

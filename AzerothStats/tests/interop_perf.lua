-- Dedicated AZST1 serializer benchmark. Synthetic workload; timings are
-- informational and intentionally have no machine-dependent pass threshold.
local A = AzerothStats
assert(type(A.ExportCodeV1) == "function", "AZST1 serializer unavailable")

local function makeRun(index)
    return {
        id = "azstats-bench-" .. index,
        zone = "elwynn",
        class = "warrior",
        heroic = 3,
        status = "ended",
        result = "victory",
        partial = false,
        startedAt = 1794300000 + index,
        endedAt = 1794300900 + index,
        values = {
            duration = 900,
            level = 60,
            kills = 1000 + index,
            gold = 250,
            damage = 1250000 + index,
            taken = 4500,
            healing = 4400,
            peakDps = 25000,
            bosses = 5,
            elites = 20,
            guardians = 4,
            chests = 12,
            magnets = 3,
        },
    }
end

local function benchmark(count)
    local started = os.clock()
    local bytes = 0
    for index = 1, count do
        local code = A.ExportCodeV1(makeRun(index))
        assert(type(code) == "string", "AZST1 export failed at " .. index)
        assert(string.sub(code, 1, 7) == "AZST1:{", "invalid AZST1 prefix")
        assert(string.sub(code, -1) == "}", "truncated AZST1 JSON")
        assert(string.len(code) <= 8192, "AZST1 byte limit exceeded")
        bytes = bytes + string.len(code)
    end
    return os.clock() - started, bytes
end

local oneTime, oneBytes = benchmark(1)
local hundredTime, hundredBytes = benchmark(100)
local thousandTime, thousandBytes = benchmark(1000)
assert(oneBytes > 0 and hundredBytes > oneBytes and thousandBytes > hundredBytes)
print(
    string.format(
        "AZST1 serializer benchmark (synthetic): 1=%0.6fs/%dB; 100=%0.6fs/%dB; 1000=%0.6fs/%dB",
        oneTime,
        oneBytes,
        hundredTime,
        hundredBytes,
        thousandTime,
        thousandBytes
    )
)

local A = AzerothStats
local saved = {
    db = A.db,
    run = A.run,
    globals = AzerothStatsDB,
    time = NOW,
    units = AZS_UNITS,
    revive = AZS_REVIVE,
    pets = AZS_PETS,
    zone = AZS_ZONE,
    stats = AZS_STATS,
    at = A.runPacketAt,
    boss = AZS_BOSSMETER,
}
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, "V2 observe: " .. label)
end
AzerothStatsDB = nil
A.InitDB()
local r = {
    id = "azstats-1",
    class = "warrior",
    zone = "elwynn",
    status = "active",
    values = { duration = 15, kills = 20, gold = 30 },
    accounted = {},
    meters = {},
    events = {},
}
A.db.runs[1], A.run, A.runPacketAt = r, r, NOW
A.v2Packets = nil
A.ObserveV2World(r)
local function data()
    return A.V2Store(false).runs[r.id]
end
check(table.getn(data().progression) == 1, "initial progression point")
A.ObserveV2World(r)
check(table.getn(data().progression) == 1, "duplicate poll not a new point")
AZS_UNITS = { { kind = "boss", id = 42, name = "Synthetic boss", hp = 100, hpm = 100 } }
A.ObserveV2World(r)
check(table.getn(data().encounters) == 0, "unnotified world state is ignored")
A.V2Packet("AZSUNITS")
A.ObserveV2World(r)
check(table.getn(data().encounters) == 1, "fresh boss observation retained")
AZS_UNITS = {}
A.V2Packet("AZSUNITS")
A.ObserveV2World(r)
check(
    data().encounters[1].closedAt == 15 and not r.values.bosses,
    "disappearance closes observation without inventing kill"
)
AZS_REVIVE = { down = 0 }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
AZS_REVIVE = { down = 1, by = "Friend", share = 0.2 }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
AZS_REVIVE = { down = 1, by = "" }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
check(data().support[4].kind == "interrupted", "interrupted attempt distinct from return")
AZS_REVIVE = { down = 0 }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
check(data().support[5].kind == "returned", "return observed without claiming causal revival")
AZS_REVIVE = { down = 0, reviving = "Friend", rshare = 0.2 }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
AZS_REVIVE = { down = 0, reviving = "" }
A.V2Packet("AZSREVIVE")
A.ObserveV2World(r)
check(
    data().support[6].direction == "out" and data().support[7].kind == "attemptEnded",
    "outgoing attempts do not claim successful revives"
)
AZS_BOSSMETER = {}
for i = 1, 8 do
    table.insert(AZS_BOSSMETER, { name = string.rep("Source", 20) .. i, dmg = i * 100 })
end
A.V2Packet("AZSBOSSDMG")
A.ObserveV2World(r)
check(
    data().bossSamples[1].seq == 1 and table.getn(data().bossSamples[1].rows) == 8,
    "long source names fit bounded boss snapshots"
)
A.V2Packet("AZSBOSSDMG")
A.ObserveV2World(r)
check(table.getn(data().bossSamples) == 1, "unchanged shared boss snapshot is deduplicated")
AZS_PETS = { { key = "imp", name = "Imp" }, { key = "imp", name = "Imp" } }
A.V2Packet("AZSPETS")
A.ObserveV2World(r)
check(data().summons == nil, "optional summons collection defaults off")
A.V2Store(false).preferences.summons = true
A.V2Packet("AZSPETS")
A.ObserveV2World(r)
check(data().summons.Imp.maximum == 2, "maximum simultaneous presence, not casts")
AZS_ZONE = { zone = "elwynn", class = "warrior", affixes = "sanguine,explosive" }
A.V2Packet("AZSZONE")
A.ObserveV2World(r)
check(
    data().affixesRaw == "sanguine,explosive",
    "native raw affix string kept without guessed parsing"
)
r.values.duration, r.values.kills = 60, 3
A.runPacketAt = NOW
A.ObserveV2World(r)
check(data().progression[2].gap, "missing interval/counter decrease breaks curve")
A.V2Packet("AZSUNITS")
A.Packet("AZSRUN", "ph=ready;t=0")
check(A.v2Packets == nil, "known ready boundary clears stale world notifications")
A.db, A.run, AzerothStatsDB, NOW = saved.db, saved.run, saved.globals, saved.time
AZS_UNITS, AZS_REVIVE, AZS_PETS, AZS_ZONE, AZS_STATS =
    saved.units, saved.revive, saved.pets, saved.zone, saved.stats
A.runPacketAt, A.v2Packets = saved.at, nil
AZS_BOSSMETER = saved.boss
print("V2 NATIVE OBSERVATIONS PASSED", TEST_COUNT)

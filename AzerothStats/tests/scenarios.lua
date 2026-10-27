local A = AzerothStats
TEST_COUNT = 0
local function check(ok, message)
    assert(ok, message)
    TEST_COUNT = TEST_COUNT + 1
end
local function reset()
    AzerothStatsDB = nil
    A.db = nil
    A.run = nil
    A.newBoundary = nil
    A.boundaryGate = nil
    A.buildBaseline = nil
    A.inReady = nil
    A.packetReady = nil
    A.packetSummary = nil
    A.meterPackets = nil
    AZS_RUN = {}
    AZS_END = {}
    AZS_ZONE = { zone = "feralas", zname = "Feralas", class = "rogue" }
    AZS_METER = {}
    AZS_HEALING = {}
    AZS_BOSSMETER = {}
    AZS_TAKEN = {}
    AZS_SPELLS = {}
    AZS_STATS = {}
    AZS_END_UPDATED = nil
    AZS_METER_UPDATED = nil
    AZS_HEALING_UPDATED = nil
    AZS_BOSSMETER_UPDATED = nil
    AZS_TAKEN_UPDATED = nil
    check(A.InitDB(), "init db")
end
local function emit(prefix, payload, reverse)
    NOW = NOW + 1
    if reverse then
        A.Packet(prefix, payload)
    end
    event = "CHAT_MSG_ADDON"
    arg1 = prefix
    arg2 = payload
    AZS_ApiOnEvent()
    if not reverse then
        A.Packet(prefix, payload)
    end
end
local function playing(t, kills)
    emit(
        "AZSRUN",
        "ph=playing;t="
            .. t
            .. ";kills="
            .. (kills or 0)
            .. ";lvl=2;gold=7;dealt=100;taken=4;chest=1"
    )
    A.Sample()
end
-- A reload can miss the one-shot zone packet. Only recognized native names or
-- plausible continuity may fill that gap; neither a different map nor an ended
-- run is silently borrowed to improve the display.
local zoneFunctions = { GetMinimapZoneText, GetSubZoneText, GetRealZoneText, GetZoneText }
GetMinimapZoneText = function()
    return A.gameText.fr["zone.arena.name"]
end
GetSubZoneText, GetRealZoneText, GetZoneText = nil, nil, nil
reset()
AZS_ZONE = {}
playing(120, 5)
local observed = A.run
check(
    observed.zone == "arena" and observed.zoneSource == "GetMinimapZoneText",
    "recognized native zone fills a missed packet"
)
GetMinimapZoneText = function()
    return "Unrelated Hall"
end
A.run = nil
local sequence = A.db.sequence
playing(121, 6)
check(
    A.run == observed and A.db.sequence == sequence and A.run.zone == "arena",
    "reload continuity preserves the observed map without duplicating the run"
)
reset()
AZS_ZONE = {}
playing(10, 1)
observed = A.run
check(not observed.zone, "unknown native labels never become a guessed map")
GetRealZoneText = function()
    return A.gameText.en["zone.arena.name"]
end
playing(11, 2)
check(
    A.run == observed and A.run.zone == "arena",
    "late recognized native metadata repairs the same live run"
)
AZS_ZONE = { zone = "feralas", class = "rogue" }
local _, _, _, packetZone = A.Identity()
check(packetZone == "feralas", "explicit packet map wins over native fallback")
GetRealZoneText = nil
for language, dictionary in pairs(A.gameText) do
    AZS_ZONE = {}
    GetMinimapZoneText = function()
        return dictionary["zone.arena.name"]
    end
    local _, _, _, localized = A.Identity()
    check(localized == "arena", "native zone names resolve across catalog language " .. language)
end
GetMinimapZoneText = function()
    return "Unrelated Hall"
end
reset()
playing(120, 5)
observed = A.run
A.run = nil
AZS_ZONE = {}
playing(1, 1)
check(A.run.id ~= observed.id and not A.run.zone, "a reset clock does not inherit the prior map")
GetMinimapZoneText, GetSubZoneText, GetRealZoneText, GetZoneText =
    zoneFunctions[1], zoneFunctions[2], zoneFunctions[3], zoneFunctions[4]
reset()
A.Sample()
check(table.getn(A.db.runs) == 0, "no phantom run outside game")
playing(0, 0)
check(A.run.values.healing == nil, "empty initialization is not an exact zero")
emit("AZSHEAL", "")
A.Sample()
check(A.run.values.healing == 0, "received empty meter is a valid zero")
reset()
AZS_METER = { { name = "Old", dmg = 999, dps = 99 } }
AZS_HEALING = { { name = "Old heal", dmg = 80, dps = 8 } }
emit("AZSRUN", "ph=ready;t=0")
A.Sample()
check(table.getn(A.db.runs) == 0, "ready is not a played run")
playing(1, 1)
local r = A.run
check(
    r.values.damage == 100 and r.values.healing == nil and r.meters.damage == nil,
    "stale meters gated"
)
emit("AZSMETER", "Fireball,60,60,60,0;Melee,40,40,40,0", true)
emit("AZSHEAL", "Heal,25,25,100,0")
emit("AZSBOSSDMG", "Fireball,20,10,100,0")
emit("AZSTAKEN", "mob melee,4")
A.Sample()
check(
    r.meters.damage.total == 100 and r.values.healing == 25 and r.meters.taken.total == 4,
    "real API meter formats"
)
check(r.meters.boss.total == 20 and r.values.bosses == nil, "last boss meter not a kill count")
for i = 1, 40 do
    A.Sample()
end
check(
    A.db.totals.sum.damage == 100 and A.db.totals.sum.healing == 25 and A.db.totals.runs == 1,
    "idempotent totals"
)
check(
    A.db.totals.spells.damage.Fireball == 60 and A.db.classes.rogue.spells.healing.Heal == 25,
    "idempotent spell ledger and class aggregation"
)
check(r.meters.boss.total == 20, "boss snapshots never summed")
NOW = NOW + 100
A.Sample()
check(
    r.values.duration == 1 and AZS_GetRunTime() > 1,
    "records use raw server clock, not interpolation"
)
emit("AZSRUN", "ph=choosing;t=1;kills=1;lvl=2")
A.Sample()
check(A.run == r and r.values.duration == 1, "choosing preserves run")
emit("AZSRUN", "ph=paused;t=1;kills=1;lvl=2")
A.Sample()
check(A.run == r, "paused preserves run")
emit("AZSRUN", "ph=dead;t=12;kills=4;lvl=3;gold=15")
A.Sample()
check(r.status == "terminal" and r.result == nil, "terminal waits for official summary")
emit(
    "AZSEND",
    "result=defeat;t=12;lvl=3;kills=4;elites=2;guardians=1;bosses=1;dmg=140;taken=9;gold=15;chests=2;magnets=1;hero=Player;zone=feralas;class=rogue"
)
A.Sample()
check(
    r.status == "ended" and r.values.elites == 2 and r.values.damage == 140 and r.values.gold == 15,
    "exact official summary mapping"
)
-- Simulate the same final packet after reload; no duplicate run or aggregates.
A.run = nil
A.Sample()
check(
    A.run == r and r.resumeHeuristic and table.getn(A.db.runs) == 1,
    "reload continuity tagged heuristic"
)
for i = 1, 8 do
    A.Packet("AZSEND", "")
    A.Sample()
end
check(A.db.totals.runs == 1 and A.db.totals.sum.damage == 140, "terminal duplicate packets")
emit("AZSRUN", "ph=ready;t=0")
A.Sample()
playing(0, 0)
local second = A.run
check(
    second ~= r
        and second.values.elites == nil
        and second.values.healing == nil
        and second.summary == nil,
    "new run never inherits summary or heals"
)
playing(20, 10)
local before = A.run
playing(0, 0)
check(A.run ~= before and before.status == "interrupted", "clock reset separates runs")
local current = A.run
AZS_RUN = {}
A.Sample()
check(
    A.run == current and current.result == nil and current.apiMissing,
    "missing phase does not fabricate end"
)
playing(51, 10)
check(not A.run.apiMissing, "valid phase clears transient API diagnostic")
reset()
playing(0, 0)
playing(50, 9)
r = A.run
local beforeFinal = table.getn(r.timeline)
emit("AZSRUN", "ph=victory;t=50;kills=9;lvl=5")
A.Sample()
check(
    table.getn(r.timeline) == beforeFinal + 1
        and r.timeline[table.getn(r.timeline)].phase == "victory",
    "terminal snapshot bypasses 15-second throttle"
)
emit("AZSEND", "result=victory;t=50;kills=9;lvl=5;dmg=500;gold=100;bosses=2")
A.Sample()
check(A.db.totals.wins == 1, "victory counted")
playing(60, 12)
check(
    A.run == r and r.continued and r.official.result == "victory",
    "endless continuation retains official end"
)
emit("AZSEND", "result=left;t=70;kills=15;lvl=6;dmg=800;gold=140;bosses=3")
A.Sample()
check(
    A.db.totals.runs == 1 and A.db.totals.wins == 1 and A.db.totals.sum.damage == 800,
    "continuation updates same lifetime ledger"
)
for i = 1, 10 do
    A.Sample()
end
check(
    r.status == "ended" and A.db.totals.sum.damage == 800,
    "old playing packet after final summary cannot reopen run"
)
emit("AZSMETER", "Spell,100,1,100,0")
A.Sample()
emit("AZSMETER", "Spell,10,1,100,0")
A.Sample()
check(
    r.meters.damage.total == 100 and r.meterReset and r.unavailable.damage,
    "meter reset protected"
)
AZS_METER = { { name = "Bad", dmg = -1 } }
A.Sample()
check(
    r.meters.damage.total == 100 and r.unavailable.damage == "paquet invalide",
    "invalid meter rejected"
)
-- UI command and pagination coverage on real model data.
A.BuildUI()
A.view.cumulative = true
A.view.tab = 4
A.Rows()
A.view.mode = "boss"
A.Rows()
A.view.mode = "damage"
A.view.cumulative = nil
for i = 1, 8 do
    A.view.tab = i
    A.view.page = 1
    A.ToggleUI(true)
    A.RefreshUI()
    check(type(A.Rows()) == "table", "tab " .. i)
end
for _, cmd in ipairs({
    "show",
    "hide",
    "history",
    "diagnose",
    "bar",
    "minimap",
    "lock",
    "resetpos",
    "scale 99",
    "scale .9",
    "class rogue",
    "class all",
    "retention 10",
    "help",
}) do
    SlashCmdList.AZEROTHSTATS(cmd)
end
check(A.db.settings.scale == 0.9 and A.db.settings.maxRuns == 10, "bounded settings commands")
A.view.tab = 8
for _, row in ipairs(A.Rows()) do
    if row.action then
        row.action()
    end
end
A.view.tab = 2
for _, row in ipairs(A.PageModel().cards) do
    if row.action then
        row.action()
    end
end
check(A.view.class == "rogue", "class drilldown")
A.view.class = nil
A.view.tab = 3
for _, row in ipairs(A.Rows()) do
    if row.action then
        row.action()
        break
    end
end
check(A.view.selected ~= nil and A.view.tab == 4, "history selection")
-- Rotation only removes detailed rows; lifetime totals and records survive.
for i = 1, 15 do
    emit("AZSRUN", "ph=ready;t=0")
    A.Sample()
    playing(0, 0)
    playing(i, i)
end
check(
    table.getn(A.db.runs) == 10 and A.db.totals.runs == 16 and A.db.pruned == 6,
    "retention preserves lifetime counters"
)
check(A.db.totals.records.damage.value == 800, "records survive history pruning")
local sum = A.db.totals.sum.duration
for i = 1, 100 do
    A.Sample()
end
check(A.db.totals.sum.duration == sum, "repeated polling stable after pruning")
-- A final summary immediately followed by ready belongs to the preceding run.
local last = A.run
emit("AZSEND", "result=defeat;t=20;hero=Player;zone=feralas;kills=50;dmg=1000")
emit("AZSRUN", "ph=ready;t=0")
A.Sample()
check(last.summary and last.values.kills == 50 and A.run == nil, "summary and ready in same tick")
-- Nil phase plus a delayed end packet is still an official end.
playing(1, 1)
local late = A.run
AZS_RUN = {}
emit("AZSEND", "result=left;t=2;hero=Player;zone=feralas;kills=3;dmg=1600")
A.Sample()
check(late.result == "left" and late.values.damage == 1600, "delayed end with missing phase")
local healingAPI = AZS_GetHealing
AZS_GetHealing = nil
AZS_HEALING = nil
playing(4, 4)
check(A.run.unavailable.healing == "API absente", "missing optional API diagnosed")
AZS_GetHealing = healingAPI
AZS_HEALING = {}
-- An unknown future schema is never rewritten.
local saved = AzerothStatsDB
AzerothStatsDB = { schema = 99, marker = "keep" }
A.db = nil
check(not A.InitDB() and AzerothStatsDB.marker == "keep", "future schema preserved")
AzerothStatsDB = saved
A.InitDB()
PERSISTENCE_EXPECT =
    { runs = A.db.totals.runs, damage = A.db.totals.sum.damage, sequence = A.db.sequence }
print("SCENARIOS PASSED", TEST_COUNT)

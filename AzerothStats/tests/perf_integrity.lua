-- Perf throttles must not drop live run observations.
local A = AzerothStats
local function check(ok, msg)
    assert(ok, msg)
    TEST_COUNT = TEST_COUNT + 1
end
local savedDb, savedRun = AzerothStatsDB, A.run
local oldLink, oldTexture = GetInventoryItemLink, GetInventoryItemTexture
local methods = getmetatable(GameTooltip).__index
local oldSet, oldNum = methods.SetInventoryItem, methods.NumLines
local inventory, descriptions, scanSlot = {}, {}, nil
GetInventoryItemLink = function(unit, slot)
    return inventory[slot]
end
GetInventoryItemTexture = function(unit, slot)
    return inventory[slot] and "Interface\\Icons\\INV_Misc_Book_09"
end
methods.SetInventoryItem = function(self, unit, slot)
    scanSlot = slot
    local first = getglobal("AzerothStatsItemScanTextLeft1")
        or CreateFrame("FontString", "AzerothStatsItemScanTextLeft1")
    first:SetText(descriptions[slot] or ("Slot " .. tostring(slot)))
    return inventory[slot] ~= nil
end
methods.NumLines = function()
    return descriptions[scanSlot] and 1 or 0
end

AzerothStatsDB, A.db, A.run = nil, nil, nil
A.inReady, A.newBoundary, A.boundaryGate, A.buildBaseline = nil, nil, nil, nil
A.packetReady, A.inventoryBaseline, A.packetSummary, A.spellPacket = nil, nil, nil, nil
A.meterPackets, A.statsPacket = nil, nil
AZS_RUN, AZS_ZONE, AZS_END = {}, { class = "rogue", zone = "feralas", heroic = 0 }, {}
AZS_SPELLS, AZS_STATS = {}, {}
AZS_METER, AZS_HEALING, AZS_TAKEN, AZS_BOSSMETER = {}, {}, {}, {}
AZS_METER_UPDATED, AZS_HEALING_UPDATED, AZS_TAKEN_UPDATED = nil, nil, nil
AZS_SPELLS_UPDATED, AZS_STATS_UPDATED, AZS_END_UPDATED = nil, nil, nil
A.InitDB()

local function sample(prefix, text, runFields)
    NOW = NOW + 1
    if runFields then
        AZS_RUN = runFields
    end
    if prefix then
        A.Packet(prefix, text or "")
    end
    A.Sample()
end

sample("AZSRUN", "ph=ready;t=0", { ph = "ready", t = 0 })
sample(
    "AZSRUN",
    "ph=playing;t=1;kills=0;lvl=1;dealt=10",
    { ph = "playing", t = 1, kills = 0, lvl = 1, dealt = 10 }
)
local run = A.run
check(run and run.status == "active", "integrity fixture starts an active run")

for slot = 1, 12 do
    inventory[slot] = "|cffffffff|Hitem:" .. (100 + slot) .. ":0:0:0|h[Gear " .. slot .. "]|h|r"
    descriptions[slot] = "Bonus +" .. slot
end
sample(
    "AZSRUN",
    "ph=playing;t=16;kills=3;lvl=2;dealt=40",
    { ph = "playing", t = 16, kills = 3, lvl = 2, dealt = 40 }
)
check(run.equipment[1] ~= nil, "equipment links captured on snapshot")
check(
    table.getn(run.equipmentPending or {}) > 0 or run.equipmentTooltips[1],
    "tooltip work is queued or partially drained"
)
for i = 1, 8 do
    A.Sample()
end
check(
    (not run.equipmentPending or table.getn(run.equipmentPending) == 0)
        and run.equipmentTooltips[1]
        and run.equipmentTooltips[12],
    "staggered tooltip drains complete without dropping slots"
)

AZS_METER = { { name = "Melee", dmg = 40, dps = 2 } }
AZS_METER_UPDATED = 1
sample("AZSMETER", "Melee,40,2,100,0", { ph = "playing", t = 17, kills = 3, lvl = 2, dealt = 40 })
check(run.meters.damage and run.meters.damage.total == 40, "meter packet is honored immediately")
local firstRead = run.meterReadAt and run.meterReadAt.damage
AZS_METER = {
    { name = "Melee", dmg = 40, dps = 2 },
    { name = "Backstab", dmg = 25, dps = 3 },
}
AZS_METER_UPDATED = 2
NOW = NOW + 0.5
A.Sample()
check(
    run.meters.damage
        and run.meters.damage.total == 65
        and A.db.totals.spells.damage.Backstab == 25,
    "UPDATED stamp forces meter reread inside the 2s quiet window"
)
check(run.meterReadAt.damage ~= nil, "meter read clock is recorded")
check(firstRead == nil or run.meterReadAt.damage >= firstRead, "meter read advances on stamp")

AZS_SPELLS = { { key = "backstab", rank = 1, spell = 53 } }
A.spellPacket = true
A.ObserveBuild(run)
AZS_SPELLS[1].rank = 4
A.spellPacket = nil
AZS_SPELLS_UPDATED = nil
A.ObserveBuild(run)
check(
    run.usage.spells.backstab.maxRank == 4 and run.usage.spells.backstab.gains == 3,
    "rank gains without packet/stamp are still observed immediately"
)

inventory[13] = "|cffffffff|Hitem:200:0:0:0|h[Mark of the Chosen]|h|r"
descriptions[13] = "Luck +10%"
A.ObserveBuild(run)
local firstJewel = run.usage.jewelry["jewel.chosen"]
check(firstJewel and firstJewel.tooltip[1].text == "Luck +10%", "jewelry tooltip captured once")
local captures = 0
local previousCapture = A.CaptureItem
A.CaptureItem = function(...)
    captures = captures + 1
    return previousCapture(...)
end
A.ObserveBuild(run)
A.ObserveBuild(run)
A.CaptureItem = previousCapture
check(captures == 0, "unchanged jewelry does not rescan tooltips every second")

AZS_END = {
    result = "victory",
    t = 20,
    dmg = 65,
    kills = 3,
    taken = 1,
    gold = 10,
    lvl = 2,
    bosses = 1,
    elites = 0,
    guardians = 0,
    chests = 1,
    magnets = 0,
    hero = "Player",
    class = "rogue",
    zone = "feralas",
}
AZS_END_UPDATED = 1
sample("AZSEND", "result=victory", { ph = "victory", t = 20, kills = 3, lvl = 2, dealt = 65 })
check(run.status == "ended" and run.result == "victory", "official summary retained")
check(
    run.equipmentTooltips[1] and run.equipmentTooltips[12],
    "end-of-run finalize keeps equipment descriptions"
)
check(A.db.totals.wins == 1 and A.db.totals.sum.damage == 65, "lifetime ledgers keep final counters")

GetInventoryItemLink, GetInventoryItemTexture = oldLink, oldTexture
methods.SetInventoryItem, methods.NumLines = oldSet, oldNum
AzerothStatsDB, A.db, A.run = savedDb, savedDb, savedRun
if A.db then
    A.RefreshUI()
end
print("PERF DATA INTEGRITY PASSED", TEST_COUNT)

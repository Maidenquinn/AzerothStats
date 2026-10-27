-- Synthetic 0.121 payloads; no native difficulty/armory write is ever called.
local A = AzerothStats
local function check(ok, text)
    assert(ok, text)
    TEST_COUNT = TEST_COUNT + 1
end
local database, live, view = AzerothStatsDB, A.run, A.view
local fields = {}
for _, key in ipairs({
    "newBoundary",
    "boundaryGate",
    "buildBaseline",
    "inReady",
    "packetReady",
    "packetSummary",
    "meterPackets",
    "inventoryBaseline",
    "spellPacket",
    "deathWatch",
    "partySession",
}) do
    fields[key] = { value = A[key] }
    A[key] = nil
end
local globals = {}
for _, key in ipairs({
    "AZS_ZONE",
    "AZS_RUN",
    "AZS_END",
    "AZS_SPELLS",
    "AZS_STATS",
    "AZS_METER",
    "AZS_HEALING",
    "AZS_TAKEN",
    "AZS_BOSSMETER",
}) do
    globals[key] = { value = getglobal(key) }
    _G[key] = {}
end
AzerothStatsDB, A.db, A.run = nil, nil, nil
A.view = { tab = 3, page = 1, mode = "damage", characterTab = "Spells" }
check(A.InitDB(), "heroic fixture initializes schema 1")
local function sample(level, t, phase)
    AZS_ZONE = { zone = "feralas", class = "rogue", heroic = level }
    AZS_RUN = { ph = phase or "playing", t = t, kills = t, lvl = 3 }
    A.Packet("AZSRUN", "ph=" .. (phase or "playing") .. ";t=" .. t)
    A.Sample()
end
for level = 0, 5 do
    sample(nil, 0, "ready")
    sample(level, 10)
    check(
        A.run.heroic == level and A.run.heroicSource == "AZS_ZONE.heroic",
        "exact observed heroic level " .. level
    )
end
sample(nil, 0, "ready")
sample(nil, 10)
check(A.run.heroic == nil, "missing old-client field stays unknown, not Normal")
local unknownId = A.run.id
sample(3, 11)
check(A.run.id == unknownId and A.run.heroic == 3, "late heroic metadata enriches same unknown run")
A.run = nil
sample(nil, 12)
check(
    A.run.id == unknownId and A.run.heroic == 3,
    "reload retains observed heroic when packet is absent"
)
A.run = nil
sample(4, 13)
check(
    A.run.id ~= unknownId and A.run.heroic == 4,
    "known different difficulty cannot resume prior run"
)
sample(nil, 0, "ready")
sample(nil, 1)
check(A.run.heroic == nil, "new unknown run does not inherit prior heroic level")
for _, value in ipairs({ -1, 6, 1.5, "junk", math.huge }) do
    check(A.HeroicLevel(value) == nil, "invalid heroic input rejected")
end
local allCount = table.getn(A.db.runs)
local totals = A.Sign(A.db.totals)
for level = 0, 5 do
    A.view.difficulty = level
    local model = A.PageModel()
    for _, item in ipairs(model.rows) do
        local run = A.IndexRuns()[item.favorite.key]
        check(run.heroic == level, "history difficulty filter is exact")
    end
    check(
        model.cards[1].value == A.Format(table.getn(model.rows)),
        "filtered summary covers only matching retained rows"
    )
end
A.view.difficulty = "unknown"
local model = A.PageModel()
check(table.getn(model.rows) == 1, "unknown history is separate from explicit Normal")
A.view.difficulty = nil
check(
    table.getn(A.PageModel().rows) == allCount and A.Sign(A.db.totals) == totals,
    "filtering never rewrites lifetime ledger"
)
A.ToggleUI(true)
A.RefreshUI()
check(A.ui.difficultyButton:IsShown(), "History exposes difficulty dropdown")
A.ui.difficultyButton.callback(A.ui.difficultyButton)
check(table.getn(A.ui.menu.items) >= 8, "dropdown includes all, Normal, I-V and unknown")
A.ui.menu:Hide()
A.view.tab = 4
A.RefreshUI()
check(not A.ui.difficultyButton:IsShown(), "history filter never silently affects combat aggregate")
-- Expanded native gear tooltips keep set membership, stars and fractional bonuses verbatim.
local methods = getmetatable(GameTooltip).__index
local oldInventory = methods.SetInventoryItem
methods.SetInventoryItem = function(self)
    self.NumLines = function()
        return 58
    end
    for i = 1, 58 do
        local name = "AzerothStatsItemScanTextLeft" .. i
        local line = getglobal(name) or CreateFrame("FontString", name)
        line:SetText(
            i == 58 and "(8) 3 stars: Fireball splits; +0.3% critical strike" or ("Set piece " .. i)
        )
    end
    return true
end
local captured = A.CaptureItem(1)
check(
    table.getn(captured) == 58 and string.find(captured[58].text, "+0.3%", 1, true),
    "set tooltip after line 40 preserves fractional/native text"
)
methods.SetInventoryItem = oldInventory
A.itemTip.NumLines = nil
for key, record in pairs(globals) do
    _G[key] = record.value
end
for key, record in pairs(fields) do
    A[key] = record.value
end
AzerothStatsDB, A.db, A.run, A.view = database, database, live, view
A.RefreshUI()
print("HEROIC HISTORY AND SET TOOLTIP TESTS PASSED", TEST_COUNT)

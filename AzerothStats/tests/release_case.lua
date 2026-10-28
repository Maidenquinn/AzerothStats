-- Release acceptance fixture. All game events below are simulated with the actual client parser.
local A = AzerothStats
local checks = 0
local function check(ok, text)
    assert(ok, text)
    checks = checks + 1
end
local cls = RELEASE_CLASS
local heroic = RELEASE_INDEX - math.floor(RELEASE_INDEX / 6) * 6
UnitClass = function()
    return cls, string.upper(cls)
end
local inventory = {}
local methods = getmetatable(GameTooltip).__index
local scanSlot
GetInventoryItemLink = function(unit, slot)
    return inventory[slot]
end
GetInventoryItemTexture = function(unit, slot)
    return inventory[slot] and "Interface\\Icons\\INV_Misc_Book_09"
end
methods.SetInventoryItem = function(self, unit, slot)
    scanSlot = slot
    for i, text in ipairs({
        slot == 13 and "Mark of the Chosen" or "Release fixture head",
        "+21 Health",
    }) do
        local field = getglobal("AzerothStatsItemScanTextLeft" .. i)
            or CreateFrame("FontString", "AzerothStatsItemScanTextLeft" .. i)
        field:SetText(text)
    end
    return inventory[slot] ~= nil
end
methods.NumLines = function()
    return inventory[scanSlot] and 2 or 0
end
local function equipped()
    inventory[1] = "|Hitem:104020:0:0:0|h[Release fixture head]|h"
    inventory[13] = "|Hitem:900001:0:0:0|h[Mark of the Chosen]|h"
end
local function bootstrap()
    event = "ADDON_LOADED"
    arg1 = "AzerothStats"
    this = A.driver
    A.driver:GetScript("OnEvent")()
    check(A.initialized and A.db and A.window, "addon loads through client events")
    local driver = A.driver
    local database = A.db
    event = "VARIABLES_LOADED"
    arg1 = nil
    this = driver
    driver:GetScript("OnEvent")()
    check(A.driver == driver and A.db == database, "duplicate load event cannot rebuild database")
end
local function packet(prefix, payload)
    NOW = NOW + 1
    event = "CHAT_MSG_ADDON"
    arg1 = prefix
    arg2 = payload
    if math.mod(RELEASE_INDEX, 2) == 0 then
        this = A.driver
        A.driver:GetScript("OnEvent")()
        AZS_ApiOnEvent()
    else
        AZS_ApiOnEvent()
        this = A.driver
        A.driver:GetScript("OnEvent")()
    end
    A.Sample()
end
local function progress(t, dealt, kills, phase)
    packet(
        "AZSRUN",
        "ph="
            .. (phase or "playing")
            .. ";t="
            .. t
            .. ";dealt="
            .. dealt
            .. ";kills="
            .. kills
            .. ";taken=4;gold=55;lvl=4;chest=45"
    )
end
local function summary(result, t, damage)
    packet(
        "AZSEND",
        "result="
            .. result
            .. ";t="
            .. t
            .. ";dmg="
            .. damage
            .. ";kills=15;taken=4;gold=55;lvl=4;bosses=1;elites=2;guardians=1;chests=2;magnets=1;hero=Player;class="
            .. cls
            .. ";zone=feralas"
    )
end
local function refreshAll()
    for tab = 1, table.getn(A.tabs) do
        A.view.tab = tab
        if tab == 3 then
            A.view.historySection = "History"
        end
        A.ToggleUI(true)
        A.RefreshUI()
        check(A.ui.model.title == A.T(A.tabs[tab]), "class page " .. tab)
    end
end
local keys = {}
for key, class in pairs(A.abilityClasses) do
    if class == cls then
        table.insert(keys, key)
    end
end
table.sort(keys)
local spell = assert(keys[1], "missing class spell fixture")
bootstrap()
if RELEASE_STAGE == 1 then
    check(
        A.db.totals.runs == nil and table.getn(A.db.runs) == 0,
        "clean install has no fabricated runs"
    )
    packet("AZSZONE", "zone=feralas;class=" .. cls .. ";heroic=" .. heroic)
    packet("AZSRUN", "ph=ready;t=0")
    check(table.getn(A.db.runs) == 0, "ready does not count as a game")
    progress(0, 100, 1)
    check(
        A.run.recordBaseline ~= nil,
        "new run freezes record baseline before its ledger contributes"
    )
    check(A.run.heroic == heroic, "new packet preserves exact difficulty")
    equipped()
    packet("AZSSPELLS", spell .. ",53,1,0,3")
    packet("AZSMETER", "Fixture attack,100,10,100,0")
    packet("AZSHEAL", "Fixture heal,10,1,100,0")
    packet("AZSTAKEN", "mob melee,4")
    progress(16, 200, 8)
    packet("AZSSPELLS", spell .. ",53,3,0,3")
    packet("AZSMETER", "Fixture attack,200,12,100,0")
    check(A.db.totals.runs == 1 and A.db.classes[cls].runs == 1, "one observed game per class")
    check(
        A.run.buildJournal and table.getn(A.run.buildJournal.entries) > 0,
        "native parser rank changes enter the sampled build journal"
    )
    check(A.run.values.chests == nil, "chest price never becomes an opening count")
    check(A.db.totals.usage.spells[spell].gains == 2, "observed rank growth")
    check(A.db.totals.usage.jewelry["jewel.chosen"].runs == 1, "jewelry present in one game")
    check(A.run.equipmentTooltips[1][2].text == "+21 Health", "equipment description captured")
    A.db.settings.scale = 0.85
    A.db.settings.opacity = 0.9
    A.db.settings.textSize = 14
    A.db.settings.hud = A.NormalizeBar({
        version = 1,
        width = 610,
        height = 72,
        icons = false,
        labels = true,
        locked = true,
        blocks = {
            { metric = "duration", scope = "all" },
            { metric = "kills", scope = "class", class = cls },
        },
    })
    A.SetLanguage("fr")
    A.view.tab = 5
    A.view.difficulty = heroic
    A.view.characterTab = "Equipment"
    A.ApplyUI()
    A.RefreshUI()
    this = A.driver
    event = "PLAYER_LOGOUT"
    arg1 = nil
    A.driver:GetScript("OnEvent")()
    check(A.db.totals.sum.damage == 200, "normal logout accounts last sample without duplication")
elseif RELEASE_STAGE == 2 then
    check(
        A.db.runs[1].heroic == heroic and A.view.difficulty == heroic,
        "difficulty and history filter survive a fresh VM"
    )
    check(
        A.db.settings.hud.width == 610 and not A.db.settings.hud.icons and A.db.settings.hud.locked,
        "HUD size and explicit false/lock preferences survive a fresh VM"
    )
    check(
        A.db.settings.hud.blocks[2].scope == "class" and A.db.settings.hud.blocks[2].class == cls,
        "fixed-class block scope survives a fresh VM"
    )
    check(
        A.view.tab == 5 and A.view.characterTab == "Equipment" and A.Locale() == "fr",
        "view and language survive a fresh VM"
    )
    check(
        A.db.settings.scale == 0.85
            and A.db.settings.opacity == 0.9
            and A.db.settings.textSize == 14,
        "appearance persists across a fresh VM"
    )
    check(
        A.db.runs[1].buildJournal and A.ValidateJournal(A.db.runs[1].buildJournal),
        "journal and last-state baselines survive a fresh VM"
    )
    equipped()
    packet("AZSZONE", "zone=feralas;class=" .. cls .. ";heroic=" .. heroic)
    progress(16, 200, 8)
    local run = A.run
    packet("AZSSPELLS", spell .. ",53,3,0,3")
    packet("AZSMETER", "Fixture attack,200,12,100,0")
    packet("AZSHEAL", "Fixture heal,10,1,100,0")
    check(
        A.db.totals.runs == 1 and run.resumeHeuristic,
        "mid-game reload resumes same record, explicitly heuristic"
    )
    check(
        A.db.totals.sum.damage == 200 and A.db.totals.spells.damage["Fixture attack"] == 200,
        "restored combat ledgers do not double count"
    )
    check(
        A.db.totals.usage.spells[spell].runs == 1 and A.db.totals.usage.spells[spell].gains == 2,
        "restored build ledger does not double count"
    )
    check(
        A.db.totals.usage.jewelry["jewel.chosen"].runs == 1,
        "restored jewelry frequency does not double count"
    )
    progress(16, 200, 8, "choosing")
    check(A.run == run, "choice preserves identity")
    progress(16, 200, 8, "paused")
    check(A.run == run, "pause preserves identity")
    progress(
        17,
        300,
        15,
        RELEASE_RESULT == "victory" and "victory"
            or (RELEASE_RESULT == "defeat" and "dead" or "playing")
    )
    summary(RELEASE_RESULT, 17, 300)
    check(
        run.result == RELEASE_RESULT and run.values.chests == 2 and A.db.totals.sum.chests == 2,
        "official end and chests"
    )
    check(
        run.values.bosses == 1 and run.values.elites == 2 and run.values.guardians == 1,
        "official final counters"
    )
    summary(RELEASE_RESULT, 17, 300)
    for i = 1, 30 do
        A.Sample()
    end
    check(
        A.db.totals.runs == 1 and A.db.totals.sum.damage == 300,
        "duplicate end and polling stay idempotent"
    )
    if RELEASE_RESULT == "victory" then
        progress(18, 350, 16)
        check(
            A.run == run and run.continued and run.official.result == "victory",
            "victory continuation keeps first official result"
        )
        summary("left", 25, 400)
        check(
            A.db.totals.wins == 1 and A.db.totals.runs == 1 and A.db.totals.sum.damage == 400,
            "continuation finalizes without a second game or victory"
        )
    else
        check((A.db.totals.wins or 0) == 0, "defeat and abandonment never invent victory")
    end
    refreshAll()
    A.view.tab = 5
    A.view.characterTab = "Equipment"
    A.RefreshUI()
elseif RELEASE_STAGE == 3 then
    check(
        A.db.settings.hud.width == 610
            and A.db.settings.hud.height == 72
            and table.getn(A.db.settings.hud.blocks) == 2,
        "HUD configuration survives terminal save and second restart"
    )
    check(
        A.db.totals.runs == 1 and table.getn(A.db.runs) == 1,
        "final save restores exactly one game"
    )
    check(
        A.db.totals.sum.damage == (RELEASE_RESULT == "victory" and 400 or 300),
        "final damage survives restoration"
    )
    check(
        A.db.classes[cls].runs == 1 and A.db.totals.sum.chests == 2,
        "class and final chest totals persist"
    )
    check(
        A.db.totals.usage.spells[spell].runs == 1
            and A.db.totals.usage.jewelry["jewel.chosen"].runs == 1,
        "final popularity persists"
    )
    check(
        A.db.runs[1].equipmentTooltips[1][2].text == "+21 Health",
        "historical descriptions survive a fresh VM"
    )
    check(
        A.db.runs[1].recordBaseline and A.db.runs[1].reportNotified,
        "record baseline and summary notice deduplication survive fresh processes"
    )
    check(
        A.pendingReport == nil,
        "restoring a completed game does not replay its transient report notice"
    )
    check(A.db.runs[1].heroic == heroic, "historical difficulty survives final restoration")
    packet("AZSZONE", "zone=feralas;class=" .. cls .. ";heroic=" .. heroic)
    packet("AZSRUN", "ph=ready;t=0")
    check(
        A.run == nil and A.db.totals.runs == 1,
        "fresh ready screen does not create a phantom game"
    )
    refreshAll()
else
    error("unknown acceptance stage")
end
RELEASE_CHECKS = checks
print("RELEASE_CASE_OK", cls, RELEASE_RESULT, RELEASE_STAGE, checks)

local A = AzerothStats
local checks = 0
local function check(ok, msg)
    assert(ok, msg)
    checks = checks + 1
end
this = A.driver
event = "ADDON_LOADED"
arg1 = "AzerothStats"
A.driver:GetScript("OnEvent")()
check(A.db and table.getn(A.db.runs) == 0, "clean event-driven initialization")
this = A.driver
event = "VARIABLES_LOADED"
arg1 = nil
A.driver:GetScript("OnEvent")()
check(table.getn(A.db.runs) == 0, "duplicate load does not create games")
local r = {
    id = "ci-1",
    class = "rogue",
    hero = "Fixture",
    zone = "feralas",
    startedAt = 1,
    status = "ended",
    result = "defeat",
    values = { duration = 10, damage = 100, kills = 5, chests = 2 },
    accounted = {},
    events = {},
    timeline = {},
    meters = {
        damage = { rows = { { name = "Melee", dmg = 100, dps = 10 } }, total = 100, rate = 10 },
    },
}
table.insert(A.db.runs, r)
A.Account(r)
A.Account(r)
check(A.db.totals.runs == 1 and A.db.totals.sum.damage == 100, "idempotent metric ledger")
check(
    A.db.classes.rogue.sum.chests == 2 and A.db.totals.spells.damage.Melee == 100,
    "class and spell ledgers"
)
AZS_SPELLS = { { key = "backstab", rank = 1, spell = 53 } }
A.ObserveBuild(r)
AZS_SPELLS[1].rank = 3
A.ObserveBuild(r)
A.ObserveBuild(r)
check(
    A.db.totals.usage.spells.backstab.runs == 1 and A.db.totals.usage.spells.backstab.gains == 2,
    "observed rank ledger"
)
A.run = r
r.status = "active"
A.BeginInsights(r)
A.ObserveInsights(r, { t = 10, dealt = 300 }, "playing")
A.Account(r)
check(
    r.values.peakDps == 30 and A.db.totals.sum.peakDps == nil,
    "DPS peak is not an additive total"
)
AZS_PARTY = { { name = "Peer", class = "mage", dmg = 20, dps = 2 } }
AZS_PARTY_UPDATED = NOW
A.partyGeneration = 1
A.ObserveInsights(r, { t = 10, dealt = 300 }, "playing")
A.Account(r)
A.Account(r)
check(A.db.totals.companions["Peer:mage"].runs == 1, "offline co-op ledger")
AZS_PARTY = {
    { name = "Fixture", class = "rogue", dmg = 300, dps = 30, top = "Backstab", topdps = 20 },
    { name = "Peer", class = "mage", dmg = 100, dps = 10, top = "Fireball", topdps = 8 },
}
A.partyGeneration = 2
A.ObserveInsights(r, { t = 10, dealt = 300 }, "playing")
local comp = A.CoopComparison(r)
check(
    comp.total == 400 and comp.rate == 40 and comp.ranked and comp.rows[1].isSelf,
    "same-packet co-op comparison includes own player"
)
check(
    comp.rows[2].fraction == 0.25 and comp.rows[2].topdps == 8,
    "comparable shares and native top spell DPS"
)
AZS_PARTY = {}
A.partyGeneration = 3
A.ObserveInsights(r, {}, "playing")
check(A.CoopComparison(r).total == 400, "empty party packet retains comparison")
local legacy = {
    hero = "Fixture",
    class = "rogue",
    status = "ended",
    summary = { dmg = 300, t = 10 },
    coop = { peers = { peer = { name = "Peer", class = "mage", damage = 100, dps = 10 } } },
}
local old = A.CoopComparison(legacy)
check(
    table.getn(old.rows) == 2 and not old.ranked and not old.total and not old.rows[1].fraction,
    "legacy samples stay explicitly incomparable"
)
A.view.tab = 9
A.view.usageTab = "Co-op"
A.view.cumulative = false
A.view.selected = r.id
A.ToggleUI(true)
A.RefreshUI()
check(
    table.getn(A.ui.model.cards) == 3 and table.getn(A.ui.model.rows) == 2,
    "party comparison card and row model"
)
A.SelectCoopRun(r.id)
check(A.view.selected == r.id and not A.view.cumulative, "historical party selection")
r.status = "ended"
for _, lg in ipairs(A.languages) do
    if lg[1] ~= "auto" then
        for key in pairs(A.uiText.en) do
            check(
                type(A.uiText[lg[1]][key]) == "string" and A.uiText[lg[1]][key] ~= "",
                "translation " .. lg[1] .. " " .. key
            )
        end
        A.SetLanguage(lg[1])
        for tab = 1, table.getn(A.tabs) do
            A.view.tab = tab
            A.view.selected = r.id
            A.ToggleUI(true)
            A.RefreshUI()
            check(A.ui.model.title == A.T(A.tabs[tab]), "page title " .. lg[1] .. tab)
        end
        local language = A.gameText[lg[1]]
        local link = "[" .. language["amulet.south_seas_kelp"] .. " IV]"
        check(
            A.JewelKey(link, "rogue") == "amulet.south_seas_kelp",
            "accessory normalization " .. lg[1]
        )
    end
end
A.view.tab = 4
A.view.mode = "boss"
A.view.combatTab = "Spells"
A.view.cumulative = true
A.RefreshUI()
check(
    A.ui.model.emptyText == A.T("Select a run for its last boss fight"),
    "honest last-boss limitation"
)
A.view.tab = 8
A.RefreshUI()
local slider = A.ui.sliders[2]
local old = A.window:GetScale()
this = slider
slider:GetScript("OnMouseDown")()
slider:SetValue(0.85)
slider:GetScript("OnValueChanged")()
A.RefreshUI()
check(A.window:GetScale() == old, "scale stays stable during dragging")
this = slider
slider:GetScript("OnMouseUp")()
check(A.window:GetScale() == 0.85, "scale commits on release")
local source = SNAPSHOT(AzerothStatsDB)
local signature = A.Sign(AzerothStatsDB.totals)
AzerothStatsDB = nil
assert(loadstring("AzerothStatsDB=" .. source))()
A.db = nil
A.InitDB()
check(A.Sign(A.db.totals) == signature, "offline serialization roundtrip")
CI_CHECKS = checks
print("OFFLINE MODEL/UI CHECKS PASSED", checks)

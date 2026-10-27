local A = AzerothStats
local function check(ok, text)
    assert(ok, text)
    TEST_COUNT = TEST_COUNT + 1
end
local saved, oldrun = AzerothStatsDB, A.run
AzerothStatsDB = nil
A.db = nil
A.InitDB()
A.run = nil
local function run(n)
    return {
        id = "fav-" .. n,
        class = "rogue",
        hero = "Fixture",
        startedAt = n,
        status = "ended",
        values = { duration = n },
        accounted = {},
        events = {},
        meters = {},
    }
end
for i = 1, 14 do
    table.insert(A.db.runs, run(i))
end
A.db.settings.maxRuns = 10
local pinned = A.db.runs[1]
local d = A.RunFavorite(pinned)
check(A.ToggleFavorite(d) and A.IsFavorite("run", pinned.id), "favorite added with stable run ID")
A.Trim()
check(
    A.db.runs[1] == pinned and table.getn(A.db.runs) == 11 and A.db.pruned == 3,
    "favorite run survives pruning in addition to ordinary retention"
)
A.ToggleFavorite(d)
A.Trim()
check(
    not A.IsFavorite("run", pinned.id)
        and table.getn(A.db.runs) == 10
        and A.db.runs[1].id == "fav-5",
    "unfavorite permits normal pruning"
)
local photoRun = A.db.runs[table.getn(A.db.runs)]
photoRun.zone = "arena"
A.ToggleFavorite(A.RunFavorite(photoRun))
A.view.tab, A.view.favoriteCategory, A.view.class = 10, "run", nil
A.ToggleUI(true)
A.RefreshUI()
check(
    A.ui.model.photoRows and A.ui.model.rows[1].zone == "arena",
    "favorite history uses its recorded zone photo"
)
check(
    A.ui.model.rows[1].label == A.ZoneName(photoRun),
    "favorite run primary label matches history zone"
)
local widgetCount = table.getn(objects)
A.RefreshUI()
check(table.getn(objects) == widgetCount, "shared page redraw reuses existing widgets")
A.ToggleFavorite(A.RunFavorite(photoRun))
A.ToggleFavorite({
    kind = "spell",
    key = "backstab",
    label = "Backstab",
    tab = 9,
    section = "Spells",
})
A.ToggleFavorite({
    kind = "jewelry",
    key = "amulet.test",
    label = "Amulet",
    tab = 9,
    section = "Jewelry",
    display = { link = "item:123", tooltip = { { text = "Recorded bonus" } } },
})
A.view.tab = 10
A.view.favoriteCategory = "jewelry"
A.view.class = nil
A.ToggleUI(true)
A.RefreshUI()
check(
    table.getn(A.ui.model.rows) == 1 and A.ui.model.rows[1].favorite,
    "favorites page exposes stored entries"
)
A.ui.model.rows[1].action()
check(A.view.tab == 9, "favorite opens source view")
local detail = A.db.favorites.entries["jewelry:amulet.test"]
check(
    detail.display.tooltip[1].text == "Recorded bonus",
    "favorite retains bounded item description"
)
A.db.totals.usage = { spells = {} }
for i = 1, 20 do
    A.db.totals.usage.spells["fixture" .. i] = { runs = i, gains = 0, maxRank = 1 }
end
A.view.tab = 9
A.view.usageTab = "Spells"
A.view.cumulative = true
A.view.class = nil
A.RefreshUI()
local target = A.ui.model.rows[15].favorite
A.OpenFavorite(target)
A.RefreshUI()
check(
    A.view.page > 1 and A.ui.model.rows[15].focused,
    "bookmark opens and highlights its actual result page"
)
local legacy = {
    kind = "spell",
    key = "taken:mob spell",
    label = "Creature spells",
    tab = 4,
    mode = "taken",
    class = "rogue",
}
A.ToggleFavorite(legacy)
local original = A.Sign(A.db.favorites.entries)
A.view.tab = 10
A.view.class = nil
A.view.favoriteCategory = "combat"
A.RefreshUI()
check(
    table.getn(A.ui.model.rows) == 1 and A.ui.model.rows[1].favorite.key == legacy.key,
    "legacy combat bookmark appears only in Combat category"
)
check(
    A.Sign(A.db.favorites.entries) == original,
    "categorizing existing bookmarks does not rewrite their IDs or metadata"
)
check(
    A.FavoriteCounts().combat == 1
        and A.FavoriteCounts().jewelry == 1
        and A.FavoriteCounts().spell == 1,
    "category counts separate combat, items and spells"
)
check(
    string.find(A.uiRows[1].favorite.heart.texture, "FavoriteHeartFilled.tga", 1, true),
    "saved bookmark uses filled heart texture"
)
A.view.favoriteCategory = "item"
A.RefreshUI()
check(
    A.ui.model.empty
        and table.getn(A.ui.model.rows) == 0
        and A.ui.model.emptyText
            == A.T("No favorites in this category") .. "\n" .. A.T(
                "Use the heart to save a favorite"
            ),
    "empty category never leaks other favorites"
)
A.view.class = "mage"
A.view.favoriteCategory = "combat"
A.RefreshUI()
check(table.getn(A.ui.model.rows) == 0, "category and class filters intersect")
A.view.class = nil
A.ToggleFavorite(legacy)
for _, button in ipairs(A.ui.favoriteCategories) do
    button.callback(button)
    check(
        A.view.favoriteCategory == button.category and A.view.page == 1,
        "category button selects its own category and resets paging"
    )
    for _, item in ipairs(A.ui.model.rows) do
        check(
            A.FavoriteCategory(item.favorite) == button.category,
            "category buttons never display mixed kinds"
        )
    end
end
check(
    A.db.settings.view.favoriteCategory == A.view.favoriteCategory,
    "selected category is persisted with view preferences"
)
local ref = A.db.runs[1]
local combat = {
    kind = "spell",
    key = ref.id .. ":damage:Backstab",
    label = "Backstab",
    tab = 4,
    mode = "damage",
    runId = ref.id,
    cumulative = false,
    class = ref.class,
}
A.ToggleFavorite(combat)
check(A.IsRunProtected(ref.id), "historical combat bookmark protects its underlying run")
A.OpenFavorite(combat)
A.RefreshUI()
check(
    A.view.selected == ref.id and not A.view.cumulative and A.view.tab == 4,
    "historical combat reopens the actual bookmarked run rather than all-time totals"
)
A.ToggleFavorite(combat)
check(not A.IsRunProtected(ref.id), "removing last combat reference releases retention protection")
A.view.tab = 3
A.RefreshUI()
check(
    string.find(A.uiRows[1].favorite.heart.texture, "FavoriteHeartEmpty.tga", 1, true),
    "unmarked row uses outlined heart"
)
local signature = A.Sign(A.db.favorites)
local serialized = SNAPSHOT(A.db)
AzerothStatsDB = nil
assert(loadstring("AzerothStatsDB=" .. serialized))()
A.db = nil
A.InitDB()
check(A.Sign(A.db.favorites) == signature, "favorites persist through serialization")
local count = 0
for i = 1, 350 do
    A.ToggleFavorite({ kind = "spell", key = "bounded-" .. i, label = "Fixture", tab = 9 })
end
for _ in pairs(A.db.favorites.entries) do
    count = count + 1
end
check(count == 300, "favorite storage has a hard bound")
A.db.favorites.entries = {}
A.view.tab = 3
A.RefreshUI()
check(A.ui.model.rows[1].favorite.kind == "run", "history exposes a real run bookmark control")
local r = run(99)
r.status = "active"
A.run = r
table.insert(A.db.runs, r)
A.db.classes.rogue = {}
A.BeginDeathWatch(r)
A.ObserveNemesis(r, { hp = 0 }, "dead")
check(not r.deaths, "dead screen on startup does not fabricate a death")
A.ObserveNemesis(r, { hp = 100 }, "playing")
A.DeathEvidence("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Plains Creeper hits you for 7.")
NOW = NOW + 0.1
A.ObserveNemesis(r, { hp = 0 }, "dead")
check(
    r.deaths and r.deaths[1].source == "Plains Creeper" and r.deaths[1].confidence == "probable",
    "last attacker correlated with death is labeled probable"
)
check(r.deaths[1].hits[1].amount == 7, "hit damage is not appended to attacker name")
A.MarkDeath()
A.ObserveNemesis(r, {}, "dead")
check(
    table.getn(r.deaths) == 1 and A.db.totals.deathEvidence.deaths == 1,
    "event plus repeated dead packets count only one death"
)
local oldFormat = ERR_KILLED_BY_S
ERR_KILLED_BY_S = "%s has slain you."
A.DeathEvidence("UI_ERROR_MESSAGE", "Another Enemy has slain you.")
check(
    r.deaths[1].source == "Another Enemy" and r.deaths[1].confidence == "confirmed",
    "explicit native message upgrades death evidence"
)
check(
    A.db.totals.deathEvidence.sources["Plains Creeper"].probable == 0
        and A.db.totals.deathEvidence.sources["Another Enemy"].confirmed == 1,
    "upgrade replaces aggregate evidence rather than duplicating death"
)
NOW = NOW + 3
A.ObserveNemesis(r, { hp = 100 }, "playing")
A.DeathEvidence("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "Mage's Fireball crits you for 12.")
NOW = NOW + 3
A.MarkDeath()
check(
    r.deaths[2].confidence == "unknown" and not r.deaths[2].source,
    "stale last hit never becomes a killer"
)
NOW = NOW + 3
A.ObserveNemesis(r, { hp = 100 }, "playing")
A.DeathEvidence(
    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
    "You suffer 5 Shadow damage from Warlock's Curse."
)
A.MarkDeath()
check(
    r.deaths[3].source == "Warlock",
    "periodic damage template identifies actor rather than spell or amount"
)
NOW = NOW + 3
A.ObserveNemesis(r, { hp = 100 }, "playing")
local oldHit = COMBATHITOTHERSELF
COMBATHITOTHERSELF = "%1$s vous frappe pour %2$d."
A.DeathEvidence("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Ennemi vous frappe pour 42.")
A.MarkDeath()
check(r.deaths[4].source == "Ennemi", "native localized positional template is supported")
COMBATHITOTHERSELF = oldHit
NOW = NOW + 3
A.ObserveNemesis(r, { hp = 100 }, "playing")
A.DeathEvidence("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "Unparsed localized message")
A.MarkDeath()
check(
    r.deaths[5].confidence == "unknown" and r.deaths[5].unparsed[1] == "Unparsed localized message",
    "unknown text kept as evidence without inventing source"
)
local n = table.getn(r.deaths)
A.BeginDeathWatch(r)
A.ObserveNemesis(r, {}, "dead")
check(table.getn(r.deaths) == n, "reload at dead screen never repeats persisted deaths")
A.view.tab = 11
A.view.class = nil
A.RefreshUI()
check(
    A.ui.model.subtitle and table.getn(A.ui.model.rows) >= 4,
    "Nemesis page shows evidence counts and retained death history"
)
local deathSignature = A.Sign(A.db.totals.deathEvidence)
local persisted = SNAPSHOT(A.db)
AzerothStatsDB = nil
assert(loadstring("AzerothStatsDB=" .. persisted))()
A.db = nil
A.InitDB()
A.run = A.db.runs[table.getn(A.db.runs)]
A.BeginDeathWatch(A.run)
A.ObserveNemesis(A.run, {}, "dead")
check(
    A.Sign(A.db.totals.deathEvidence) == deathSignature and table.getn(A.run.deaths) == n,
    "death reports and evidence counters survive real serialization without a duplicate"
)
ERR_KILLED_BY_S = oldFormat
AzerothStatsDB = saved
A.db = saved
A.run = oldrun
A.deathWatch = nil
A.view.tab = 1
print("FAVORITES AND DEATH EVIDENCE PASSED", TEST_COUNT)

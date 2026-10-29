-- Isolated editing regressions. Never read or erase a player's own database.
local A = AzerothStats
local saved = {
    db = A.db,
    run = A.run,
    view = A.view,
    phase = AZS_GetPhase,
    native = AZS_RUN,
    spells = AZS_SPELLS,
    edit = A.editMode,
    pending = A.pendingEntryPlan,
    data = A.pendingDataPlan,
    death = A.deathWatch,
    report = A.pendingReport,
}
local function check(ok, why)
    assert(ok, why)
    TEST_COUNT = TEST_COUNT + 1
end
AzerothStatsDB, A.db, A.run = nil, nil, nil
AZS_RUN = { ph = "ready" }
AZS_GetPhase = function()
    return AZS_RUN.ph
end
A.view = { tab = 6, page = 1, mode = "damage", characterTab = "Spells" }
check(A.InitDB(), "editing fixture initializes")
A.SetLanguage("en")
local function run(id, class, damage, duration)
    local r = {
        id = id,
        hero = "Fixture",
        class = class,
        zone = "feralas",
        status = "ended",
        result = "victory",
        startedAt = 10,
        values = { damage = damage, duration = duration, gold = 20 },
        accounted = {},
        meters = {},
        events = {},
        reportRecords = { duration = duration, gold = 20 },
        recordBaseline = { values = {} },
        reportNotified = true,
        spells = { { key = "test", spell = 1, rank = 1 } },
        equipment = {},
    }
    table.insert(A.db.runs, r)
    A.Account(r)
    return r
end
local first, second = run("edit-a", "warrior", 1000, 100), run("edit-b", "mage", 500, 200)
A.view.selected = first.id
local sums = A.Sign(A.db.totals.sum)
local values = A.Sign(first.values)
local model = A.PageModel()
local featured
for _, item in ipairs(model.cards) do
    if item.metric == "duration" then
        featured = item
    end
end
check(
    featured and featured.entryAction.key == "duration",
    "featured survival card has an exact metric action"
)
local records = A.Sign(A.db.totals.records)
check(A.ToggleHiddenRow(featured), "hiding a featured card stores only presentation metadata")
A.editMode = false
model = A.PageModel()
check(
    table.getn(model.cards) == 2 and A.Sign(A.db.totals.records) == records,
    "hidden card leaves record ledgers unchanged"
)
A.editMode = true
model = A.PageModel()
check(
    table.getn(model.cards) == 3 and model.cards[1].hidden,
    "edit mode reveals hidden cards for reversible restoration"
)
A.RestorePageRows(model.editContext)
A.RefreshUI()
check(
    A.ui.cards[1].edit:IsShown() and A.ui.editToggle:IsShown(),
    "card and page edit controls render"
)
A.ui.cards[1].edit.callback(A.ui.cards[1].edit)
check(table.getn(A.ui.menu.items) >= 2, "card menu offers visibility and a separate data action")
A.ui.menu:Hide()
A.OpenEntryReview(featured.entryAction)
A.SetLanguage("fr")
A.RefreshEntryReview()
check(
    string.find(A.ui.entryDialog.subject.fullText, A.Metric("duration"), 1, true),
    "record confirmation resolves its metric in the current language"
)
A.SetLanguage("en")
A.ui.entryDialog.cancel.callback()
check(
    A.Sign(A.db.totals.records) == records and not A.pendingEntryPlan,
    "entry cancel never resets a record"
)
A.OpenEntryReview(featured.entryAction)
check(
    A.pendingEntryPlan.allowed and A.ui.entryDialog:IsShown(),
    "one-key review names a valid operation"
)
A.ui.entryDialog.confirm.callback()
check(
    not A.db.totals.records.duration
        and not A.db.classes.warrior.records.duration
        and not A.db.classes.mage.records.duration
        and A.db.totals.records.gold,
    "resetting survival clears just that metric globally and per class"
)
check(
    first.values.duration == 100
        and second.values.duration == 200
        and not first.reportRecords.duration
        and first.reportRecords.gold,
    "record reset retains numeric history and unrelated milestones"
)
A.Account(first)
A.FinishReport(first)
check(
    not A.db.totals.records.duration and not first.reportRecords.duration,
    "old packets and summary recomputation cannot resurrect one reset record"
)
A.pendingEntryPlan = A.EntryPlan({ kind = "record", key = "gold", label = "Gold" })
A.db.totals.records.gold.value = 99
check(
    not A.ConfirmEntryAction() and A.db.totals.records.gold.value == 99,
    "changed record requires a fresh review"
)
check(
    A.ConfirmEntryAction() and not A.db.totals.records.gold and A.db.totals.records.damage,
    "reconfirmed gold reset preserves damage record"
)
-- Generic combat rows are presentation-only: hiding cannot change damage/share ledgers.
first.meters.damage =
    { total = 1000, rate = 10, rows = { { name = "Test Source", dmg = 1000, dps = 10 } } }
A.view.tab, A.view.cumulative, A.view.selected = 4, false, first.id
A.editMode = true
A.RefreshUI()
local combat = A.ui.rows[1].item
check(
    combat and not combat.entryAction and A.ui.rows[1].edit:IsShown(),
    "combat rows expose visibility rather than a misleading numeric reset"
)
local combatState = A.Sign(first.meters)
A.ToggleHiddenRow(combat)
A.editMode = false
check(
    table.getn(A.PageModel().rows) == 0 and A.Sign(first.meters) == combatState,
    "hiding a combat source retains original meter totals and source data"
)
A.editMode = true
A.RefreshUI()
check(
    A.ui.rows[1].item.hidden and not A.ui.rows[1].favorite:IsShown(),
    "editing a hidden source offers restoration without overlapping favorites"
)
A.RestorePageRows(A.ui.model.editContext)
check(table.getn(A.PageModel().rows) == 1, "restore reveals the original source again")
A.editMode = false
A.view.tab = 6
A.RefreshUI()
check(
    A.ui.cards[1].icon:IsShown() and not A.ui.cards[1].edit:IsShown(),
    "leaving edit mode restores normal card icons"
)
local function usage(key)
    first.usage = first.usage or { spells = {}, jewelry = {} }
    local entry = { name = key, maxRank = 2, gains = 1, changes = 0 }
    first.usage.spells[key] = entry
    A.AccountUsage(first, "spells", key, entry)
end
usage("a")
usage("b")
A.pendingEntryPlan = A.EntryPlan({ kind = "trend", section = "spells", key = "a", label = "A" })
check(
    A.ConfirmEntryAction()
        and not A.db.totals.usage.spells.a
        and A.db.totals.usage.spells.b
        and not first.usage.spells.a,
    "one spell trend can be reset without clearing other spells"
)
A.AccountUsage(first, "spells", "a", { maxRank = 3, gains = 2 })
AZS_SPELLS = { { key = "a", rank = 3, spell = 1 }, { key = "b", rank = 2, spell = 2 } }
A.ObserveBuild(first)
check(not first.usage.spells.a, "resumed native build observation skips the cleared spell key")
check(
    not A.db.totals.usage.spells.a and first.spells[1].key == "test",
    "old usage callbacks cannot restore a cleared key; build snapshots remain"
)
first.coop = {
    peers = { one = { name = "One", class = "mage" }, two = { name = "Two", class = "rogue" } },
    latest = {},
    accounted = {},
}
A.AccountInsights(first)
A.pendingEntryPlan =
    A.EntryPlan({ kind = "trend", section = "companions", key = "one", label = "One" })
check(
    A.ConfirmEntryAction()
        and not A.db.totals.companions.one
        and A.db.totals.companions.two
        and first.coop.peers.one,
    "companion frequency reset keeps other peers and historical comparisons"
)
A.AccountInsights(first)
check(not A.db.totals.companions.one, "old companion ledger cannot recreate cleared frequency")
A.db.totals.deathEvidence = {
    deaths = 4,
    sources = { Kobold = { confirmed = 1, probable = 1 }, Wolf = { confirmed = 0, probable = 1 } },
}
A.db.classes.warrior.deathEvidence = {
    deaths = 3,
    sources = { Kobold = { confirmed = 1, probable = 0 }, Wolf = { confirmed = 0, probable = 1 } },
}
A.db.classes.mage.deathEvidence =
    { deaths = 1, sources = { Kobold = { confirmed = 0, probable = 1 } } }
first.deaths = {
    { source = "Kobold", confidence = "confirmed", at = 10, t = 10, hits = {} },
    { source = "Wolf", confidence = "probable", at = 11, t = 11, hits = {} },
    { confidence = "unknown", at = 12, t = 12, hits = {} },
}
second.deaths = { { source = "Kobold", confidence = "probable", at = 12, t = 12, hits = {} } }
A.pendingEntryPlan = A.EntryPlan({ kind = "nemesis", key = "Kobold", label = "Kobold" })
check(
    A.ConfirmEntryAction()
        and A.db.totals.deathEvidence.deaths == 2
        and A.db.classes.warrior.deathEvidence.deaths == 2
        and not A.db.totals.deathEvidence.sources.Kobold
        and A.db.totals.deathEvidence.sources.Wolf,
    "source reset removes its exact evidence counts, retaining unknown and other deaths"
)
check(
    table.getn(first.deaths) == 2 and table.getn(second.deaths) == 0,
    "only the selected nemesis disappears from retained death logs"
)
A.run = first
A.deathWatch = {
    run = first,
    armed = true,
    closed = false,
    hits = {},
    explicit = { source = "Kobold", at = GetTime(), raw = "Synthetic" },
}
local evidenceBefore = A.Sign(A.db.totals.deathEvidence)
A.MarkDeath()
check(
    A.Sign(A.db.totals.deathEvidence) == evidenceBefore,
    "old life observer cannot restore the erased nemesis"
)
A.run = nil
local oldMask = first.nemesisResets
first.nemesisResets = {}
for i = 1, 512 do
    first.nemesisResets["old-source-" .. i] = true
end
check(
    not A.EntryPlan({ kind = "nemesis", key = "Wolf", label = "Wolf" }).allowed,
    "mask capacity blocks mutation before a saved-data limit can be exceeded"
)
first.nemesisResets = oldMask
check(
    A.Sign(first.values) == values and A.Sign(A.db.totals.sum) == sums,
    "targeted resets never change run results or lifetime sums"
)
AZS_RUN.ph = "playing"
A.pendingEntryPlan = A.EntryPlan({ kind = "record", key = "damage", label = "Damage" })
check(
    not A.ConfirmEntryAction() and A.db.totals.records.damage,
    "targeted resets fail closed during play"
)
AZS_RUN.ph = "ready"
A.ToggleFavorite(A.RunFavorite(second))
A.pendingEntryPlan = A.EntryPlan({ kind = "run", key = second.id, label = "Protected run" })
check(
    not A.ConfirmEntryAction() and A.FindRun(second.id),
    "single-row run deletion respects favorite protection"
)
A.pendingEntryPlan =
    A.EntryPlan({ kind = "bookmark", key = A.FavoriteId("run", second.id), label = "Bookmark" })
check(A.ConfirmEntryAction() and A.FindRun(second.id), "removing a bookmark keeps its source run")
A.pendingEntryPlan = A.EntryPlan({ kind = "run", key = second.id, label = "History" })
check(
    A.ConfirmEntryAction() and not A.FindRun(second.id) and A.Sign(A.db.totals.sum) == sums,
    "single-row history deletion keeps cumulative totals"
)
local restored = assert(loadstring("return " .. SNAPSHOT(A.db)))()
check(
    A.ValidateDatabase(restored)
        and restored.runs[1].recordResets.duration
        and restored.runs[1].trendResets.spells.a
        and restored.runs[1].nemesisResets.Kobold,
    "per-entry reset barriers survive persistence and validation"
)
AzerothStatsDB, A.db = restored, nil
check(A.InitDB(), "targeted reset database reloads normally")
A.Account(A.db.runs[1])
check(
    not A.db.totals.records.duration and not A.db.totals.usage.spells.a,
    "normal reload cannot restore reset entries"
)
local fresh = run("edit-new", "warrior", 2000, 50)
fresh.usage = { spells = {}, jewelry = {} }
A.AccountUsage(fresh, "spells", "a", { maxRank = 1, gains = 0 })
check(
    A.db.totals.records.duration and A.db.totals.usage.spells.a,
    "new runs collect the cleared record and trend again"
)
check(
    not A.EntryPlan({ kind = "record", key = "bad" })
        and not A.EntryPlan({ kind = "trend", key = "a", section = "bad" }),
    "unsupported entry keys fail closed"
)
local invalid = A.Copy(A.db)
invalid.runs[1].recordResets.duration = "bad"
check(not A.ValidateDatabase(invalid), "reset masks require boolean true entries")
A.ui.entryDialog:Hide()
AZS_SPELLS = saved.spells
AzerothStatsDB, A.db, A.run, A.view, AZS_GetPhase, AZS_RUN =
    saved.db, saved.db, saved.run, saved.view, saved.phase, saved.native
A.editMode, A.pendingEntryPlan, A.pendingDataPlan, A.deathWatch, A.pendingReport =
    saved.edit, saved.pending, saved.data, saved.death, saved.report
A.DetectLocale()
A.ApplyUI()
A.RefreshUI()
print("PER-ENTRY EDITING REGRESSIONS PASSED", TEST_COUNT)

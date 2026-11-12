-- Pure policy eligibility: synthetic runs only, no SavedVariables writes.
local A = AzerothStats
local before = A.Sign({ A.db.runs, A.db.totals, A.db.classes })
local fixture = {
    id = "synthetic-left",
    hero = "Synthetic",
    zone = "arena",
    class = "mage",
    status = "ended",
    result = "left",
    official = { result = "left", hero = "Synthetic", zone = "arena", class = "mage", t = 119 },
}
local original = A.Sign(fixture)
local function check(ok, reason)
    assert(ok, "abandoned policy: " .. reason)
    TEST_COUNT = TEST_COUNT + 1
end
check(A.AbandonedAdmissionEligible(fixture, 2), "fresh official short left is eligible")
check(not A.AbandonedAdmissionEligible(fixture, 1), "minimum duration respected")
fixture.official.t = 120
check(not A.AbandonedAdmissionEligible(fixture, 2), "exact threshold retained")
fixture.official.t = 119
fixture.status = "interrupted"
check(not A.AbandonedAdmissionEligible(fixture, 2), "interruption never inferred as left")
fixture.status = "ended"
fixture.official = nil
check(not A.AbandonedAdmissionEligible(fixture, 2), "missing official packet retained")
fixture.official = { result = "left", hero = "Other", zone = "arena", t = 10 }
check(not A.AbandonedAdmissionEligible(fixture, 2), "mismatched hero retained")
fixture.official.hero = "Synthetic"
fixture.official.zone = nil
check(not A.AbandonedAdmissionEligible(fixture, 2), "missing zone identity retained")
fixture.official.zone = "arena"
fixture.official.result = "victory"
check(not A.AbandonedAdmissionEligible(fixture, 2), "victory retained")
fixture.official.result = "left"
fixture.result = "victory"
check(not A.AbandonedAdmissionEligible(fixture, 2), "endless victory retained")
fixture.result = "left"
fixture.continued = true
check(not A.AbandonedAdmissionEligible(fixture, 2), "continued run retained")
fixture.continued = nil
fixture.favorite = true
check(not A.AbandonedAdmissionEligible(fixture, 2), "favorite retained")
fixture.favorite = nil
fixture.summaryRejected = true
check(not A.AbandonedAdmissionEligible(fixture, 2), "rejected summary retained")
fixture.summaryRejected = nil
fixture.official.t = -1
check(not A.AbandonedAdmissionEligible(fixture, 2), "negative duration retained")
fixture.official.t = 10
check(not A.AbandonedAdmissionEligible(fixture, -1), "invalid threshold rejected")
check(not A.AbandonedAdmissionEligible(fixture, nil), "unconfigured policy disabled")
check(not A.AbandonedAdmissionEligible(fixture, 1441), "unbounded threshold rejected")
check(A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == before, "ledgers untouched")
check(A.Sign(fixture) ~= original, "test mutations remain isolated to fixture")
-- The exposed command must only count eligible records, not change anything.
local savedRuns, savedSay = A.db.runs, A.Say
local printed = {}
A.Say = function(message)
    table.insert(printed, message)
end
local eligible = {
    id = "preview-left",
    class = "mage",
    hero = "Synthetic",
    zone = "arena",
    status = "ended",
    result = "left",
    official = { result = "left", hero = "Synthetic", zone = "arena", class = "mage", t = 90 },
}
local interrupted = A.Copy(eligible)
interrupted.id, interrupted.status = "preview-interrupted", "interrupted"
local victory = A.Copy(eligible)
victory.id, victory.result = "preview-victory", "victory"
eligible.counted = true
eligible.accounted = { damage = 42 }
eligible.spellAccounted = { damage = { SyntheticSpell = 10 } }
eligible.usage = { accounted = { spells = { synthetic = { runs = 1 } } } }
eligible.coop = { accounted = { teammate = { damage = 3 } } }
eligible.deaths = { { source = "synthetic" } }
local savedRecords, savedClasses, savedPruned = A.db.totals.records, A.db.classes, A.db.pruned
A.db.totals.records = { damage = { id = "preview-left", value = 42 } }
A.db.classes = { mage = { records = { damage = { id = "preview-left", value = 42 } } } }
A.db.pruned = 7
A.db.runs = { eligible, interrupted, victory }
local snapshot = A.Sign({ A.db.runs, A.db.totals, A.db.classes })
SlashCmdList["AZEROTHSTATS"]("abandon preview 2")
check(
    string.find(printed[1] or "", "1 eligible of 3 retained runs", 1, true) ~= nil,
    "preview counts only eligible official short-left outcomes"
)
check(
    string.find(
        printed[2] or "",
        "1 counted; 1 with metric entries; 1 with spell entries; 1 active record references",
        1,
        true
    ) ~= nil,
    "preview exposes aggregate accounting and record dependencies"
)
check(
    string.find(
        printed[3] or "",
        "1 class record references; 1 with build usage; 1 with co-op accounting; 1 with death evidence",
        1,
        true
    ) ~= nil,
    "preview reports per-class record, usage, coop and death dependencies"
)
check(
    string.find(printed[4] or "", "7 runs pruned", 1, true) ~= nil,
    "preview warns when historical data was pruned"
)
check(
    string.find(printed[5] or "", "no data changed", 1, true) ~= nil,
    "preview discloses read-only behavior"
)
check(A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == snapshot, "preview leaves ledgers intact")
printed = {}
SlashCmdList["AZEROTHSTATS"]("abandon preview 0")
check(string.find(printed[1] or "", "Usage:", 1, true) ~= nil, "invalid preview duration rejected")
check(A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == snapshot, "invalid preview is inert")
-- True favorites live in the bookmark catalogue, not in run.favorite.
local savedFavorites = A.db.favorites
A.db.favorites = { version = 1, entries = {} }
A.db.favorites.entries["run:preview-left"] = {
    kind = "run",
    key = "preview-left",
    runId = "preview-left",
}
printed = {}
SlashCmdList["AZEROTHSTATS"]("abandon preview 2")
check(
    string.find(printed[1] or "", "0 eligible of 3 retained runs", 1, true) ~= nil,
    "run bookmark protects its historical source from preview"
)
A.db.favorites.entries = {
    ["spell:synthetic"] = {
        kind = "spell",
        key = "synthetic",
        runId = "preview-left",
        tab = 4,
    },
}
printed = {}
SlashCmdList["AZEROTHSTATS"]("abandon preview 2")
check(
    string.find(printed[1] or "", "0 eligible of 3 retained runs", 1, true) ~= nil,
    "combat favorite protects its source run in the real preview"
)
check(
    not A.AbandonedAdmissionEligible(eligible, 2, true),
    "explicitly protected combat-source run is ineligible"
)
A.db.favorites = savedFavorites
-- Empty accounting dictionaries must not be mistaken for contributions.
local savedSpells, savedUsage, savedCoop = eligible.spellAccounted, eligible.usage, eligible.coop
eligible.spellAccounted = { damage = {} }
eligible.usage = { accounted = { spells = {} } }
eligible.coop = { accounted = {} }
local emptyImpact = A.AbandonedImpactPreview(2)
check(
    emptyImpact.eligible == 1
        and emptyImpact.withSpells == 0
        and emptyImpact.withUsage == 0
        and emptyImpact.withCoop == 0,
    "empty accounting containers do not inflate dependency counts"
)
eligible.spellAccounted, eligible.usage, eligible.coop = savedSpells, savedUsage, savedCoop
check(
    A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == snapshot,
    "bookmark preview leaves ledgers intact"
)
-- Session-only History visibility: never touch retained data, totals or backups.
local savedRefresh, savedClass = A.RefreshUI, A.view.class
local savedKind, savedResult = A.view.historyKind, A.view.historyResult
local savedAdvanced, savedSearch = A.view.historyAdvanced, A.view.historySearch
local savedDifficulty = A.view.difficulty
local savedHide = A.view.historyHideShortLeftMinutes
A.RefreshUI = function() end
A.view.class, A.view.historyKind, A.view.historyResult = nil, nil, nil
A.view.historyAdvanced, A.view.historySearch, A.view.difficulty = nil, "", nil
A.db.favorites = { version = 1, entries = {} }
check(A.MatchesHistory(eligible), "short left visible with session filter off")
local beforeToggle = A.Sign({ A.db.runs, A.db.totals, A.db.classes })
SlashCmdList["AZEROTHSTATS"]("abandon hide 2")
check(A.view.historyHideShortLeftMinutes == 2, "session filter stores requested minutes")
check(not A.MatchesHistory(eligible), "eligible short left hidden in history")
check(A.MatchesHistory(victory), "victory stays visible")
check(A.MatchesHistory(interrupted), "interrupted stays visible")
A.db.favorites.entries["run:preview-left"] = {
    kind = "run",
    key = "preview-left",
    runId = "preview-left",
}
check(A.MatchesHistory(eligible), "bookmarked left stays visible")
A.db.favorites.entries = {}
SlashCmdList["AZEROTHSTATS"]("abandon hide 0")
check(A.view.historyHideShortLeftMinutes == 2, "invalid hide threshold changes nothing")
SlashCmdList["AZEROTHSTATS"]("abandon show")
check(
    A.view.historyHideShortLeftMinutes == nil and A.MatchesHistory(eligible),
    "show resets filter"
)
check(A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == beforeToggle, "toggle preserves ledgers")
A.RefreshUI = savedRefresh
A.view.class, A.view.historyKind, A.view.historyResult = savedClass, savedKind, savedResult
A.view.historyAdvanced, A.view.historySearch = savedAdvanced, savedSearch
A.view.difficulty, A.view.historyHideShortLeftMinutes = savedDifficulty, savedHide
A.db.favorites = savedFavorites
A.Say, A.db.runs = savedSay, savedRuns
A.db.totals.records, A.db.classes, A.db.pruned = savedRecords, savedClasses, savedPruned
print("ABANDONED ADMISSION ELIGIBILITY REGRESSIONS PASSED", TEST_COUNT)

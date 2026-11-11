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
A.db.runs = { eligible, interrupted, victory }
local snapshot = A.Sign({ A.db.runs, A.db.totals, A.db.classes })
SlashCmdList["AZEROTHSTATS"]("abandon preview 2")
check(
    string.find(printed[1] or "", "1 eligible of 3 retained runs", 1, true) ~= nil,
    "preview counts only eligible official short-left outcomes"
)
check(
    string.find(printed[2] or "", "no runs, totals or backups changed", 1, true) ~= nil,
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
        category = "combat",
    },
}
-- Explicit protection is also safe independent of bookmark category mapping.
check(
    not A.AbandonedAdmissionEligible(eligible, 2, true),
    "protected combat-source run is ineligible"
)
A.db.favorites = savedFavorites
check(A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == snapshot, "bookmark preview leaves ledgers intact")
A.Say, A.db.runs = savedSay, savedRuns
print("ABANDONED ADMISSION ELIGIBILITY REGRESSIONS PASSED", TEST_COUNT)

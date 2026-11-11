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
print("ABANDONED ADMISSION ELIGIBILITY REGRESSIONS PASSED", TEST_COUNT)

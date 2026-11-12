-- Lot A: native run identity observations must not silently rewrite retained runs.
-- Synthetic replay of the manual /reload, lobby rollover and direct-reader cases.
local A = AzerothStats
local function verify(ok, label)
    assert(ok, "lot A identity: " .. label)
    TEST_COUNT = TEST_COUNT + 1
end

local savedZone, savedDb = AZS_ZONE, A.db
local savedManual, savedAuto = AzerothStatsBackup, AzerothStatsAutoBackup
local run = {
    id = "azstats-replay-1",
    status = "ended",
    result = "victory",
    partial = false,
    summary = { result = "victory", kills = 61, t = 490 },
    stats = { synthetic = 1 },
    equipment = { "synthetic-gear" },
    timeline = { { event = "synthetic" } },
    deaths = {},
    values = { kills = 61, duration = 490 },
}
local another = { id = "azstats-replay-2", status = "interrupted", values = {} }
local db = { runs = { run, another } }
A.db = db
local manual, auto = { marker = "manual" }, { marker = "auto" }
AzerothStatsBackup, AzerothStatsAutoBackup = manual, auto
local before = A.Sign({ db, manual, auto })

AZS_ZONE = { run = "ae4d123145af4971-1", phase = "live" }
local first = A.InteropNativeRunCandidate()
verify(first == "ae4d123145af4971-1", "opaque native ID read in live phase")
-- A /reload may replace the native packet while retaining the same game run.
AZS_ZONE = { run = "ae4d123145af4971-1", phase = "live" }
verify(A.InteropNativeRunCandidate() == first, "same native ID on reload")
-- In the lobby the game may preallocate the *next* run ID.
AZS_ZONE = { run = "c479a8db4402e523-2", phase = "ready" }
verify(A.InteropNativeRunCandidate() ~= first, "lobby candidate differs")
verify(
    run.nativeRunId == nil and another.nativeRunId == nil,
    "read-only observer never backfills finished or interrupted runs"
)
verify(A.ExportRunV1(run).run.nativeRunId == nil, "export does not misattribute lobby candidate")
local code = A.ExportRetainedCodeV1(run.id)
verify(
    type(code) == "string" and string.sub(code, 1, 6) == "AZST1:",
    "existing retained direct-reader run can be projected"
)
verify(
    run.summary.kills == 61
        and run.stats.synthetic == 1
        and run.equipment[1] == "synthetic-gear"
        and run.timeline[1].event == "synthetic",
    "WoW Logs direct-reader fields survive export unchanged"
)
verify(
    AzerothStatsBackup == manual and AzerothStatsAutoBackup == auto,
    "both backup roots preserve identity"
)
verify(A.Sign({ db, manual, auto }) == before, "no source or snapshot mutation")
AZS_ZONE, A.db = savedZone, savedDb
AzerothStatsBackup, AzerothStatsAutoBackup = savedManual, savedAuto
print("LOT A IDENTITY AND SAVE CONTRACT REGRESSIONS PASSED")

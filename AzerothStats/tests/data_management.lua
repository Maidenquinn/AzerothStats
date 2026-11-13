-- Data erasure is tested on isolated synthetic databases only, never a player's file.
local A = AzerothStats
local function check(ok, message)
    assert(ok, message)
    TEST_COUNT = TEST_COUNT + 1
end
local db, live, view, phaseFn, plan, retention =
    A.db, A.run, A.view, AZS_GetPhase, A.pendingDataPlan, A.pendingRetention
local keys = {
    "pendingReport",
    "partySession",
    "deathWatch",
    "journalPhaseRun",
    "journalPhase",
    "journalStatsWindow",
    "boundaryGate",
    "newBoundary",
    "inventoryBaseline",
    "buildBaseline",
    "spellPacket",
    "statsPacket",
    "inReady",
    "packetSummary",
    "packetReady",
    "meterPackets",
}
local transient = {}
for _, key in ipairs(keys) do
    transient[key] = A[key]
end
local nativeRun = AZS_RUN
AZS_RUN = A.Copy(nativeRun) or {}
AzerothStatsDB, A.db, A.run = nil, nil, nil
A.view = { tab = 8, page = 1, mode = "damage", characterTab = "Spells" }
AZS_GetPhase = function()
    return "ready"
end
check(A.InitDB(), "data fixture initializes")
A.SetLanguage("en")
-- Snapshot retention is configurable without changing legacy default behavior.
local priorManual, priorAuto = AzerothStatsBackup, AzerothStatsAutoBackup
AzerothStatsBackup, AzerothStatsAutoBackup = nil, nil
check(A.db.settings.autoBackupRetention == 15, "existing saves default to 15 automatic backups")
A.db.settings.autoBackupRetention = 2
for index = 1, 4 do
    A.db.sequence = index
    check(A.CreateDataBackup(true), "automatic snapshot can be created between runs")
end
local automatic = A.ListDataBackups(true)
check(
    table.getn(automatic) == 2 and automatic[1].id == 4 and automatic[2].id == 3,
    "retention keeps the newest two snapshots and preserves stable IDs"
)
check(A.CreateDataBackup(true), "identical automatic snapshot is safely reusable")
check(
    table.getn(A.ListDataBackups(true)) == 2 and A.ListDataBackups(true)[1].id == 4,
    "duplicate auto backup does not allocate a new ID or store another full copy"
)
check(A.CreateDataBackup(false), "manual backup remains independent")
check(
    table.getn(A.ListDataBackups(false)) == 1 and table.getn(A.ListDataBackups(true)) == 2,
    "automatic retention never removes a manual snapshot"
)
-- Manual cleanup requires a current preview and never touches automatic backups.
for index = 2, 5 do
    A.db.sequence = index
    check(A.CreateDataBackup(false), "manual snapshot fixture can be created")
end
local manualPlan = A.PreviewManualBackupCleanup(2)
check(manualPlan and manualPlan.remove == 3, "manual cleanup previews three older snapshots")
check(not A.CleanupManualBackups(2), "cleanup without preview token is rejected")
check(not A.CleanupManualBackups(2, "invalid"), "stale cleanup token is rejected")
local autoBeforeCleanup = table.getn(A.ListDataBackups(true))
local beforeCleanupBytes = string.len(SNAPSHOT(AzerothStatsBackup))
local liveSequenceBeforeCleanup = A.db.sequence
check(A.CleanupManualBackups(2, manualPlan.token), "confirmed cleanup removes old manual backups")
local afterCleanupBytes = string.len(SNAPSHOT(AzerothStatsBackup))
check(
    afterCleanupBytes < beforeCleanupBytes,
    "manual backup cleanup decreases serialized backup-root bytes if live data is unchanged"
)
check(
    A.db.sequence == liveSequenceBeforeCleanup,
    "manual backup cleanup does not alter live database sequence"
)
local keptManual = A.ListDataBackups(false)
check(
    table.getn(keptManual) == 2 and keptManual[1].id == 5 and keptManual[2].id == 4,
    "cleanup keeps the newest manual snapshots and stable IDs"
)
check(
    table.getn(A.ListDataBackups(true)) == autoBeforeCleanup,
    "manual cleanup does not affect automatic backups"
)
local emptyPlan = A.PreviewManualBackupCleanup(2)
check(emptyPlan and emptyPlan.remove == 0, "repeat cleanup is a no-op")
check(A.CleanupManualBackups(2, emptyPlan.token), "confirmed no-op cleanup succeeds")
A.run = { status = "active" }
check(not A.PreviewManualBackupCleanup(1), "manual cleanup preview blocked during active run")
check(not A.CleanupManualBackups(1, "invalid"), "manual cleanup blocked during active run")
A.run = nil
-- Active sessions must not snapshot, restore or delete a backup.
local activeFixture = { status = "active" }
A.run = activeFixture
local protectedCount = table.getn(A.ListDataBackups(true))
check(not A.CreateDataBackup(true), "active run cannot create a backup")
check(not A.RestoreDataBackup(nil, true), "active run cannot restore a backup")
check(not A.DeleteDataBackup(nil, true), "active run cannot delete a backup")
check(
    table.getn(A.ListDataBackups(true)) == protectedCount,
    "active-run guards leave backup history unchanged"
)
A.run = nil
-- A malformed catalogue row must not hide or delete valid neighboring snapshots.
local catalogue = AzerothStatsAutoBackup.entries
table.insert(catalogue, 1, { invalid = true })
check(table.getn(A.ListDataBackups(true)) == protectedCount, "malformed backup metadata is skipped")
check(not A.RestoreDataBackup(-999, true), "malformed backup row cannot be restored")
check(not A.DeleteDataBackup(-999, true), "malformed backup row cannot be deleted")
check(table.getn(catalogue) == protectedCount + 1, "malformed row remains available for recovery")
table.remove(catalogue, 1)
-- Corrupt stored snapshots must be rejected without replacing the live DB.
local latestAuto = AzerothStatsAutoBackup.entries[table.getn(AzerothStatsAutoBackup.entries)]
local validData = latestAuto.data
latestAuto.data = { invalid = true }
local beforeCorruptRestore = A.db
check(not A.RestoreDataBackup(latestAuto.id, true), "invalid snapshot cannot be restored")
check(A.db == beforeCorruptRestore, "invalid restore preserves the live database")
latestAuto.data = validData
check(not A.RestoreDataBackup(999999, true), "unknown backup ID cannot replace the live database")

-- A validated snapshot can still fail during initialization (migration,
-- theme initialization, or a future runtime change). Restore must be atomic
-- with respect to the active SavedVariables pointer and pending delete plan.
local rollbackSaved, rollbackDB = AzerothStatsDB, A.db
local rollbackPlan = { signature = "restore-rollback-test" }
local oldInitDB = A.InitDB
A.pendingDataPlan = rollbackPlan
A.InitDB = function()
    A.db = nil
    return false
end
local restoreFailed, restoreMessage = A.RestoreDataBackup(latestAuto.id, true)
A.InitDB = oldInitDB
check(not restoreFailed, "failed initialization rejects backup restore")
check(
    AzerothStatsDB == rollbackSaved and A.db == rollbackDB and A.pendingDataPlan == rollbackPlan,
    "failed restore preserves previous database pointers and pending plan"
)
check(
    string.find(restoreMessage or "", "previous database preserved", 1, true) ~= nil,
    "failed restore reports rollback to the user"
)
A.pendingDataPlan = nil

A.db.settings.autoBackupRetention = 15
A.db.settings.autoBackupEveryRuns = 2
A.db.settings.autoBackupRunCounter = 0
AzerothStatsAutoBackup = { schema = 2, nextId = 1, entries = {} }
-- Use a minimal terminal-state record; this function must not mutate a run.
local completed = { status = "ended" }
check(not A.RecordCompletedRunBackup(completed), "first completed run does not snapshot")
check(
    A.db.settings.autoBackupRunCounter == 1 and table.getn(A.ListDataBackups(true)) == 0,
    "periodic backup waits until the configured interval (counter="
        .. tostring(A.db.settings.autoBackupRunCounter)
        .. ", entries="
        .. tostring(table.getn(A.ListDataBackups(true)))
        .. ")"
)
check(A.RecordCompletedRunBackup(completed), "second completed run triggers snapshot")
check(
    A.db.settings.autoBackupRunCounter == 0
        and table.getn(A.ListDataBackups(true)) == 1
        and AzerothStatsAutoBackup.entries[1].data.settings.autoBackupRunCounter == 0,
    "successful periodic backup resets its live and persisted counters"
)
-- A repeated automatic request with an identical database must not multiply
-- the saved file size. This also covers safety snapshots requested twice
-- without an intervening data change.
local autoBeforeDuplicate = table.getn(A.ListDataBackups(true))
local nextIdBeforeDuplicate = AzerothStatsAutoBackup.nextId
local duplicateOK, duplicateMessage = A.CreateDataBackup(true)
check(duplicateOK, "identical automatic backup request succeeds")
check(
    table.getn(A.ListDataBackups(true)) == autoBeforeDuplicate
        and AzerothStatsAutoBackup.nextId == nextIdBeforeDuplicate,
    "identical automatic backup does not create a duplicate snapshot or advance its ID"
)
check(
    string.find(duplicateMessage or "", "already up to date", 1, true) ~= nil,
    "identical automatic backup explicitly reports deduplication"
)
-- A changed database must create a fresh automatic snapshot, and retention
-- of one must discard only the older automatic entry (never manual backups).
local savedSequence = A.db.sequence
local savedRetention = A.db.settings.autoBackupRetention
local manualBeforeRetention = table.getn(A.ListDataBackups(false))
A.db.settings.autoBackupRetention = 1
A.db.sequence = (A.Number(A.db.sequence) or 0) + 1
local changedOK = A.CreateDataBackup(true)
check(changedOK, "changed database creates a new automatic snapshot")
check(
    table.getn(A.ListDataBackups(true)) == 1
        and AzerothStatsAutoBackup.nextId == nextIdBeforeDuplicate + 1
        and AzerothStatsAutoBackup.entries[1].data.sequence == A.db.sequence,
    "automatic retention one keeps only the latest changed snapshot"
)
check(
    table.getn(A.ListDataBackups(false)) == manualBeforeRetention,
    "automatic retention does not prune manual backups"
)
A.db.sequence = savedSequence
A.db.settings.autoBackupRetention = savedRetention
check(
    not A.RecordCompletedRunBackup({ status = "interrupted" }),
    "interrupted runs never trigger periodic backup"
)
A.db.settings.autoBackupEveryRuns = 0
check(not A.RecordCompletedRunBackup(completed), "periodic backup is disabled by default")
A.db.sequence = 0
AzerothStatsBackup, AzerothStatsAutoBackup = priorManual, priorAuto
local function fixture(id, class)
    return {
        id = id,
        class = class or "warrior",
        hero = "Fixture",
        zone = "feralas",
        heroic = 0,
        startedAt = 10,
        status = "ended",
        result = "victory",
        values = { duration = 100, damage = 1000 },
        events = {},
        meters = {},
        accounted = { duration = 100, damage = 1000 },
        counted = true,
        winCounted = true,
    }
end
-- Stress the real snapshot path with increasing retained histories. These are
-- synthetic records: no player's SavedVariables are read or modified.
-- Timing and disk-size measurements must still be performed in the native client.
do
    local originalRuns, originalSequence = A.db.runs, A.db.sequence
    local originalAutomatic = AzerothStatsAutoBackup
    local originalRetention = A.db.settings.autoBackupRetention
    AzerothStatsAutoBackup = { schema = 2, nextId = 1, entries = {} }
    A.db.settings.autoBackupRetention = 1
    for _, count in ipairs({ 100, 500, 1000 }) do
        local runs = {}
        for index = 1, count do
            runs[index] = fixture("stress-" .. index)
        end
        A.db.runs = runs
        A.db.sequence = count
        local ok, reason = A.CreateDataBackup(true)
        check(ok, "snapshot accepts " .. count .. " synthetic retained runs: " .. tostring(reason))
        local store = AzerothStatsAutoBackup
        check(
            table.getn(store.entries) == 1 and table.getn(store.entries[1].data.runs) == count,
            "retention one preserves a complete " .. count .. "-run snapshot"
        )
        -- Stored snapshots must be independent: later mutations to the live
        -- database cannot silently rewrite an existing recovery point.
        local savedDamage = runs[1].values.damage
        runs[1].values.damage = savedDamage + 1
        check(
            store.entries[1].data.runs[1].values.damage == savedDamage,
            "stored " .. count .. "-run snapshot is independent from live mutations"
        )
        runs[1].values.damage = savedDamage
        local beforeId = store.nextId
        check(A.CreateDataBackup(true), "duplicate stress snapshot is accepted")
        check(
            store.nextId == beforeId and table.getn(store.entries) == 1,
            "duplicate " .. count .. "-run snapshot does not increase storage"
        )
    end
    -- With a large history, retention must keep three independent recovery
    -- points in chronological order, without mutating older snapshots.
    A.db.settings.autoBackupRetention = 3
    for version = 1, 3 do
        A.db.sequence = 1000 + version
        check(A.CreateDataBackup(true), "large history version " .. version .. " snapshots")
    end
    local retained = AzerothStatsAutoBackup.entries
    check(table.getn(retained) == 3, "large-history retention keeps three versions")
    for version = 1, 3 do
        check(
            retained[version].data.sequence == 1000 + version
                and table.getn(retained[version].data.runs) == 1000,
            "large-history recovery point " .. version .. " preserves its version and runs"
        )
    end
    -- A malformed live tree must fail closed and preserve the last valid
    -- recovery catalogue, rather than replace it with a partial snapshot.
    local lastBackupId = retained[3].id
    local lastBackupSequence = retained[3].data.sequence
    A.db.runs[1].cycle = A.db.runs[1]
    local cyclicOK = A.CreateDataBackup(true)
    A.db.runs[1].cycle = nil
    check(not cyclicOK, "cyclic large-history data cannot be backed up")
    check(
        table.getn(retained) == 3
            and retained[3].id == lastBackupId
            and retained[3].data.sequence == lastBackupSequence,
        "failed large-history snapshot preserves all existing recovery points"
    )
    -- An invalid live database must not silently convert an old schema-1
    -- catalogue into schema-2 before snapshot validation has succeeded.
    local validCatalogue = AzerothStatsAutoBackup
    local legacyCatalogue = { schema = 1, data = { runs = {} } }
    AzerothStatsAutoBackup = legacyCatalogue
    A.db.runs[1].cycle = A.db.runs[1]
    local legacyOK = A.CreateDataBackup(true)
    A.db.runs[1].cycle = nil
    check(not legacyOK, "invalid snapshot rejects legacy auto backup attempt")
    check(
        AzerothStatsAutoBackup == legacyCatalogue and legacyCatalogue.schema == 1,
        "failed backup leaves legacy snapshot root unchanged"
    )
    AzerothStatsAutoBackup = validCatalogue
    A.db.runs, A.db.sequence = originalRuns, originalSequence
    A.db.settings.autoBackupRetention = originalRetention
    AzerothStatsAutoBackup = originalAutomatic
end
local a, b, c = fixture("delete-a"), fixture("keep-fav"), fixture("keep-mage", "mage")
A.db.runs = { a, b, c }
A.db.sequence = 42
A.db.pruned = 100
A.db.totals = {
    runs = 103,
    wins = 40,
    sum = { damage = 123456 },
    coverage = { damage = 103 },
    records = { damage = { value = 90000, id = "old-pruned" } },
}
A.db.classes = {
    warrior = { runs = 70, sum = { damage = 100000 } },
    mage = {
        runs = 33,
        sum = { damage = 23456 },
    },
}
A.ToggleFavorite(A.RunFavorite(b))
local totals, classes = A.Sign(A.db.totals), A.Sign(A.db.classes)
check(
    A.DataPlan("bad") == nil and A.DataPlan("history", "bad-class") == nil,
    "invalid scope cannot select a destructive action"
)
A.PrepareDataAction("run", nil, b.id)
check(
    not A.ConfirmDataAction() and A.FindRun(b.id),
    "favorite source cannot be removed as ordinary history"
)
a.status = "active"
A.run = a
A.PrepareDataAction("run", nil, a.id)
check(not A.ConfirmDataAction() and A.FindRun(a.id), "tracked active run cannot be removed")
a.status = "ended"
A.run = nil
A.view.selected = a.id
A.view.compareA = a.id
A.PrepareDataAction("run", nil, a.id)
check(A.FindRun(a.id) ~= nil, "previewing removal never deletes a run")
check(A.ConfirmDataAction(), "confirmed unprotected run details can be deleted")
check(
    not A.FindRun(a.id) and not A.view.selected and not A.view.compareA,
    "removed source clears stale selectors"
)
check(
    A.view.tab == 3 and A.view.historySection == "History",
    "deleting selected details returns to History instead of silently switching reports"
)
check(
    A.db.totals.runs == 102
        and A.db.totals.sum.damage == 122456
        and A.db.classes.warrior.runs == 69
        and A.db.totals.records.damage.id == "old-pruned",
    "detail deletion subtracts accounted run and preserves unrelated pruned record"
)
check(
    AzerothStatsAutoBackup
        and AzerothStatsAutoBackup.entries[table.getn(AzerothStatsAutoBackup.entries)].data.totals.runs
            == 103,
    "deletion creates independent automatic backup"
)
check(A.CreateDataBackup(), "manual backup can be created independently")
check(
    AzerothStatsAutoBackup.entries[1].data.runs[1].id == "delete-a",
    "automatic snapshot retains deleted run"
)
local beforeRestore = A.db.totals.runs
check(A.RestoreDataBackup(nil, true), "restore succeeds from validated independent snapshot")
check(A.db.totals.runs == 103 and A.FindRun("delete-a"), "restore recovers run and lifetime totals")
check(A.db.totals.runs ~= beforeRestore, "restore changes data rather than merely refreshing UI")
A.PrepareDataAction("run", nil, "delete-a")
check(A.ConfirmDataAction(), "run can be removed again after restore")
check(
    AzerothStatsBackup.entries[1].data.totals.runs == 102,
    "automatic deletion never overwrites manual backup"
)
check(
    AzerothStatsAutoBackup.entries[table.getn(AzerothStatsAutoBackup.entries)].data.totals.runs
        == 103,
    "automatic snapshot updates independently"
)
for index = 1, 17 do
    -- Distinct database states must rotate; identical states are deduplicated.
    A.db.sequence = A.db.sequence + 1
    check(A.CreateDataBackup(true), "automatic snapshot " .. index)
end
-- The rotation fixture must not alter the sequence asserted by reset tests.
A.db.sequence = 42
check(table.getn(A.ListDataBackups(true)) == 15, "automatic history capped at fifteen")
check(table.getn(A.ListDataBackups(false)) == 1, "manual backup remains independent")
check(AzerothStatsAutoBackup.entries[1].id > 1, "oldest automatic snapshots rotate out")
check(A.CreateDataBackup(), "second manual snapshot")
check(table.getn(A.ListDataBackups(false)) == 2, "manual history appends instead of overwriting")

totals, classes = A.Sign(A.db.totals), A.Sign(A.db.classes)
local d = fixture("other-warrior")
table.insert(A.db.runs, d)
A.PrepareDataAction("history", "warrior")
local e = fixture("arrived-later")
table.insert(A.db.runs, e)
local ok, reason = A.ConfirmDataAction()
check(
    not ok and reason == "Data changed; review again" and A.FindRun(d.id),
    "changed deletion impact requires review before any mutation"
)
check(A.ConfirmDataAction(), "reconfirmed current class history plan applies")
check(
    A.FindRun(b.id) and A.FindRun(c.id) and not A.FindRun(d.id) and not A.FindRun(e.id),
    "class-history clear preserves favorites and other classes"
)
check(
    A.db.totals.runs == 100 and A.db.totals.sum.damage == 120456,
    "class-history clear subtracts known contributions only"
)
totals, classes = A.Sign(A.db.totals), A.Sign(A.db.classes)
-- The visible list selects a run without changing any saved data.
A.OpenDataManagement()
A.ui.dataDialog.actions[1].callback()
check(
    not A.ui.dataDialog.scopeButton:IsShown(),
    "single-run choice uses a visible list, not a long dropdown"
)
check(
    A.ui.dataDialog.confirm.label.fullText == A.T("Review deletion")
        and A.ui.dataDialog.selectionHint:IsShown(),
    "selection CTA explicitly opens review without deleting"
)
A.ui.dataDialog.rows[1].callback()
check(
    A.pendingDataPlan.id == c.id and A.FindRun(c.id) and A.Sign(A.db.totals) == totals,
    "clicking a dated row only selects its exact run"
)
A.ui.dataDialog.confirm.callback()
check(
    A.ui.dataDialog.stage == "review" and A.FindRun(c.id),
    "single-run review does not erase the selected run"
)
A.RefreshUI()
check(
    A.ui.dataDialog.reviewHeading:IsShown()
        and not A.ui.dataDialog.selectionHint:IsShown()
        and A.ui.dataDialog.title.fullText == A.T("Confirm deletion") .. " · 2/2",
    "review has a distinct confirmation title and irreversible-action explanation"
)
check(
    A.ui.dataDialog.confirm.label.fullText == A.T("Delete run details"),
    "global refresh preserves the explicit confirmation label"
)
A.ui.dataDialog.back.callback()
check(A.ui.dataDialog.id == c.id, "back keeps the chosen run")
A.ui.dataDialog.next.callback()
check(A.ui.dataDialog.previewPage == 1, "pagination clamps to available candidates")
A.ui.dataDialog.cancel.callback()
-- Native-owner regression: menus inside this new dialog must not disappear behind it.
A.OpenDataManagement()
A.ui.dataDialog.scopeButton.callback(A.ui.dataDialog.scopeButton)
check(
    A.ui.menu:GetParent() == A.ui.dataDialog
        and A.ui.menu:GetFrameLevel() > A.ui.dataDialog:GetFrameLevel(),
    "management popup has the correct dialog owner and level"
)
A.ui.menu:Hide()
A.ui.dataDialog.cancel.callback()
check(
    not A.pendingDataPlan and A.Sign(A.db.totals) == totals,
    "UI cancel changes no persisted statistics"
)
SlashCmdList.AZEROTHSTATS("reset")
check(
    A.ui.dataDialog:IsShown() and A.Sign(A.db.totals) == totals,
    "reset command only opens management; never erases immediately"
)
A.ui.dataDialog.cancel.callback()
A.OpenDataManagement()
A.ui.dataDialog.actions[3].callback()
check(
    A.ui.dataDialog.kind == "reset"
        and A.pendingDataPlan.kind == "reset"
        and A.Sign(A.db.totals) == totals,
    "choosing full reset previews it without deleting data"
)
A.ui.dataDialog.confirm.callback()
check(
    A.ui.dataDialog.stage == "review" and A.Sign(A.db.totals) == totals,
    "first continue only enters review; no persisted mutation"
)
check(
    string.find(A.ui.dataDialog.message.fullText, A.T("Will be kept"), 1, true),
    "review explicitly states what is kept"
)
A.ui.dataDialog.back.callback()
check(
    A.ui.dataDialog.stage == "select" and A.Sign(A.db.totals) == totals,
    "back returns to selection without deleting data"
)
A.ui.dataDialog.confirm.callback()
A.ui.dataDialog.token:SetText("WRONG")
A.ui.dataDialog.confirm.callback()
check(A.Sign(A.db.totals) == totals, "actual confirm callback rejects the wrong reset token")
A.ui.dataDialog.cancel.callback()
-- Full reset is separate from history removal and requires an explicit ready boundary/token.
AZS_GetPhase = function()
    return "playing"
end
A.PrepareDataAction("reset")
check(
    not A.ConfirmDataAction("RESET") and A.Sign(A.db.totals) == totals,
    "in-run reset is rejected even with the token"
)
AZS_GetPhase = function()
    return nil
end
AZS_RUN.ph = nil
A.PrepareDataAction("reset")
check(not A.ConfirmDataAction("RESET"), "missing native phase cannot authorize reset")
AZS_GetPhase = function()
    return "ready"
end
local phaseAccepted, phaseMessage = A.ConfirmDataAction("RESET")
check(
    not phaseAccepted and phaseMessage == "Data changed; review again",
    "newly available ready phase requires a fresh review"
)
A.PrepareDataAction("reset")
check(
    not A.ConfirmDataAction("reset") and A.Sign(A.db.totals) == totals,
    "token is exact and case sensitive"
)
check(not A.ConfirmDataAction("RESET "), "extra token characters cannot confirm")
local settings = A.db.settings
local hud, scale, language = A.Sign(settings.hud), settings.scale, settings.language
local migrations = A.Sign(A.db.migrations)
A.pendingReport = { id = b.id }
A.partySession = { run = b }
A.deathWatch = { run = b }
A.journalPhaseRun = b
check(A.ConfirmDataAction("RESET"), "explicit ready-phase full reset succeeds")
check(
    A.db.settings == settings
        and A.Sign(settings.hud) == hud
        and settings.scale == scale
        and settings.language == language,
    "full reset retains exact settings/HUD object"
)
check(
    A.db.sequence == 42 and A.Sign(A.db.migrations) == migrations,
    "IDs remain monotonic and migration markers remain"
)
check(
    table.getn(A.db.runs) == 0
        and not next(A.db.totals)
        and not next(A.db.classes)
        and not next(A.db.favorites.entries),
    "full reset clears all statistics/history/favorites"
)
check(
    not A.run
        and not A.pendingReport
        and not A.partySession
        and not A.deathWatch
        and not A.journalPhaseRun,
    "reset detaches old observer state and pending notices"
)
check(A.ValidateDatabase(A.db), "reset database still satisfies the saved-data contract")
local restored = assert(loadstring("return " .. SNAPSHOT(A.db)))()
check(
    A.ValidateDatabase(restored) and restored.sequence == 42,
    "reset database survives serialization without old totals"
)
AzerothStatsDB = restored
A.db = nil
check(
    A.InitDB() and not next(A.db.totals) and not next(A.db.classes),
    "normal initialization/migrations do not resurrect cleared totals"
)
-- New post-reset observations are counted once, using a new local run ID.
AZS_RUN = { ph = "playing", t = 1, kills = 2, gold = 1, lvl = 1, dealt = 10 }
AZS_GetPhase = function()
    return AZS_RUN.ph
end
A.Sample()
check(
    A.run and A.run.id == "azstats-43" and A.db.totals.runs == 1,
    "post-reset run starts clean with a unique ID"
)
local damage = A.db.totals.sum.damage
A.Sample()
check(
    A.db.totals.runs == 1 and A.db.totals.sum.damage == damage,
    "post-reset polling never reimports old ledgers"
)
-- Category cleanup uses synthetic data and leaves unrelated history/statistics intact.
A.run = nil
AZS_RUN.ph = "ready"
AZS_GetPhase = function()
    return "ready"
end
local old = fixture("category-old")
old.spells = { { key = "test", spell = 1, rank = 2 } }
old.usage = { spells = { test = { maxRank = 2, gains = 1 } }, jewelry = {} }
old.coop = { peers = { peer = { name = "Peer", class = "mage" } }, latest = {}, accounted = {} }
old.deaths = { { confidence = "unknown", t = 100, at = 10, hits = {} } }
old.reportRecords = { damage = 1000 }
old.recordBaseline = { values = {} }
local other = fixture("category-other", "mage")
A.db.runs = { old, other }
A.db.totals.records = { damage = { value = 1000, id = old.id, at = 10 } }
A.db.classes.warrior = { sum = { damage = 1000 }, records = A.Copy(A.db.totals.records) }
A.db.classes.mage = { records = { damage = { value = 500, id = other.id, at = 10 } } }
A.db.totals.deathEvidence = { deaths = 1, sources = { Kobold = { confirmed = 0, probable = 1 } } }
A.db.classes.warrior.deathEvidence = A.Copy(A.db.totals.deathEvidence)
A.db.totals.usage =
    { spells = { test = { runs = 1, gains = 1, changes = 0, maxRank = 2 } }, jewelry = {} }
A.db.classes.warrior.usage = A.Copy(A.db.totals.usage)
A.db.totals.companions = { peer = { name = "Peer", class = "mage", runs = 1, wins = 1 } }
A.db.classes.warrior.companions = A.Copy(A.db.totals.companions)
A.ToggleFavorite(A.RunFavorite(old))
local historyValues = A.Sign(old.values)
local oldSums = A.Sign(A.db.totals.sum)
local oldSpells, oldCoop = A.Sign(old.spells), A.Sign(old.coop)
check(
    A.DataPlan("records", "warrior") == nil,
    "category cleanup rejects an unsupported class scope"
)
A.OpenDataManagement()
A.ui.dataDialog.actions[1].callback()
A.ui.dataDialog.rows[2].callback()
check(
    string.find(A.ui.dataDialog.preview.identity.fullText, A.ZoneName(old), 1, true)
        and string.find(A.ui.dataDialog.preview.values.fullText, A.Metric("damage"), 1, true),
    "right preview follows the selected run and shows actual metrics"
)
A.ui.dataDialog.actions[4].callback()
check(
    A.pendingDataPlan.kind == "nemesis"
        and A.pendingDataPlan.count == 1
        and A.pendingDataPlan.details == 1,
    "category preview counts aggregate sources and historical evidence separately"
)
A.ui.dataDialog.cancel.callback()
check(A.db.totals.deathEvidence.deaths == 1, "cancel category cleanup keeps evidence")
AZS_RUN.ph = "playing"
AZS_GetPhase = function()
    return AZS_RUN.ph
end
A.PrepareDataAction("nemesis")
check(not A.ConfirmDataAction(), "category cleanup cannot run during play")
AZS_RUN.ph = "ready"
A.PrepareDataAction("nemesis")
check(
    A.ConfirmDataAction() and not A.db.totals.deathEvidence and not old.deaths,
    "nemesis cleanup removes aggregate and historical death log"
)
check(
    A.db.totals.records.damage and A.db.totals.usage.spells.test and A.IsRunProtected(old.id),
    "nemesis cleanup preserves records trends favorites and history"
)
A.PrepareDataAction("records")
A.db.classes.mage.records.gold = { value = 4, id = other.id, at = 10 }
check(not A.ConfirmDataAction(), "new class category entries invalidate a reviewed plan")
check(
    A.ConfirmDataAction()
        and not next(A.db.totals.records)
        and not next(A.db.classes.mage.records)
        and not old.reportRecords
        and not old.recordBaseline,
    "records cleanup clears all class records and historical milestones"
)
A.PrepareDataAction("trends")
check(
    A.ConfirmDataAction() and not A.db.totals.usage and not A.db.totals.companions and not old.usage,
    "trends cleanup clears builds popularity and companion totals"
)
check(
    A.Sign(old.values) == historyValues
        and A.Sign(old.spells) == oldSpells
        and A.Sign(old.coop) == oldCoop
        and A.Sign(A.db.totals.sum) == oldSums,
    "category cleanup preserves combat results build snapshots coop comparisons and lifetime totals"
)
A.Account(old)
A.ObserveBuild(old)
A.ObserveNemesis(old, { t = 100 }, "playing")
A.FinishReport(old)
check(
    not next(A.db.totals.records)
        and not A.db.totals.usage
        and not A.db.totals.companions
        and not old.usage
        and not old.reportRecords
        and not old.deaths,
    "old retained run callbacks cannot recreate cleared categories"
)
local reloaded = assert(loadstring("return " .. SNAPSHOT(A.db)))()
check(
    A.ValidateDatabase(reloaded)
        and reloaded.runs[1].recordsReset
        and reloaded.runs[1].trendsReset
        and reloaded.runs[1].nemesisReset,
    "category reset barriers survive serialization and database validation"
)
local categoryDb = A.db
AzerothStatsDB, A.db = reloaded, nil
check(A.InitDB(), "cleaned categories initialize through normal migrations")
A.Account(A.db.runs[1])
check(
    not next(A.db.totals.records)
        and not A.db.totals.usage
        and not A.db.totals.companions
        and not A.db.totals.deathEvidence,
    "normal reload cannot resurrect erased categories"
)
AzerothStatsDB, A.db = categoryDb, categoryDb
local flags = A.Copy(reloaded)
flags.runs[1].recordsReset = "bad"
check(not A.ValidateDatabase(flags), "saved reset barriers must be booleans")
A.PrepareDataAction("favorites")
check(
    A.ConfirmDataAction() and not next(A.db.favorites.entries) and A.FindRun(old.id),
    "favorites cleanup removes bookmarks without deleting retained runs"
)
local fresh = fixture("category-new")
fresh.counted, fresh.winCounted = false, false
fresh.accounted = {}
A.db.runs[3] = fresh
A.Account(fresh)
fresh.usage = { spells = {}, jewelry = {} }
A.AccountUsage(fresh, "spells", "test", { maxRank = 1, gains = 0 })
check(
    A.db.totals.records.damage and A.db.totals.usage.spells.test.runs == 1,
    "new runs collect fresh records and trends after category cleanup"
)
for _, lang in ipairs(A.languages) do
    if lang[1] ~= "auto" then
        A.SetLanguage(lang[1])
        A.OpenDataManagement()
        check(
            A.ui.dataDialog.title.fullText == A.T("Manage local data") .. " · 1/2",
            "localized data management title"
        )
        A.ui.dataDialog.cancel.callback()
    end
end
AzerothStatsDB, A.db, A.run, A.view, AZS_GetPhase, A.pendingDataPlan, A.pendingRetention =
    db, db, live, view, phaseFn, plan, retention
for _, key in ipairs(keys) do
    A[key] = transient[key]
end
AZS_RUN = nativeRun
A.DetectLocale()
A.ApplyUI()
A.RefreshUI()
print("LOCAL DATA MANAGEMENT REGRESSIONS PASSED", TEST_COUNT)

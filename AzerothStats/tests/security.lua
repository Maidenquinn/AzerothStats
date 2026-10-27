-- Adversarial fixtures run only in an isolated test VM, never in the game.
local A = AzerothStats
local function check(ok, message)
    assert(ok, message)
    TEST_COUNT = TEST_COUNT + 1
end
local savedDatabase, savedRun, savedView = AzerothStatsDB, A.run, A.view
local savedWatch, savedParty = A.deathWatch, A.partySession
local globals = {}
for _, name in ipairs({
    "AZS_RUN",
    "AZS_ZONE",
    "AZS_END",
    "AZS_SPELLS",
    "AZS_STATS",
    "AZS_METER",
    "AZS_HEALING",
    "AZS_BOSSMETER",
    "AZS_TAKEN",
    "AZS_GetMeter",
    "AZS_GetRunSummary",
    "AZS_GetPhase",
    "GetInventoryItemLink",
    "GetInventoryItemTexture",
}) do
    globals[name] = { value = getglobal(name) }
end
local function fresh()
    AzerothStatsDB = nil
    A.db = nil
    A.run = nil
    A.newBoundary = nil
    A.boundaryGate = nil
    A.buildBaseline = nil
    A.inventoryBaseline = nil
    A.packetReady = nil
    A.packetSummary = nil
    A.partySession = nil
    A.deathWatch = nil
    A.inReady = nil
    check(A.InitDB(), "valid empty database initializes")
end
fresh()
check(
    A.Number(0 / 0) == nil and A.Number(math.huge) == nil and A.Number(-1) == nil,
    "non-finite and negative counters rejected"
)
check(
    A.PrefixText("éé", 3) == "é" and A.PrefixText("界界", 5) == "界",
    "UTF-8 prefixes never split a valid multibyte character"
)
local cycle = {}
cycle.self = cycle
cycle.fn = function()
    error("data callback must not execute")
end
local copied = A.Copy(cycle)
check(
    copied and copied.self == nil and copied.fn == nil,
    "data copies omit cycles and executable values"
)
check(
    type(A.Sign(cycle)) == "string" and A.signatureLimited,
    "cyclic signature cannot recurse forever"
)
check(
    A.Text("|T../../secret|t|Hurl:https://example.invalid|hTitle|h|cffff0000Name|r") == "TitleName",
    "external texture/link/control markup removed"
)
for _, path in ipairs({
    "C:\\secret.tga",
    "../secret",
    "Interface\\..\\private.tga",
    "https://example.invalid/a.tga",
    "|Tbad|t",
}) do
    check(A.TexturePath(path) == nil, "unsafe texture namespace rejected")
end
check(
    A.TexturePath("INV_Sword_04") == "Interface\\Icons\\INV_Sword_04",
    "native icon basename remains supported"
)
for _, link in ipairs({
    "url:https://example.invalid",
    "|Hurl:abc|h[x]|h",
    "|Hrun:code|h[x]|h",
    "item:1;RunScript()",
}) do
    check(A.ItemLink(link) == nil, "non-item hyperlink rejected")
end
check(
    A.ItemLink("|cff00ff00|Hitem:123:0:0:0|h[Test]|h|r") == "item:123:0:0:0",
    "normal colored inventory link stays available"
)
check(
    A.FramePosition({ "BAD", "CENTER", 0, 0 }) == nil
        and A.FramePosition({ "CENTER", "CENTER", math.huge, 0 }) == nil,
    "invalid native anchors/coordinates rejected"
)
check(
    A.FramePosition({ "CENTER", "CENTER", -100, 12 })[3] == -100,
    "valid signed frame coordinates retained"
)
local dateReader = date
date = function()
    error("out of range native date")
end
check(A.Date(1e99) == A.T("Unavailable"), "native date errors remain unavailable")
date = dateReader
check(A.Duration(1e99) == A.T("Unavailable"), "duration cannot overflow native integer formatting")
AZS_RUN = {
    ph = "playing",
    t = 10,
    dealt = 100,
    unsafe = function()
        error("must not run")
    end,
    nested = { bad = true },
}
local before = A.Sign(AZS_RUN)
local progress = A.ReadProgress()
check(
    progress.unsafe == nil and progress.nested == nil and A.Sign(AZS_RUN) == before,
    "progress is a read-only scalar snapshot"
)
AZS_ZONE = { class = "unbounded-class-name", zone = "feralas" }
local _, class = A.Identity()
check(class == "rogue", "unknown packet class falls back to native class")
local called = 0
AZS_GetMeter = function()
    called = called + 1
    error("should not process oversized raw list")
end
AZS_METER = {}
for i = 1, 257 do
    AZS_METER[i] = { name = "Source" .. i, dmg = 1 }
end
local meter, reason = A.ReadMeter("damage")
check(
    not meter and reason == "paquet invalide" and called == 0,
    "oversized rows rejected before native helper execution"
)
AZS_METER = { { name = {}, dmg = 1 } }
meter = A.ReadMeter("damage")
check(not meter and called == 0, "malformed source names rejected before native helper execution")
AZS_GetMeter = globals.AZS_GetMeter.value
check(
    not A.Packet("AZSRUN", {}) and not A.Packet("AZSRUN", string.rep("x", 65537)),
    "invalid/oversized payload notifications rejected"
)
check(
    not A.Packet("NOT_AN_AZS_PACKET", "ph=ready") and not A.packetReady,
    "unrecognized prefixes cannot trigger boundaries"
)
check(
    not A.SummaryMatches({ hero = "Self", zone = "one" }, { hero = "Other", zone = "one" }),
    "conflicting final-result hero rejected"
)
check(
    not A.SummaryMatches({ hero = "Self", zone = "one" }, { hero = "Self", zone = "two" }),
    "conflicting final-result map rejected"
)
check(
    A.SummaryMatches({ hero = "Self", zone = "one" }, {}),
    "missing legacy identity remains explicitly heuristic"
)
local map = { a = 1, b = 2 }
local owner = {}
check(
    A.Admit(map, "a", 2, owner) and not A.Admit(map, "c", 2, owner) and owner.truncated,
    "dictionary cap allows existing keys, refuses new ones and flags partial coverage"
)
local function corrupt(edit)
    fresh()
    local database = AzerothStatsDB
    edit(database)
    check(
        not A.InitDB() and A.db == nil and AzerothStatsDB == database,
        "invalid database disables collection without replacing player data"
    )
end
corrupt(function(d)
    d.settings = "bad"
end)
corrupt(function(d)
    d.totals.records = { damage = { value = "bad" } }
end)
corrupt(function(d)
    d.favorites.entries.x = { kind = "run", key = "x", label = "X", display = { tooltip = "bad" } }
end)
corrupt(function(d)
    d.classes.rogue = { usage = { spells = { bad = "broken entry" } } }
end)
corrupt(function(d)
    d.loop = d
end)
corrupt(function(d)
    d.callback = function()
        error("save code must not execute")
    end
end)
local limit = A.limits.savedNodes
corrupt(function(d)
    A.limits.savedNodes = 4
    d.extra = { 1, 2, 3, 4 }
end)
A.limits.savedNodes = limit
fresh()
-- Filling a source dictionary must not allow one more observation to grow it.
A.db.classes.rogue = {}
A.db.totals.spells = { damage = {} }
for i = 1, A.limits.spellSources do
    A.db.totals.spells.damage["Source" .. i] = 1
end
local run = {
    id = "security",
    class = "rogue",
    values = {},
    accounted = {},
    events = {},
    meters = { damage = { rows = { { name = "New Source", dmg = 5 } }, total = 5 } },
    usage = { spells = {}, jewelry = {}, slots = {} },
}
A.Account(run)
check(
    A.db.totals.spells.damage["New Source"] == nil and A.db.totals.spellSourcesTruncated,
    "cumulative source growth bounded and marked partial"
)
AZS_SPELLS = {}
for i = 1, 256 do
    table.insert(AZS_SPELLS, { key = "fixture_" .. i, rank = 1 })
end
for i = 1, A.limits.usageKeys do
    run.usage.spells["old_" .. i] = { maxRank = 1, lastRank = 1, gains = 0 }
end
A.ObserveBuild(run)
check(
    run.usage.spells.fixture_1 == nil and run.usageTruncated,
    "per-run build dictionary cannot grow beyond its cap"
)
-- These are observed native capabilities the runtime must never call.
local blocked = {}
local forbiddenCalls = 0
for _, name in ipairs({
    "SendAddonMessage",
    "SendChatMessage",
    "SetCVar",
    "RunScript",
    "RunMacroText",
    "CastSpellByName",
    "UseAction",
    "TargetUnit",
    "SetBinding",
    "DeleteCursorItem",
}) do
    blocked[name] = { value = getglobal(name) }
    _G[name] = function()
        forbiddenCalls = forbiddenCalls + 1
        error("forbidden side effect")
    end
end
AZS_RUN = { ph = "playing", t = 10, kills = 1, lvl = 1, dealt = 10 }
AZS_ZONE = { class = "rogue", zone = "feralas" }
AZS_END = {}
AZS_SPELLS = {}
AZS_STATS = {}
AZS_METER = {}
AZS_HEALING = {}
AZS_TAKEN = {}
AZS_BOSSMETER = {}
A.run = nil
A.newBoundary = true
A.Packet("AZSRUN", "ph=playing;t=10")
A.Sample()
for tab = 1, table.getn(A.tabs) do
    A.view.tab = tab
    A.ToggleUI(true)
    A.RefreshUI()
end
check(
    forbiddenCalls == 0,
    "sampling and all presentation pages issue no outbound/gameplay/CVar/binding operations"
)
for name, record in pairs(blocked) do
    _G[name] = record.value
end
for name, record in pairs(globals) do
    _G[name] = record.value
end
AzerothStatsDB = savedDatabase
A.db = savedDatabase
A.run = savedRun
A.view = savedView
A.deathWatch = savedWatch
A.partySession = savedParty
A.signatureLimited = nil
A.inputLimited = nil
print("ADVERSARIAL INPUT AND CAPABILITY TESTS PASSED", TEST_COUNT)

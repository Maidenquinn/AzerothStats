local A = AzerothStats

A.metrics = {"duration", "kills", "gold", "damage", "healing", "taken", "bosses", "elites", "guardians", "chests", "magnets", "level"}

function A.InitDB()

 if AzerothStatsDB == nil then

  AzerothStatsDB = {schema = 1, sequence = 0, runs = {}, totals = {}, classes = {}, settings = {}, migrations = {}}

 end

 local d = AzerothStatsDB

 if type(d) ~= "table" or d.schema ~= A.schema or type(d.runs) ~= "table" or type(d.settings) ~= "table" or type(d.totals) ~= "table" or type(d.classes) ~= "table" or not A.Number(d.sequence) then

  A.Say(A.T("Database incompatible; collection disabled")); return false

 end

 for _, r in ipairs(d.runs) do

  if type(r) ~= "table" or type(r.values) ~= "table" or type(r.accounted) ~= "table" or type(r.events) ~= "table" or type(r.meters) ~= "table" then

   A.Say(A.T("Invalid run; database preserved")); return false

  end

 end

 A.db = d

 A.CorrectChests()
 A.NormalizeJewelry()

 local s = d.settings

 if s.bar == nil then s.bar = true end

 if s.minimap == nil then s.minimap = true end

 if s.locked == nil then s.locked = false end

 s.maxRuns = math.max(10, math.min(1000, math.floor(A.Number(s.maxRuns) or 200)))

 s.scale = math.max(0.65, math.min(1.5, A.Number(s.scale) or 1))

 s.opacity = math.max(0.45, math.min(1, A.Number(s.opacity) or 1))

 s.textSize = math.max(11, math.min(16, A.Number(s.textSize) or 12))

 if s.language~="auto" and not A.uiText[s.language] then s.language="auto" end

 d.version = A.version

 return true

end

local function bucket(t)

 t.sum = t.sum or {}; t.coverage = t.coverage or {}; t.records = t.records or {}

 return t

end

function A.Account(r)

 local d = A.db

 if not d or not r then return end

 if not d.classes[r.class] then d.classes[r.class] = {} end

 local groups = {bucket(d.totals), bucket(d.classes[r.class])}

 for _, g in ipairs(groups) do

  if not r.counted then g.runs = (g.runs or 0) + 1 end

  if r.result == "victory" and not r.winCounted then g.wins = (g.wins or 0) + 1 end

  for _, key in ipairs(A.metrics) do

   local value, old = A.Number(r.values[key]), r.accounted[key]

   if value then

    if old == nil then g.coverage[key] = (g.coverage[key] or 0) + 1 end

    if key ~= "level" then g.sum[key] = (g.sum[key] or 0) + value - (old or 0) end

    local rec = g.records[key]

    if not rec or value > rec.value then g.records[key] = {value = value, id = r.id, at = r.startedAt} end

   end

  end

 end

 r.counted = true

 if r.result == "victory" then r.winCounted = true end

 for _, key in ipairs(A.metrics) do if r.values[key] ~= nil then r.accounted[key] = r.values[key] end end

 -- Separate ledger for sampled spell counters. Never add rates or last-boss meters.

 r.spellAccounted = r.spellAccounted or {}

 for _, mode in ipairs({"damage", "healing", "taken"}) do

  local m = r.meters[mode]

  if m then

   local current = {}

   for _, row in ipairs(m.rows) do

    local name = tostring(row.name or row.source or "?")

    current[name] = (current[name] or 0) + row.dmg

   end

   r.spellAccounted[mode] = r.spellAccounted[mode] or {}

   for name, value in pairs(current) do

    local old = r.spellAccounted[mode][name] or 0

    for _, g in ipairs(groups) do

     g.spells = g.spells or {}; g.spells[mode] = g.spells[mode] or {}

     g.spells[mode][name] = (g.spells[mode][name] or 0) + value - old

    end

    r.spellAccounted[mode][name] = value

   end

  end

 end

end

function A.Trim()

 while table.getn(A.db.runs) > A.db.settings.maxRuns do

  table.remove(A.db.runs, 1); A.db.pruned = (A.db.pruned or 0) + 1

 end

end

-- Future imports must provide provenance and their own immutable identity.

-- No save-file reader or RSE1 parser is bundled in V1.

function A.RegisterImporter(name, fn)

 if type(name) == "string" and type(fn) == "function" then A.importers[name] = fn end

end



-- 1.0-1.2 incorrectly treated next-chest PRICE as a count. Preserve the old values for audit.

function A.CorrectChests()
 A.NormalizeJewelry()

 local d=A.db;d.migrations=d.migrations or {}

 if d.migrations.chestPrice13 then return end

 local groups={d.totals};for _,g in pairs(d.classes) do table.insert(groups,g) end

 for _,g in ipairs(groups) do

  g.legacyChest13={sum=g.sum and g.sum.chests,coverage=g.coverage and g.coverage.chests,record=g.records and g.records.chests}

  if g.sum then g.sum.chests=nil end;if g.coverage then g.coverage.chests=nil end;if g.records then g.records.chests=nil end

 end

 for _,r in ipairs(d.runs) do

  r.legacyChestPrice13=r.values.chests

  local value=r.summary and A.Number(r.summary.chests)

  r.values.chests=value;r.accounted.chests=value

  if value then

   for _,g in ipairs({d.totals,d.classes[r.class] or {}}) do

    g.sum=g.sum or {};g.coverage=g.coverage or {};g.records=g.records or {}

    g.sum.chests=(g.sum.chests or 0)+value;g.coverage.chests=(g.coverage.chests or 0)+1

    if not g.records.chests or value>g.records.chests.value then g.records.chests={value=value,id=r.id,at=r.startedAt} end

   end

  end

 end

 d.migrations.chestPrice13={version=A.version,pruned=d.pruned or 0}

end


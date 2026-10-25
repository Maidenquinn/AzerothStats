local A = AzerothStats

local summaryFields = {duration = "t", level = "lvl", kills = "kills", gold = "gold", damage = "dmg", taken = "taken", bosses = "bosses", elites = "elites", guardians = "guardians", chests = "chests", magnets = "magnets"}

local function applySummary(r, s)

 local sig = A.Sign(s)

 if sig == r.summarySignature then return end

 r.summarySignature = sig; r.summary = s; r.official = r.official or A.Copy(s)

 if not r.zone and type(s.zone)=="string" then r.zone=s.zone end
 r.result = s.result; r.status = "ended"; r.endedAt = A.Wall()

 for k, field in pairs(summaryFields) do if A.Number(s[field]) then r.values[k] = A.Number(s[field]) end end

 A.Event(r, "summary", "Resume officiel : " .. s.result)

end

local function close(reason)

 local r = A.run

 if r then

  if r.status == "active" then r.status = "interrupted" end

  r.closeReason = reason; A.Event(r, "boundary", reason); A.Account(r)

 end

 A.run = nil

end

local function start(ph, t)

 local d = A.db

 local key, cls, hero, zone, zname = A.Identity()

 local old = d.runs[table.getn(d.runs)]

 -- No server run UUID exists. Continuity after a UI reload is explicitly heuristic.

 if not A.newBoundary and old and old.identity == key and t and old.lastRawTime and t >= old.lastRawTime and not old.closeReason and ph ~= "ready" then

  A.run = old; old.resumeHeuristic = true

  A.Event(old, "resume", "Reprise probable apres rechargement ; pas d'identifiant serveur")

 else

  if old and old.status == "active" then old.status = "interrupted"; old.closeReason = "continuite non prouvee" end

  d.sequence = d.sequence + 1

  local r = {id = "azstats-" .. tostring(d.sequence), identity = key, class = cls, hero = hero, zone = zone, zoneName = zname,

   startedAt = A.Wall(), status = "active", phase = ph, values = {}, accounted = {}, meters = {}, unavailable = {}, events = {}, timeline = {},

   partial = not t or t > 2, gate = A.boundaryGate, summaryBaseline = A.Sign(A.Copy(AZS_END)), summaryStamp = AZS_END_UPDATED,

   inventoryBaseline=A.inventoryBaseline, bootTerminal = not A.newBoundary and (ph == "dead" or ph == "victory")}

  A.run = r; table.insert(d.runs, r)

  A.Event(r, "start", r.partial and "Partie observee en cours ; couverture partielle" or "Debut observe")

 end

 A.BeginInsights(A.run)
 A.newBoundary = nil

 A.Trim()

end

local function snapshot(r, raw, force)

 if not force and r.snapshotAt and r.values.duration and r.values.duration < r.snapshotAt + 15 then return end

 r.snapshotAt = r.values.duration or 0

 local v = {t = r.values.duration, level = r.values.level, kills = r.values.kills, gold = r.values.gold, phase = r.phase}

 table.insert(r.timeline, v)

 if table.getn(r.timeline) > 240 then table.remove(r.timeline, 2); r.timelineTruncated = true end

 local sig = A.Sign(A.Copy(AZS_SPELLS))

 if not r.spellsBaseline or sig ~= r.spellsBaseline then r.spells = A.Copy(AZS_SPELLS) end

 if not r.statsBaseline or A.Sign(A.Copy(AZS_STATS)) ~= r.statsBaseline then r.stats = A.Copy(AZS_STATS) end

 r.equipment = {};r.equipmentIcons={};r.equipmentTooltips={}

 for slot = 1, 19 do

  local link

  -- Inventory's API takes two arguments, unlike the simple one-argument reader.

  if type(GetInventoryItemLink) == "function" then

   local ok, value = pcall(GetInventoryItemLink, "player", slot)

   if ok then link = value else link = nil end

  end

  if type(link) == "string" then r.equipment[slot] = string.sub(link, 1, 500);r.equipmentTooltips[slot]=A.CaptureItem(slot) end

  if type(GetInventoryItemTexture)=="function" then

   local ok,texture=pcall(GetInventoryItemTexture,"player",slot)

   if ok and type(texture)=="string" then r.equipmentIcons[slot]=texture end

  end

 end

end

function A.Sample()

 if not A.db then return end

 local raw = type(AZS_RUN) == "table" and AZS_RUN or {}

 local ph = A.Call(AZS_GetPhase) or raw.ph

 local t = A.Number(raw.t) -- server sample, never the interpolated helper for records

 local key,cls,hero,zone,zname = A.Identity()
 if A.run and cls==A.run.class and hero==A.run.hero and (not zone or not A.run.zone or zone==A.run.zone) then
  if zone then A.run.zone=zone;A.run.zoneName=zname or A.run.zoneName;A.run.identity=key
  else key=A.run.identity end
 end

 local boundary = A.packetReady or (A.run and ((t and A.run.lastRawTime and t + 2 < A.run.lastRawTime) or (key ~= A.run.identity)

  or (t and A.run.lastRawTime and t < A.run.lastRawTime and A.Number(raw.kills) and A.run.values.kills and raw.kills < A.run.values.kills)))

 A.packetReady = nil

 if boundary then

  -- End and ready packets can arrive in the same render interval.

  local ending = A.packetSummary and A.ReadSummary()

  if A.run and ending and ending.hero == A.run.hero and ending.zone == A.run.zone and A.Number(ending.t) and ending.t >= (A.run.lastRawTime or 0) then applySummary(A.run, ending) end

  A.packetSummary = nil

  close("nouvelle preparation, identite ou horloge reinitialisee")

  A.boundaryGate = A.Gate(); A.newBoundary = true

  A.inventoryBaseline=A.InventorySignature();A.spellPacket=nil

  A.buildBaseline = {spells = A.Sign(A.Copy(AZS_SPELLS)), stats = A.Sign(A.Copy(AZS_STATS))}

 end

 if ph == "ready" then

  if not A.inReady then

   close("retour en preparation"); A.boundaryGate = A.Gate(); A.newBoundary = true

   A.inventoryBaseline=A.InventorySignature();A.spellPacket=nil

  A.buildBaseline = {spells = A.Sign(A.Copy(AZS_SPELLS)), stats = A.Sign(A.Copy(AZS_STATS))}

  end

  A.inReady = true; A.packetSummary = nil; A.meterPackets = {}; return

 end

 A.inReady = nil

 if not A.run and (ph == "playing" or ph == "choosing" or ph == "paused" or ph == "dead" or ph == "victory" or ph == "endless") then

  start(ph, t)

  if A.buildBaseline then A.run.spellsBaseline = A.buildBaseline.spells; A.run.statsBaseline = A.buildBaseline.stats end

 end

 local r = A.run

 if not r then A.packetSummary = nil; return end

 if ph then

  r.apiMissing=nil

  local terminalSnapshot=(ph=="dead" or ph=="victory") and r.phase~=ph

  if r.phase ~= ph then A.Event(r, "phase", tostring(r.phase) .. " -> " .. tostring(ph)) end

  local endTime = r.summary and A.Number(r.summary.t) or r.values.duration

  if (ph == "playing" or ph == "endless") and (r.status == "terminal" or r.status == "ended") and t and endTime and t > endTime then

   r.status = "active"; r.continued = true; A.Event(r, "continue", "Continuation apres fin officielle")

  end

  r.phase = ph; r.lastObservedAt = A.Wall()

  if t then r.lastRawTime = t; r.values.duration = t; r.provenance = r.provenance or {}; r.provenance.duration = "AZS_RUN.t (echantillon serveur)" end

  r.progress = A.Copy(raw)

  for k, field in pairs({kills = "kills", gold = "gold", level = "lvl", damage = "dealt", taken = "taken"}) do

   local n = A.Number(raw[field])

   if n then r.values[k] = n end

  end

  if A.meterPackets and r.gate then for k in pairs(A.meterPackets) do r.gate[k] = nil end end

  for k in pairs(A.sources) do

   local m, reason = A.ReadMeter(k, r.gate)

   if m then

    local old = r.meters[k]

    if k ~= "boss" and old and m.total < old.total then

     r.unavailable[k] = "compteur en baisse : dernier echantillon conserve"

     r.meterReset = true

    else

     r.meters[k] = m; r.unavailable[k] = nil

     -- Raw run counters have priority over sampled spell lists for whole-run totals.

     if k == "healing" or (k == "damage" and raw.dealt == nil) or (k == "taken" and raw.taken == nil) then r.values[k] = m.total end

    end

   else r.unavailable[k] = reason end

  end

  local level = r.values.level

  if level and level ~= r.lastLevel then A.Event(r, "level", "Niveau " .. A.Format(level)); r.lastLevel = level end

  A.ObserveInsights(r,raw,ph)
  if r.status=="active" then A.ObserveBuild(r) end

  snapshot(r, raw, terminalSnapshot)

  if (ph == "dead" or ph == "victory") and r.status == "active" then

   r.status = "terminal"; r.endedAt = A.Wall(); A.Event(r, "terminal", ph .. " ; attente du resume officiel")

  end

 else

  r.apiMissing = true -- a missing phase is not proof of death or abandonment

 end

 local s = A.ReadSummary()

 local sig = A.Sign(s)

 local bootstrap = s and r.bootTerminal and t and A.Number(s.t) and math.abs(s.t - t) < 0.1 and s.hero == r.hero and s.zone == r.zone

 local fresh = s and (A.packetSummary or bootstrap or (sig ~= r.summaryBaseline and AZS_END_UPDATED ~= r.summaryStamp))

 if fresh and sig ~= r.summarySignature then

  applySummary(r, s)

 end

 -- A final summary outranks the older AZSRUN packet, including on subsequent polls.

 if r.status == "ended" and r.summary then

  for k, field in pairs(summaryFields) do if A.Number(r.summary[field]) then r.values[k] = A.Number(r.summary[field]) end end

 end

 A.packetSummary = nil; A.meterPackets = {}

 A.Account(r)

end

function A.Packet(prefix, message)

 if prefix == "AZSRUN" and type(message) == "string" and string.find(";" .. message .. ";", ";ph=ready;", 1, true) then A.packetReady = true end

 if prefix == "AZSSPELLS" then A.spellPacket=true end

 if prefix == "AZSPARTY" then A.partyGeneration=(A.partyGeneration or 0)+1 end
 if prefix == "AZSEND" then A.packetSummary = true end

 local map = {AZSMETER = "damage", AZSHEAL = "healing", AZSBOSSDMG = "boss", AZSTAKEN = "taken"}

 if map[prefix] then A.meterPackets = A.meterPackets or {}; A.meterPackets[map[prefix]] = true end

end


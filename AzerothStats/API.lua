local A = AzerothStats
A.sources = {
 damage = {fn = "AZS_GetMeter", raw = "AZS_METER", scope = "partie"},
 healing = {fn = "AZS_GetHealing", raw = "AZS_HEALING", scope = "soins effectifs de la partie"},
 boss = {fn = "AZS_GetBossMeter", raw = "AZS_BOSSMETER", scope = "DERNIER combat de boss"},
 taken = {raw = "AZS_TAKEN", scope = "partie, par source"}
}
function A.Identity()
 local _, cls = A.Call(UnitClass, "player")
 local z = type(AZS_ZONE) == "table" and AZS_ZONE or {}
 local class = string.lower(tostring(z.class or cls or "UNKNOWN"))
 local hero = tostring(A.Call(UnitName, "player") or "?")
 return hero .. ":" .. class .. ":" .. tostring(z.zone or "?"), class, hero, z.zone, z.zname
end
function A.Gate()
 local gate = {}
 for key, src in pairs(A.sources) do gate[key] = {sig = A.Sign(A.Copy(getglobal(src.raw))), stamp = getglobal(src.raw .. "_UPDATED")} end
 gate.summary = A.Sign(A.Copy(AZS_END))
 gate.summaryStamp = AZS_END_UPDATED
 return gate
end
function A.ReadMeter(key, gate)
 local src = A.sources[key]
 local raw = getglobal(src.raw)
 local g = gate and gate[key]
 if g and g.sig == A.Sign(A.Copy(raw)) and g.stamp == getglobal(src.raw .. "_UPDATED") then return nil, "attente d'un paquet frais" end
 local rows, total, rate
 if src.fn then rows, total, rate = A.Call(getglobal(src.fn)) end
 if type(rows) ~= "table" then rows = raw end
 if type(rows) ~= "table" then return nil, "API absente" end
 if table.getn(rows) == 0 and getglobal(src.raw .. "_UPDATED") == nil then return nil, "aucun paquet recu" end
 local m = {rows = {}, total = 0, scope = src.scope, source = src.raw, sampledAt = A.Wall()}
 for i = 1, math.min(table.getn(rows), 256) do
  local row = rows[i]
  if type(row) ~= "table" or not A.Number(row.dmg) then return nil, "paquet invalide" end
  local clean = A.Copy(row); clean.dmg = A.Number(row.dmg); clean.dps = A.Number(row.dps)
  table.insert(m.rows, clean); m.total = m.total + clean.dmg
 end
 if table.getn(rows) > 256 then m.truncated = true end
 m.total = A.Number(total) or m.total
 m.rate = A.Number(rate)
 return m
end
function A.ReadSummary()
 local s = A.Call(AZS_GetRunSummary)
 if type(s) ~= "table" then s = AZS_END end
 if type(s) == "table" and (s.result == "victory" or s.result == "defeat" or s.result == "left") then return A.Copy(s) end
end
function A.Diagnostics()
 local out={}
 for _,r in ipairs(A.DiagnosticRows()) do table.insert(out,r[1].." : "..tostring(r[2])..(r[3] and " · "..r[3] or "")) end
 return out
end
function A.DiagnosticRows()
 local out={{A.T("Client"),"Interface 11200 / Lua 5.0"},{A.T("Schema"),A.schema.." / "..A.version},
  {A.T("Locale detection"),A.Locale(),A.localeSource=="Settings" and A.T("Settings") or A.localeSource or ""},{A.T("Local storage"),A.T("Saved on normal game exit")},
  {A.T("Interpolation"),A.Rate(A.Call(AZS_GetRunTime)),"AZS_GetRunTime"}}
 for _,n in ipairs({"AZS_GetPhase","AZS_GetRunTime","AZS_GetMeter","AZS_GetHealing","AZS_GetBossMeter","AZS_GetRunSummary","AZS_RUN","AZS_END","AZS_TAKEN","AZS_STATS"}) do
  table.insert(out,{n,getglobal(n)~=nil and A.T("Available") or A.T("Missing"),type(getglobal(n))})
 end
 if A.apiError then table.insert(out,{A.T("Last error"),A.apiError}) end
 if A.run then for k,reason in pairs(A.run.unavailable or {}) do table.insert(out,{A.ModeName(k),A.Reason(reason)}) end end
 return out
end

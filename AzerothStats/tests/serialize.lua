local function snapshot(v, seen, path)
    seen = seen or {}
    path = path or "AzerothStatsDB"
    if type(v) == "table" then
        assert(not seen[v], "cycle at " .. path .. " first seen " .. tostring(seen[v]))
        seen[v] = path
        local s = "{"
        for k, x in pairs(v) do
            s = s
                .. "["
                .. snapshot(k, seen, path .. ".key")
                .. "]="
                .. snapshot(x, seen, path .. "." .. tostring(k))
                .. ","
        end
        seen[v] = nil
        return s .. "}"
    end
    if type(v) == "string" then
        return string.format("%q", v)
    end
    if type(v) == "number" or type(v) == "boolean" then
        return tostring(v)
    end
    return "nil"
end
SNAPSHOT = snapshot

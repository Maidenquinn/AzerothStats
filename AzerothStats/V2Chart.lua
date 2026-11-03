-- Bounded native 11200 chart primitives. Stair guides connect adjacent retained
-- samples for readability; gaps are never bridged and no values are generated.
local A = AzerothStats
function A.V2ChartScale(value, minimum)
    local target = math.max(minimum or 1, value or 0)
    local unit = 1
    while target > unit * 10 do
        unit = unit * 10
    end
    for _, step in ipairs({ 1, 2, 5, 10 }) do
        if step * unit >= target then
            return step * unit
        end
    end
    return unit * 10
end

function A.V2DrawChart(graph, series, width, height, maxT, maxY, metric)
    graph.guides = graph.guides or {}
    local count, dots = 0, 0
    local function rect(x, y, w, h, color, alpha)
        count = count + 1
        local texture = graph.guides[count]
        if not texture then
            texture = graph:CreateTexture(nil, "ARTWORK")
            graph.guides[count] = texture
        end
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", graph, "TOPLEFT", x, -y)
        texture:SetWidth(math.max(1, w))
        texture:SetHeight(math.max(1, h))
        texture:SetTexture(unpack(color))
        texture:SetAlpha(alpha)
        texture:Show()
    end
    for side, points in ipairs(series) do
        local previous
        local color = side == 1 and A.theme.gold or A.theme.green
        local n = math.min(120, table.getn(points))
        for i = 1, n do
            local at = n > 1 and math.floor((i - 1) * (table.getn(points) - 1) / (n - 1)) + 1 or 1
            local p = points[at]
            local x, y = 8 + p.t / maxT * width, 48 + height - p.value / maxY * height
            local connected = previous ~= nil
            if previous then
                for j = previous.at + 1, at do
                    if points[j].gap then
                        connected = false
                    end
                end
            end
            if connected then
                -- Samples remain distinct. The horizontal/vertical guide is a
                -- visual step, not a claim that the counter was constant between packets.
                rect(previous.x, previous.y, x - previous.x, 2, color, 0.8)
                rect(x, math.min(y, previous.y), 2, math.abs(y - previous.y), color, 0.8)
                if side == 1 then
                    rect(
                        previous.x,
                        previous.y + 2,
                        x - previous.x,
                        math.max(0, 48 + height - previous.y - 2),
                        color,
                        0.09
                    )
                end
            end
            dots = dots + 1
            local dot = graph.points[dots]
            if not dot then
                dot = CreateFrame("Frame", nil, graph)
                dot:EnableMouse(true)
                dot.texture = dot:CreateTexture(nil, "OVERLAY")
                dot.texture:SetAllPoints(dot)
                dot:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(this.description)
                    GameTooltip:Show()
                end)
                dot:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                graph.points[dots] = dot
            end
            dot:SetWidth(4)
            dot:SetHeight(4)
            dot:ClearAllPoints()
            dot:SetPoint("TOPLEFT", graph, "TOPLEFT", x - 1, -y + 1)
            dot.texture:SetTexture(unpack(color))
            dot.description = (side == 1 and "A · " or "B · ")
                .. A.Duration(p.t)
                .. " · "
                .. A.Metric(metric)
                .. " "
                .. A.Format(p.value)
                .. (p.gap and " · " .. A.T("Partial") or "")
            dot:Show()
            previous = { x = x, y = y, at = at }
        end
    end
    for i = count + 1, table.getn(graph.guides) do
        graph.guides[i]:Hide()
    end
    for i = dots + 1, table.getn(graph.points) do
        graph.points[i]:Hide()
    end
    graph.guideCount, graph.sampleCount = count, dots
end

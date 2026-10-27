-- Chroniques d'Azeroth shared visual tokens. Source-defined assets, no external dependency.
local A = AzerothStats
A.theme = {
    name = "Chroniques d'Azeroth",
    version = 1,
    background = { 0.063, 0.09, 0.106 },
    panel = { 0.094, 0.129, 0.149 },
    bronze = { 0.54, 0.44, 0.27 },
    gold = { 0.85, 0.71, 0.42 },
    text = { 0.94, 0.91, 0.83 },
    muted = { 0.65, 0.70, 0.70 },
    green = { 0.61, 0.77, 0.57 },
    red = { 0.91, 0.40, 0.37 },
    edge = "Interface\\AddOns\\AzerothStats\\media\\ChronicleEdge.tga",
    grain = "Interface\\AddOns\\AzerothStats\\media\\ChronicleGrain.tga",
    seal = "Interface\\AddOns\\AzerothStats\\media\\ChronicleSeal.tga",
    icons = "Interface\\AddOns\\AzerothStats\\media\\ChronicleIcons.tga",
    media = "Interface\\AddOns\\AzerothStats\\media\\",
}

--- Fixed original painted glyph grid: compass, swords, laurel, hourglass, skull, clock,
--- helmet, trophy, journal, heart, gear, pulse, chart, chest, coins and shield.
function A.PaintedGlyph(texture, index)
    index = math.max(0, math.min(15, index - 1))
    texture:SetTexture(A.theme.media .. string.format("ChronicleGlyph%02d.tga", index + 1))
    texture:SetTexCoord(0, 1, 0, 1)
end

--- Decorative zone illustrations are original art, not recorded gameplay or telemetry.
function A.ZoneIllustration(texture, zone)
    local index = ({ elwynn = 0, naxx = 1, naxxramas = 1, feralas = 2, ungoro = 3 })[zone] or 0
    texture:SetTexture(A.theme.media .. "ChronicleZone" .. (index + 1) .. ".tga")
    texture:SetTexCoord(0, 1, 0, 1)
end

--- Select one original glyph from the fixed atlas; callers cannot choose an arbitrary texture path.
function A.ThemeIcon(texture, index)
    A.PaintedGlyph(texture, ({ 13, 13, 6, 2, 7, 8, 12, 11, 9, 10, 5, 12 })[index] or 9)
end

--- Paint explicit owned borders; never pass a custom strip to the client's backdrop tiler.
function A.PaintBorder(frame, r, g, b, alpha)
    for _, texture in ipairs(frame.themeBorder or {}) do
        texture:SetVertexColor(1, 1, 1)
        texture:SetAlpha(alpha or 1)
    end
end

--- Select a plate quadrant without rebuilding textures. Native SetBackdrop tiling is avoided.
function A.MaterialState(frame, active)
    local index = frame.themeKind == "card" and 2 or (active and 1 or 0)
    if frame.themeKind == "main" or frame.themeKind == "window" then
        index = 3
    end
    local path = A.theme.media .. "ChroniclePlate" .. (index + 1) .. ".tga"
    local cuts = { 0, 0.07, 0.93, 1 }
    for _, texture in ipairs(frame.materialParts or {}) do
        local x, y = texture.materialX, texture.materialY
        if texture.materialPath ~= path then
            texture:SetTexture(path)
            texture.materialPath = path
        end
        texture:SetTexCoord(cuts[x], cuts[x + 1], cuts[y], cuts[y + 1])
    end
end

--- Build a full frame ornament or nine bounded material slices, without native edge repetition.
function A.ThemeFrame(frame, kind)
    frame.themeBorder = {}
    frame.themeKind = kind
    if frame == A.window or frame:GetName() == "AzerothStatsBarEditor" then
        frame.themeKind = "window"
    end
    frame.materialParts = {}
    for y = 1, 3 do
        for x = 1, 3 do
            local texture = frame:CreateTexture(nil, "BORDER")
            texture.materialX, texture.materialY = x, y
            table.insert(frame.materialParts, texture)
            if x == 2 and y == 2 then
                frame.materialCenter = texture
                -- Keep the quiet existing slate/grain background on large windows;
                -- stretching a tiny material center over it magnifies its grain.
                if frame.themeKind == "window" then
                    texture:Hide()
                end
            else
                table.insert(frame.themeBorder, texture)
            end
        end
    end
    A.MaterialState(frame, false)
    A.UpdateThemeFrame(frame)
    A.PaintBorder(frame, 0.62, 0.51, 0.32, kind == "main" and 1 or 0.6)
end

--- Set explicit dimensions: this client does not resolve stretched texture sizes from two anchors.
function A.UpdateThemeFrame(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if frame.themeWidth == width and frame.themeHeight == height then
        return
    end
    frame.themeWidth = width
    frame.themeHeight = height
    local corner = math.min(
        frame.themeKind == "window" and 18
            or (frame.themeKind == "main" and 5 or (frame.themeKind == "card" and 10 or 6)),
        height / 3,
        width / 3
    )
    local xs, ys = { 0, corner, width - corner }, { 0, corner, height - corner }
    for _, texture in ipairs(frame.materialParts or {}) do
        local x, y = texture.materialX, texture.materialY
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", xs[x], -ys[y])
        texture:SetWidth(x == 2 and math.max(1, width - 2 * corner) or corner)
        texture:SetHeight(y == 2 and math.max(1, height - 2 * corner) or corner)
    end
end

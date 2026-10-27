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
    edge = "Interface\\AddOns\\AzerothStats\\media\\ChronicleEdge.tga",
    grain = "Interface\\AddOns\\AzerothStats\\media\\ChronicleGrain.tga",
    seal = "Interface\\AddOns\\AzerothStats\\media\\ChronicleSeal.tga",
    icons = "Interface\\AddOns\\AzerothStats\\media\\ChronicleIcons.tga",
    window = "Interface\\AddOns\\AzerothStats\\media\\ChronicleWindow.tga",
    glyphs = "Interface\\AddOns\\AzerothStats\\media\\ChronicleGlyphs.tga",
    landscapes = "Interface\\AddOns\\AzerothStats\\media\\ChronicleLandscapes.tga",
    surfaces = "Interface\\AddOns\\AzerothStats\\media\\ChronicleSurfaces.tga",
}

--- Fixed original painted glyph grid: compass, swords, laurel, hourglass, skull, clock,
--- helmet, trophy, journal, heart, gear, pulse, chart, chest, coins and shield.
function A.PaintedGlyph(texture, index)
    index = math.max(0, math.min(15, index - 1))
    local col, row = math.mod(index, 4), math.floor(index / 4)
    texture:SetTexture(A.theme.glyphs)
    texture:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
end

--- Decorative zone illustrations are original art, not recorded gameplay or telemetry.
function A.ZoneIllustration(texture, zone)
    local index = ({ elwynn = 0, naxx = 1, naxxramas = 1, feralas = 2, ungoro = 3 })[zone] or 0
    local col, row = math.mod(index, 2), math.floor(index / 2)
    texture:SetTexture(A.theme.landscapes)
    texture:SetTexCoord(col / 2 + 0.01, (col + 1) / 2 - 0.01, row / 2 + 0.12, (row + 1) / 2 - 0.12)
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
    if frame.themeKind == "main" then
        index = 3
    end
    local col, row = math.mod(index, 2), math.floor(index / 2)
    -- The painted horizontal divider is at 46.6 percent of the source canvas;
    -- use measured plate bounds rather than sampling across the adjoining plate.
    local top, bottom = row == 0 and 0 or 0.466, row == 0 and 0.466 or 1
    local cuts = { 0, 0.07, 0.93, 1 }
    for _, texture in ipairs(frame.materialParts or {}) do
        local x, y = texture.materialX, texture.materialY
        texture:SetTexCoord(
            col / 2 + cuts[x] / 2,
            col / 2 + cuts[x + 1] / 2,
            top + cuts[y] * (bottom - top),
            top + cuts[y + 1] * (bottom - top)
        )
    end
end

--- Build a full frame ornament or nine bounded material slices, without native edge repetition.
function A.ThemeFrame(frame, kind)
    frame.themeBorder = {}
    frame.themeKind = kind
    if frame == A.window or frame:GetName() == "AzerothStatsBarEditor" then
        local ornament = frame:CreateTexture(nil, "BORDER")
        ornament:SetTexture(A.theme.window)
        -- Source rails are inset in its transparent canvas. Expand the texture
        -- to align those rails with the owned panel and keep corner relief outside.
        local x = frame:GetWidth() * 0.043
        local y = frame:GetHeight() * 0.066
        ornament:SetPoint("TOPLEFT", frame, "TOPLEFT", -x, y)
        ornament:SetWidth(frame:GetWidth() + 2 * x)
        ornament:SetHeight(frame:GetHeight() + 2 * y)
        frame.windowOrnament = ornament
        return
    end
    frame.materialParts = {}
    for y = 1, 3 do
        for x = 1, 3 do
            local texture = frame:CreateTexture(nil, "BORDER")
            texture:SetTexture(A.theme.surfaces)
            texture.materialX, texture.materialY = x, y
            table.insert(frame.materialParts, texture)
            if x == 2 and y == 2 then
                frame.materialCenter = texture
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
    if frame.windowOrnament then
        frame.windowOrnament:ClearAllPoints()
        frame.windowOrnament:SetPoint("TOPLEFT", frame, "TOPLEFT", -width * 0.043, height * 0.066)
        frame.windowOrnament:SetWidth(width * 1.086)
        frame.windowOrnament:SetHeight(height * 1.132)
    end
    local corner = math.min(
        frame.themeKind == "main" and 5 or (frame.themeKind == "card" and 10 or 6),
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

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

-- Only these source-defined IDs may be persisted. No user-selected file paths,
-- API names or executable strings enter the presentation layer.
A.themeOrder = { "chroniques", "warcraft", "atelier", "essentiel", "grimoire" }
A.themes = {
    chroniques = {
        name = "Chroniques",
        description = "Theme chroniques description",
        material = "painted",
        serif = true,
        grainAlpha = 0.16,
        corner = 18,
        background = { 0.063, 0.09, 0.106 },
        panel = { 0.094, 0.129, 0.149 },
        bronze = { 0.54, 0.44, 0.27 },
        gold = { 0.85, 0.71, 0.42 },
        text = { 0.94, 0.91, 0.83 },
        muted = { 0.65, 0.70, 0.70 },
        green = { 0.61, 0.77, 0.57 },
        red = { 0.91, 0.40, 0.37 },
        active = { 0.21, 0.17, 0.10 },
        stripe = { 0.22, 0.29, 0.32 },
    },
    warcraft = {
        name = "Warcraft",
        description = "Theme warcraft description",
        material = "native",
        serif = true,
        grainAlpha = 0.23,
        corner = 16,
        background = { 0.055, 0.047, 0.035 },
        panel = { 0.105, 0.086, 0.063 },
        bronze = { 0.48, 0.46, 0.40 },
        gold = { 1, 0.82, 0.36 },
        text = { 0.97, 0.92, 0.80 },
        muted = { 0.74, 0.71, 0.62 },
        green = { 0.46, 0.87, 0.39 },
        red = { 1, 0.39, 0.32 },
        active = { 0.34, 0.055, 0.035 },
        stripe = { 0.24, 0.21, 0.16 },
    },
    atelier = {
        name = "Atelier",
        description = "Theme atelier description",
        material = "flat",
        serif = false,
        grainAlpha = 0,
        corner = 1,
        background = { 0.085, 0.082, 0.079 },
        panel = { 0.135, 0.129, 0.122 },
        bronze = { 0.37, 0.33, 0.29 },
        gold = { 0.91, 0.64, 0.43 },
        text = { 0.94, 0.92, 0.88 },
        muted = { 0.70, 0.69, 0.66 },
        green = { 0.61, 0.80, 0.63 },
        red = { 0.98, 0.52, 0.46 },
        active = { 0.24, 0.18, 0.135 },
        stripe = { 0.29, 0.28, 0.26 },
    },
    essentiel = {
        name = "Essentiel",
        description = "Theme essentiel description",
        material = "flat",
        serif = false,
        grainAlpha = 0,
        corner = 1,
        quiet = true,
        background = { 0.047, 0.055, 0.063 },
        panel = { 0.071, 0.082, 0.090 },
        bronze = { 0.24, 0.27, 0.29 },
        gold = { 0.94, 0.79, 0.48 },
        text = { 0.94, 0.95, 0.95 },
        muted = { 0.66, 0.71, 0.73 },
        green = { 0.62, 0.83, 0.63 },
        red = { 0.99, 0.50, 0.46 },
        active = { 0.12, 0.14, 0.15 },
        stripe = { 0.18, 0.21, 0.23 },
    },
    grimoire = {
        name = "Grimoire",
        description = "Theme grimoire description",
        material = "paper",
        serif = true,
        grainAlpha = 0.52,
        corner = 30,
        background = { 0.92, 0.86, 0.73 },
        panel = { 0.96, 0.91, 0.80 },
        bronze = { 0.40, 0.27, 0.14 },
        gold = { 0.35, 0.16, 0.085 },
        text = { 0.17, 0.12, 0.08 },
        muted = { 0.34, 0.28, 0.20 },
        green = { 0.18, 0.36, 0.17 },
        red = { 0.62, 0.12, 0.10 },
        active = { 0.73, 0.59, 0.39 },
        stripe = { 0.53, 0.40, 0.23 },
    },
}
A.themeFrames, A.themeGlyphs, A.themePanels, A.themeTextures = {}, {}, {}, {}

--- Normalize a saved ID to a known theme. Unknown/old settings keep Chroniques.
function A.ThemeId(id)
    return type(id) == "string" and A.themes[id] and id or "chroniques"
end

--- Mutate token arrays in place: existing widgets retain references to their roles.
--- This function changes presentation only, never database statistics or layout.
function A.UseTheme(id)
    id = A.ThemeId(id)
    local definition = A.themes[id]
    A.activeTheme = id
    for key, value in pairs(definition) do
        if type(value) == "table" then
            A.theme[key] = A.theme[key] or {}
            for i = 1, 3 do
                A.theme[key][i] = value[i]
            end
        else
            A.theme[key] = value
        end
    end
    A.theme.quiet = definition.quiet and true or false
    A.theme.grain = definition.material == "native"
            and "Interface\\DialogFrame\\UI-DialogBox-Background"
        or (
            definition.material == "paper" and (A.theme.media .. "GrimoirePaper.tga")
            or (A.theme.media .. "ChronicleGrain.tga")
        )
end
A.UseTheme("chroniques")

--- Retain a color role for repainting dividers, tracks and alternating rows.
function A.ThemeTexture(texture, role)
    texture.themeRole = role
    table.insert(A.themeTextures, texture)
    texture:SetTexture(unpack(A.theme[role]))
end

--- Original geometric icon atlas for contemporary/quiet themes; native WoW icons
--- for Warcraft; painted Chroniques glyphs otherwise. All paths are fixed below.
local nativeGlyphs = {
    "INV_Shield_05",
    "INV_Sword_04",
    "Spell_Holy_BlessingOfStrength",
    "INV_Misc_PocketWatch_01",
    "Ability_Creature_Cursed_02",
    "INV_Misc_PocketWatch_01",
    "INV_Helmet_03",
    "INV_Misc_Coin_02",
    "INV_Misc_Book_09",
    "Spell_Holy_PrayerOfHealing",
    "Trade_Engineering",
    "Spell_Nature_Lightning",
    "INV_Misc_Note_01",
    "INV_Box_01",
    "INV_Misc_Coin_01",
    "INV_Shield_05",
}
local function paintGlyph(texture)
    local index = texture.themeGlyph
    if not index then
        return
    end
    texture:SetVertexColor(1, 1, 1)
    if A.activeTheme == "warcraft" then
        texture:SetTexture("Interface\\Icons\\" .. nativeGlyphs[index])
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    elseif A.theme.material == "flat" or A.activeTheme == "grimoire" then
        texture:SetTexture(A.theme.icons)
        local cell = ({ 6, 3, 5, 2, 10, 2, 4, 5, 8, 9, 6, 11, 0, 8, 5, 4 })[index]
        local x, y = math.mod(cell, 4), math.floor(cell / 4)
        texture:SetTexCoord(x / 4, (x + 1) / 4, y / 4, (y + 1) / 4)
        texture:SetVertexColor(unpack(A.theme.gold))
    else
        texture:SetTexture(A.theme.media .. string.format("ChronicleGlyph%02d.tga", index))
        texture:SetTexCoord(0, 1, 0, 1)
        if A.activeTheme == "grimoire" then
            texture:SetVertexColor(0.50, 0.36, 0.23)
        end
    end
end

--- Fixed original painted glyph grid: compass, swords, laurel, hourglass, skull, clock,
--- helmet, trophy, journal, heart, gear, pulse, chart, chest, coins and shield.
function A.PaintedGlyph(texture, index)
    index = math.max(1, math.min(16, index))
    if not texture.themeGlyphRegistered then
        table.insert(A.themeGlyphs, texture)
        texture.themeGlyphRegistered = true
    end
    texture.themeGlyph = index
    paintGlyph(texture)
end

-- Source photos/framing: data/run-image-sources.json and tools/build_run_images.py.
-- BEGIN GENERATED RUN IMAGE MAP
local runImages = {
    ab = { "RunZone-ab.tga", 0, 1, 0.211298, 0.908702 },
    aq = { "RunZone-aq.tga", 0, 1, 0.181298, 0.878702 },
    arena = { "RunZone-arena.tga", 0, 1, 0.160412, 0.819588 },
    av = { "RunZone-av.tga", 0, 1, 0.191298, 0.888702 },
    brm = { "RunZone-brm.tga", 0, 1, 0.258001, 0.901999 },
    duskwood = { "RunZone-duskwood.tga", 0, 1, 0.303371, 0.896629 },
    elwynn = { "RunZone-elwynn.tga", 0, 1, 0.230412, 0.889588 },
    feralas = { "RunZone-feralas.tga", 0, 1, 0.170778, 0.829222 },
    naxx = { "RunZone-naxx.tga", 0, 1, 0.171298, 0.868702 },
    sm = { "RunZone-sm.tga", 0, 1, 0.249224, 0.910776 },
    ungoro = { "RunZone-ungoro.tga", 0, 1, 0.240251, 0.899749 },
    wsg = { "RunZone-wsg.tga", 0, 1, 0.229678, 0.890322 },
}
-- END GENERATED RUN IMAGE MAP

--- Use the supplied zone photo with aspect-correct native framing. Historical names
--- and unknown zones never select a different map just to fill the thumbnail.
function A.ZoneIllustration(texture, zone)
    if zone == "naxxramas" then
        zone = "naxx"
    end
    local entry = runImages[zone]
    texture:SetTexture(A.theme.media .. (entry and entry[1] or "ChroniclePlate4.tga"))
    if entry then
        texture:SetTexCoord(entry[2], entry[3], entry[4], entry[5])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

--- Select one original glyph from the fixed atlas; callers cannot choose an arbitrary texture path.
function A.ThemeIcon(texture, index)
    A.PaintedGlyph(texture, ({ 13, 13, 6, 2, 7, 8, 12, 11, 9, 10, 5, 12 })[index] or 9)
end

--- Paint explicit owned borders; never pass a custom strip to the client's backdrop tiler.
function A.PaintBorder(frame, r, g, b, alpha)
    frame.borderAlpha = alpha or 1
    for _, texture in ipairs(frame.themeBorder or {}) do
        texture:SetVertexColor(1, 1, 1)
        texture:SetAlpha(frame.borderAlpha)
    end
    if frame.themeNative then
        frame:SetBackdropBorderColor(1, 1, 1, frame.borderAlpha)
    end
end

--- Repaint the same nine owned slices. Contemporary themes use solid one-pixel
--- rules, Grimoire uses original parchment plates, Warcraft uses client textures.
function A.MaterialState(frame, active)
    local changed = frame.materialTheme ~= A.activeTheme
        or frame.themeActive ~= (active and true or false)
    frame.themeActive = active and true or false
    if not changed then
        return
    end
    frame.materialTheme = A.activeTheme
    local kind = frame.themeKind
    local window = kind == "main" or kind == "window"
    local material = A.theme.material
    local index = kind == "card" and 2 or (active and 1 or 0)
    if window then
        index = 3
    end
    local path = A.theme.media .. "ChroniclePlate" .. (index + 1) .. ".tga"
    if material == "paper" then
        path = A.theme.media .. "GrimoirePlate" .. (index + 1) .. ".tga"
    end
    local cuts = material == "paper" and window and { 0, 0.12, 0.88, 1 } or { 0, 0.07, 0.93, 1 }
    -- Native backdrop borders use Blizzard's documented eight-tile format, not
    -- the custom atlas which previously produced repeating gold stripes.
    frame.themeNative = material == "native" and kind ~= "button"
    if frame.themeNative and frame.themeBackdrop ~= "native" then
        frame:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = window and 32 or 16,
        })
        frame:SetBackdropBorderColor(1, 1, 1, frame.borderAlpha or 0.8)
    elseif not frame.themeNative and frame.themeBackdrop == "native" then
        frame:SetBackdrop(nil)
    end
    if frame.themeBackdrop ~= material then
        frame.nativeEdge = nil
    end
    frame.themeBackdrop = material
    for _, texture in ipairs(frame.materialParts or {}) do
        local x, y = texture.materialX, texture.materialY
        texture:SetVertexColor(1, 1, 1)
        if material == "flat" then
            texture:SetTexture(
                unpack(
                    x == 2 and y == 2 and (active and A.theme.active or A.theme.panel)
                        or A.theme.bronze
                )
            )
            texture:SetTexCoord(0, 1, 0, 1)
        elseif material == "native" then
            texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
            local xs, ys = { 0, 0.09375, 0.53125, 0.625 }, { 0, 0.1875, 0.5, 0.6875 }
            texture:SetTexCoord(xs[x], xs[x + 1], ys[y], ys[y + 1])
        else
            texture:SetTexture(path)
            texture:SetTexCoord(cuts[x], cuts[x + 1], cuts[y], cuts[y + 1])
        end
        -- Warcraft buttons have native red leather; other surfaces use their
        -- solid base and native stone border. Quiet cards have no outline.
        local hide = (window and x == 2 and y == 2)
            or (material == "native" and (kind ~= "button" or (frame.navigation and not active)))
            or (A.theme.quiet and kind == "card" and (x ~= 2 or y ~= 2))
        if hide then
            texture:Hide()
        else
            texture:Show()
        end
    end
    A.PaintBorder(frame, 1, 1, 1, frame.borderAlpha)
end

--- Build a full frame ornament or nine bounded material slices, without native edge repetition.
function A.ThemeFrame(frame, kind)
    table.insert(A.themeFrames, frame)
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
    if
        frame.themeWidth == width
        and frame.themeHeight == height
        and frame.themeLayout == A.activeTheme
    then
        return
    end
    if frame.themeNative then
        local edge = height < 100 and 8
            or frame == A.window and 32
            or (frame.themeKind == "card" and 12 or 20)
        if frame.nativeEdge ~= edge then
            frame:SetBackdrop({
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                edgeSize = edge,
            })
            frame:SetBackdropBorderColor(1, 1, 1, frame.borderAlpha or 1)
            frame.nativeEdge = edge
        end
    end
    frame.themeLayout = A.activeTheme
    frame.themeWidth = width
    frame.themeHeight = height
    local corner = math.min(
        A.theme.material == "flat" and 1
            or (
                frame.themeKind == "window" and A.theme.corner
                or (frame.themeKind == "main" and 5 or (frame.themeKind == "card" and 10 or 6))
            ),
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

--- Settings sections are textures on their existing parent, never extra frames
--- above its labels. Store geometry so flat themes can reduce borders to 1px.
local function paintPanel(panel)
    local edge = (A.theme.material == "flat" or A.theme.material == "native") and 1 or 12
    local xs, ys = { 0, edge, panel.width - edge }, { 0, edge, panel.height - edge }
    local cuts = { 0, 0.07, 0.93, 1 }
    for i, texture in ipairs(panel.parts) do
        local x, y = math.mod(i - 1, 3) + 1, math.floor((i - 1) / 3) + 1
        local center = x == 2 and y == 2
        if A.theme.material == "painted" or A.theme.material == "paper" then
            texture:SetTexture(
                A.theme.media
                    .. (
                        A.theme.material == "paper" and "GrimoirePlate3.tga"
                        or "ChroniclePlate3.tga"
                    )
            )
            texture:SetTexCoord(cuts[x], cuts[x + 1], cuts[y], cuts[y + 1])
        else
            texture:SetTexture(unpack(center and A.theme.panel or A.theme.bronze))
        end
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", panel.parent, "TOPLEFT", panel.x + xs[x], -panel.y - ys[y])
        texture:SetWidth(x == 2 and panel.width - 2 * edge or edge)
        texture:SetHeight(y == 2 and panel.height - 2 * edge or edge)
    end
end
function A.ThemePanel(parent, x, y, width, height)
    local panel = { parent = parent, x = x, y = y, width = width, height = height, parts = {} }
    for i = 1, 9 do
        table.insert(panel.parts, parent:CreateTexture(nil, "BACKGROUND"))
    end
    table.insert(A.themePanels, panel)
    paintPanel(panel)
    return panel.parts
end

--- Repaint allocated ornaments only; never create textures when changing theme.
function A.RepaintMaterials()
    for _, frame in ipairs(A.themeFrames) do
        A.MaterialState(frame, frame.themeActive)
        A.UpdateThemeFrame(frame)
    end
    for _, texture in ipairs(A.themeGlyphs) do
        paintGlyph(texture)
    end
    for _, texture in ipairs(A.themeTextures) do
        texture:SetTexture(unpack(A.theme[texture.themeRole]))
    end
    for _, panel in ipairs(A.themePanels) do
        paintPanel(panel)
    end
end

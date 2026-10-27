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
}

--- Select one original glyph from the fixed atlas; callers cannot choose an arbitrary texture path.
function A.ThemeIcon(texture, index)
    index = math.max(0, math.min(11, index - 1))
    local col, row = math.mod(index, 4), math.floor(index / 4)
    texture:SetTexture(A.theme.icons)
    texture:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
end

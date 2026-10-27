NOW = 100
function GetTime()
    return NOW
end
SlashCmdList = {}
objects = {}
local methods = {}
function methods:SetScript(k, v)
    self.scripts[k] = v
end
function methods:GetScript(k)
    return self.scripts[k]
end
function methods:RegisterEvent(k)
    self.events[k] = true
end
function methods:GetName()
    return self._name
end
function methods:GetObjectType()
    return self.kind
end
function methods:SetWidth(v)
    self.width = v
end
function methods:SetHeight(v)
    self.height = v
end
function methods:GetWidth()
    return self.width or 232
end
function methods:GetHeight()
    return self.height or 100
end
function methods:SetPoint(...)
    self.point = arg
end
function methods:GetPoint()
    if self.point then
        return unpack(self.point)
    end
end
function methods:ClearAllPoints()
    self.point = nil
end
function methods:SetAllPoints() end
function methods:Show()
    self.shown = true
end
function methods:Hide()
    self.shown = false
end
function methods:IsShown()
    return self.shown ~= false
end
methods.IsVisible = methods.IsShown
function methods:SetText(v)
    self.text = v
end
function methods:GetText()
    return self.text
end
function methods:SetTexture(v)
    self.texture = v
end
function methods:GetTexture()
    return self.texture
end
function methods:SetAlpha(v)
    self.alpha = v
end
function methods:GetFrameLevel()
    return 1
end
function methods:GetCenter()
    return 500, 400
end
function methods:GetEffectiveScale()
    return 1
end
function methods:GetScale()
    return self.scale or 1
end
function methods:SetScale(v)
    self.scale = v
end
function methods:GetStringWidth()
    return string.len(self.text or "") * 6
end
function methods:GetStringHeight()
    return 14
end
function methods:GetChildren()
    return
end
function methods:GetRegions()
    return
end
function methods:GetZoom()
    return 2
end
function methods:SetValue(v)
    self.value = v
end
function methods:GetValue()
    return self.value or 0
end
function methods:SetChecked(v)
    self.checked = v
end
function methods:GetChecked()
    return self.checked
end
function methods:SetParent(p)
    self.parent = p
end
function methods:GetParent()
    return self.parent
end
for _, k in ipairs({
    "SetFont",
    "SetTextColor",
    "SetJustifyH",
    "SetTexCoord",
    "SetFrameStrata",
    "SetFrameLevel",
    "SetStatusBarTexture",
    "SetStatusBarColor",
    "SetMinMaxValues",
    "SetMovable",
    "RegisterForDrag",
    "EnableMouse",
    "SetBackdrop",
    "SetBackdropColor",
    "SetBackdropBorderColor",
    "SetVertexColor",
    "SetClampedToScreen",
    "SetHitRectInsets",
    "SetValueStep",
    "SetNormalTexture",
    "SetPushedTexture",
    "SetHighlightTexture",
    "RegisterForClicks",
    "SetID",
    "SetOwner",
    "AddLine",
    "SetToplevel",
    "StartMoving",
    "StopMovingOrSizing",
    "SetAlphaGradient",
    "SetJustifyV",
}) do
    methods[k] = function() end
end
function CreateFrame(kind, name, parent, template)
    local o = setmetatable({
        kind = kind,
        name = name,
        _name = name,
        parent = parent,
        scripts = {},
        events = {},
        children = {},
    }, { __index = methods })
    if name then
        _G[name] = o
    end
    if parent and parent.children then
        table.insert(parent.children, o)
    end
    table.insert(objects, o)
    if template == "OptionsSliderTemplate" and name then
        CreateFrame("FontString", name .. "Text")
        CreateFrame("FontString", name .. "Low")
        CreateFrame("FontString", name .. "High")
    end
    return o
end
function methods:CreateTexture(name)
    return CreateFrame("Texture", name, self)
end
function methods:CreateFontString(name)
    return CreateFrame("FontString", name, self)
end
UIParent = CreateFrame("Frame", "UIParent")
UIParent.width = 1920
UIParent.height = 1080
WorldFrame = CreateFrame("Frame", "WorldFrame")
Minimap = CreateFrame("Frame", "Minimap")
Minimap.width = 140
TargetFrame = CreateFrame("Frame", "TargetFrame")
TargetFrameHealthBar = CreateFrame("StatusBar", "TargetFrameHealthBar")
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "DEFAULT_CHAT_FRAME")
function DEFAULT_CHAT_FRAME:AddMessage(v) end
GameTooltip = CreateFrame("Frame", "GameTooltip")
NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }
UISpecialFrames = {}
function getglobal(k)
    return _G[k]
end
function UnitExists(unit)
    return unit == "player" or (unit == "target" and TARGET ~= nil)
end
function UnitName(unit)
    return unit == "target" and TARGET or "Player"
end
function UnitClassification()
    return "elite"
end
function UnitIsPlayer()
    return false
end
function UnitPlayerControlled()
    return false
end
function UnitLevel()
    return 12
end
function UnitHealth()
    return 6705
end
function UnitHealthMax()
    return 12200
end
function UnitIsDead()
    return false
end
function UnitDebuff()
    return nil
end
function UnitBuff()
    return nil
end
function UnitXP()
    return 12
end
function UnitXPMax()
    return 100
end
function UnitClass()
    return "Rogue", "ROGUE"
end
function GetMoney()
    return 100000
end
function GetCVar(k)
    return "0"
end
function SetCVar() end
function GetInventoryItemTexture()
    return nil
end
function GetInventorySlotInfo()
    return 1
end
function GetInventoryItemLink()
    return nil
end
function GetPlayerMapPosition()
    return 0.5, 0.5
end
function GetNumShapeshiftForms()
    return 0
end
function GetNumSkillLines()
    return 0
end
function GetNumTalentTabs()
    return 0
end
function SetMapToCurrentZone() end
function CameraZoomOut() end
function CameraZoomIn() end
function ShowUIPanel(f)
    f:Show()
end
function HideUIPanel(f)
    f:Hide()
end
function AZS_GetPhase()
    return AZS_RUN.ph
end
function AZS_GetRunTime()
    return AZS_RUN.t
end
function AZS_SetHudShown() end
function AZS_GetDebuffs()
    return {}
end
function AZS_GetMeter()
    return {}, 0, 0
end
function AZS_GetHealing()
    return {}, 0, 0
end
function AZS_GetBossMeter()
    return {}, 0, 0
end
function AZS_GetLairs()
    return {}
end
function AZS_RegisterBannerHandler(fn)
    BANNER_HANDLER = fn
end
AZS_ZONE = { zone = "feralas" }
AZS_RUN = { ph = "playing", t = 100, px = 10, py = 20 }
AZS_UNITS =
    { { kind = "guardian", id = 5001, name = "Brute gordunni", hp = 6705, hpm = 12200, state = 1 } }
AZS_CHESTS = { { x = 0, y = 0, mx = 0.3, my = 0.7 }, { x = 100, y = 100, mx = 0.2, my = 0.6 } }
AZS_LAIRS = {}
AZS_HEALING = {}
AZS_STATS = {}
AZS_BUFFS = {}
AZS_SPELLS = {}
AZS_TAKEN = {}
function fire(f, ev, a)
    event = ev
    arg1 = a
    this = f
    f.scripts.OnEvent()
end
function update(f, dt)
    NOW = NOW + dt
    arg1 = dt
    this = f
    f.scripts.OnUpdate()
end
function click(f)
    this = f
    f.scripts.OnClick()
end
function UnitIsDeadOrGhost()
    return false
end
function GetPlayerBuff()
    return -1
end
function UIParent:GetBackdrop()
    return {}
end
function methods:GetBackdrop()
    return {}
end

function methods:ClearLines() end
function methods:SetInventoryItem()
    return false
end

-- Exercise the actual compact action bar path, which requires the stock MainMenuBar.
MainMenuBar = CreateFrame("Frame", "MainMenuBar", UIParent)
function methods:GetBottom()
    return 10
end
function methods:GetAlpha()
    return self.alpha or 1
end
function methods:GetNumChildren()
    return 0
end

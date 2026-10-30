-- Synthetic presentation regressions. Never load player SavedVariables here.
local A = AzerothStats
local savedDB, savedRun, savedView = A.db, A.run, A.Copy(A.view)
local savedGlobal, savedPreview = AzerothStatsDB, A.themePreview
local savedLanguage = A.db.settings.language
local function check(ok, why)
    assert(ok, why)
    TEST_COUNT = TEST_COUNT + 1
end
local function hidePicker()
    -- The mock deliberately does not dispatch native OnHide automatically.
    A.ui.themeDialog:Hide()
    A.ui.themeDialog:GetScript("OnHide")()
end
local function click(control)
    this = control
    control:GetScript("OnClick")()
end

AzerothStatsDB, A.db, A.run = nil, nil, nil
check(A.InitDB(), "clean theme preference initializes")
check(A.db.settings.theme == "chroniques", "existing installs default to Chroniques")
check(
    A.ThemeId("unknown") == "chroniques" and A.ThemeId({}) == "chroniques",
    "unknown IDs cannot choose files"
)
local originalColors = A.theme.text
local statistics = A.Sign({ A.db.runs, A.db.totals, A.db.classes })
A.db.settings.language = "en"
A.view = { tab = 1, page = 1, mode = "damage", characterTab = "Spells" }
A.ToggleUI(true)
A.OpenThemePicker()
check(
    A.ui.themeDialog:IsShown() and A.ui.themeBlocker:IsShown(),
    "picker opens above owned blocker"
)
check(
    A.ui.themeDialog:GetFrameLevel() > A.window:GetFrameLevel(),
    "picker remains above main window"
)
local allocated = table.getn(objects)
for iteration = 1, 3 do
    for _, id in ipairs(A.themeOrder) do
        check(A.PreviewTheme(id), "valid visual preview: " .. id)
        check(
            A.activeTheme == id and A.theme.text == originalColors,
            "live references survive palette change"
        )
        check(A.db.settings.theme == "chroniques", "preview does not save preference")
        for tab = 1, table.getn(A.tabs) do
            A.view.tab, A.view.page = tab, 1
            A.RefreshUI()
        end
        check(
            A.Sign({ A.db.runs, A.db.totals, A.db.classes }) == statistics,
            "theme never changes run accounting"
        )
    end
end
-- Menus are lazily allocated by normal pages; count after their first visits.
allocated = table.getn(objects)
for _, id in ipairs(A.themeOrder) do
    A.PreviewTheme(id)
end
check(table.getn(objects) == allocated, "repeated previews allocate no widgets/textures")
check(not A.PreviewTheme("Interface\\OtherAddon\\arbitrary"), "preview rejects untrusted paths")
click(A.ui.themeDialog.options[3])
check(A.activeTheme == "atelier", "thumbnail click previews its own theme")
click(A.ui.themeDialog.cancel)
hidePicker()
check(A.activeTheme == "chroniques" and not A.themePreview, "cancel restores saved theme")
check(not A.ui.themeBlocker:IsShown(), "cancel removes blocker")
A.OpenThemePicker()
A.PreviewTheme("grimoire")
click(A.ui.themeDialog.apply)
hidePicker()
check(
    A.db.settings.theme == "grimoire" and A.activeTheme == "grimoire",
    "Apply alone persists choice"
)
check(
    A.theme.text[1] < A.theme.background[1] and A.theme.red[1] < 0.7,
    "light theme uses dark text and danger palette"
)
A.OpenThemePicker()
A.PreviewTheme("essentiel")
hidePicker()
check(
    A.activeTheme == "grimoire" and A.db.settings.theme == "grimoire",
    "Escape/window dismissal cancels draft"
)

-- Glyph reuse: a row changing from generic glyph to actual spell/class texture
-- must not be overwritten by the next global palette repaint.
local texture = A.window:CreateTexture(nil, "ARTWORK")
A.PaintedGlyph(texture, 2)
A.widgets.icon(texture, "Spell_Holy_Heal")
A.UseTheme("warcraft")
A.RepaintMaterials()
check(
    texture:GetTexture() == "Interface\\Icons\\Spell_Holy_Heal",
    "theme repaint preserves actual spell icon"
)
local glyphCount = table.getn(A.themeGlyphs)
A.PaintedGlyph(texture, 3)
A.widgets.icon(texture, "Spell_Holy_Heal")
A.PaintedGlyph(texture, 4)
check(table.getn(A.themeGlyphs) == glyphCount, "reused glyph registry stays bounded")

-- Readability: semantic body and secondary text retain WCAG 4.5 contrast at
-- full opacity; lower player-selected opacity depends on the game behind it.
local function linear(c)
    return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end
local function light(rgb)
    return 0.2126 * linear(rgb[1]) + 0.7152 * linear(rgb[2]) + 0.0722 * linear(rgb[3])
end
for _, id in ipairs(A.themeOrder) do
    local definition = A.themes[id]
    for _, role in ipairs({ "text", "muted" }) do
        for _, surface in ipairs({ "background", "panel" }) do
            local a, b = light(definition[role]), light(definition[surface])
            check(
                (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05) >= 4.5,
                "readable " .. id .. ": " .. role .. "/" .. surface
            )
        end
    end
end

-- Theme choice survives ordinary validation/reload; malformed/obsolete values
-- fall back without rejecting the rest of a valid database.
-- Font/asset/geometry regressions reported from native dev.1 screenshots.
A.OpenThemePicker()
A.PreviewTheme("grimoire")
for _, text in ipairs(A.ui.fonts) do
    check(
        text.shadowOffset[1] == 0 and text.shadowOffset[2] == 0 and text.shadowColor[4] == 0,
        "light-theme text has no inherited black offset shadow"
    )
    check(text.template == nil, "addon text does not inherit GameFontNormal styling")
end
check(
    A.ui.themeDialog.sampleCards[1].value.fullText == A.Format(A.db.totals.runs or 0),
    "large theme preview reads actual local run count, never a dummy 128"
)
A.PreviewTheme("warcraft")
check(not A.ui.nativeHeader:IsShown(), "no stretched red title button")
check(
    A.ui.brandGlyph:GetWidth() == 48 and A.ui.profileGlyph:GetWidth() == 32,
    "native class art stays at suitable size"
)
check(
    A.ui.brandGlyph:GetTexture() == "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
    "Warcraft profile reflects actual class instead of a fixed item"
)
A.PreviewTheme("atelier")
A.view.tab = 1
A.view.overviewStats = nil
A.RefreshUI()
check(
    A.ui.cards[1]:GetWidth() == 168 and A.ui.cards[2]:GetPoint() == "TOPLEFT",
    "architectural dashboard gives cards separate breathing space"
)
hidePicker()

local stored = A.Copy(A.db)
stored.settings.theme = "atelier"
AzerothStatsDB = stored
check(A.InitDB() and A.activeTheme == "atelier", "theme reload restores preference")
stored.settings.theme = { unexpected = true }
check(A.InitDB() and A.activeTheme == "chroniques", "malformed theme preference safely normalized")
for _, lg in ipairs(A.languages) do
    if lg[1] ~= "auto" then
        A.db.settings.language = lg[1]
        A.OpenThemePicker()
        for _, id in ipairs(A.themeOrder) do
            A.PreviewTheme(id)
        end
        hidePicker()
        check(
            A.ui.themeDialog.description.fullText ~= "Theme grimoire description",
            "localized descriptions: " .. lg[1]
        )
    end
end

AzerothStatsDB, A.db, A.run, A.view = savedGlobal, savedDB, savedRun, savedView
A.themePreview = savedPreview
A.db.settings.language = savedLanguage
A.ApplyUI()
A.RefreshUI()
print("FIVE THEME PRESENTATION REGRESSIONS PASSED", TEST_COUNT)

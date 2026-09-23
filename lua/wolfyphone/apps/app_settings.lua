-- Settings app: accent color, notification sounds toggle, about section.
-- Preferences persist client-side via the cookie library.

WolfyPhone.RegisterApp({
    id = "settings",
    name = "Settings",
    color = Color(120, 120, 128),
    glyph = "S",
    order = 90,
})

if SERVER then return end

local C = WolfyPhone.Colors

local ACCENTS = {
    { name = "iOS Blue",   color = Color(0, 122, 255) },
    { name = "Purple",     color = Color(175, 82, 222) },
    { name = "Pink",       color = Color(255, 55, 95) },
    { name = "Green",      color = Color(52, 199, 89) },
    { name = "Orange",     color = Color(255, 159, 10) },
    { name = "Teal",       color = Color(90, 200, 250) },
}

-- apply saved accent on load
do
    local saved = cookie.GetString("wolfyphone_accent")
    if saved then
        for _, a in ipairs(ACCENTS) do
            if a.name == saved then
                WolfyPhone.Colors.Accent = a.color
                WolfyPhone.Colors.BubbleOut = a.color
            end
        end
    end
end

local function buildPanel(body)
    local scroll = vgui.Create("DScrollPanel", body)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil

    local function header(text)
        local h = scroll:Add("DLabel")
        h:Dock(TOP)
        h:DockMargin(14, 14, 14, 4)
        h:SetTall(18)
        h:SetFont("WolfyPhone.Small")
        h:SetTextColor(C.TextDim)
        h:SetText(string.upper(text))
    end

    header("Accent Color")

    local grid = scroll:Add("DIconLayout")
    grid:Dock(TOP)
    grid:DockMargin(12, 0, 12, 0)
    grid:SetSpaceX(10)
    grid:SetSpaceY(10)
    grid:SetTall(64)

    for _, a in ipairs(ACCENTS) do
        local sw = grid:Add("DButton")
        sw:SetSize(50, 50)
        sw:SetText("")
        sw.accent = a
        sw.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, a.color)
            if C.Accent == a.color then
                draw.RoundedBox(10, 4, 4, w - 8, h - 8, Color(255, 255, 255, 60))
            end
        end
        sw.DoClick = function(self)
            WolfyPhone.Colors.Accent = self.accent.color
            WolfyPhone.Colors.BubbleOut = self.accent.color
            cookie.Set("wolfyphone_accent", self.accent.name)
            WolfyPhone.UI.Refresh()
        end
    end

    header("Sounds")

    local soundsOn = cookie.GetString("wolfyphone_sounds", "1") == "1"
    local tog = scroll:Add("DButton")
    tog:Dock(TOP)
    tog:DockMargin(12, 4, 12, 4)
    tog:SetTall(42)
    tog:SetText("")
    tog.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(36, 38, 46))
        draw.SimpleText("Notification sounds", "WolfyPhone.Body",
            12, h / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local on = cookie.GetString("wolfyphone_sounds", "1") == "1"
        draw.RoundedBox(12, w - 58, h / 2 - 12, 46, 24,
            on and C.Green or Color(60, 62, 70))
        draw.RoundedBox(10, w - 58 + (on and 24 or 2), h / 2 - 10, 20, 20,
            color_white)
    end
    tog.DoClick = function()
        soundsOn = not soundsOn
        cookie.Set("wolfyphone_sounds", soundsOn and "1" or "0")
    end

    header("About")

    local about = scroll:Add("DPanel")
    about:Dock(TOP)
    about:DockMargin(12, 4, 12, 4)
    about:SetTall(88)
    about.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(36, 38, 46))
        draw.SimpleText(WolfyPhone.Config.DeviceName, "WolfyPhone.Body",
            12, 16, C.Text)
        draw.SimpleText("Version " .. WolfyPhone.Version, "WolfyPhone.Small",
            12, 38, C.TextDim)
        draw.SimpleText("Gamemode: " .. engine.ActiveGamemode(), "WolfyPhone.Small",
            12, 56, C.TextDim)
        if WolfyPhone.Util.HasDarkRP() then
            draw.SimpleText("DarkRP integration active", "WolfyPhone.Small",
                12, 72, C.Green)
        end
    end
end

WolfyPhone.Apps.settings.OnOpen = buildPanel

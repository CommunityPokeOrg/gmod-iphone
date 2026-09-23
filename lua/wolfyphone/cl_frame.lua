-- Client UI: the phone shell (bezel, screen, status bar, home grid, nav bar,
-- toast banners) and the app container that hosts each app's OnOpen panel.

local Cfg = WolfyPhone.Config
local C = WolfyPhone.Colors

WolfyPhone.UI = WolfyPhone.UI or {}
local UI = WolfyPhone.UI

-- ---- fonts ---------------------------------------------------------------

surface.CreateFont("WolfyPhone.Time", {
    font = "Tahoma", size = 44, weight = 300,
})
surface.CreateFont("WolfyPhone.Title", {
    font = "Tahoma", size = 22, weight = 600,
})
surface.CreateFont("WolfyPhone.AppName", {
    font = "Tahoma", size = 13, weight = 500,
})
surface.CreateFont("WolfyPhone.Glyph", {
    font = "Tahoma", size = 26, weight = 700,
})
surface.CreateFont("WolfyPhone.Body", {
    font = "Tahoma", size = 15, weight = 500,
})
surface.CreateFont("WolfyPhone.Small", {
    font = "Tahoma", size = 12, weight = 500,
})
surface.CreateFont("WolfyPhone.Status", {
    font = "Tahoma", size = 13, weight = 700,
})

-- ---- state ---------------------------------------------------------------

UI.Frame = nil
UI.Content = nil
UI.Screen = nil
UI.NavBar = nil
UI.StatusBar = nil
UI.AppId = nil            -- currently open app id (nil = home screen)
UI.Toasts = {}
UI._viewingConvo = nil    -- set by the Messages app

local BEZEL = 14          -- bezel thickness around the screen
local STATUS_H = 24
local NAV_H = 44

function UI.CurrentApp()
    return UI.AppId
end

function UI.MessagesViewing()
    return UI._viewingConvo
end

-- ---- painting helpers ----------------------------------------------------

local function paintWallpaper(panel, w, h)
    draw.RoundedBox(0, 0, 0, w, h, C.Wallpaper)
    -- subtle gradient bands for depth
    surface.SetDrawColor(30, 34, 52, 120)
    surface.DrawRect(0, 0, w, h * 0.35)
    surface.SetDrawColor(14, 16, 26, 160)
    surface.DrawRect(0, h * 0.65, w, h * 0.35)
end

local function paintStatusBar(panel, w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 90))
    draw.SimpleText(WolfyPhone.Util.FormatClock(),
        "WolfyPhone.Status", 10, h / 2, C.StatusBar, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Cfg.CarrierName,
        "WolfyPhone.Status", w / 2, h / 2, C.StatusBar, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    -- battery pill
    local bw, bh = 26, 12
    local bx, by = w - bw - 10, (h - bh) / 2
    draw.RoundedBox(3, bx, by, bw, bh, Color(255, 255, 255, 40))
    draw.RoundedBox(3, bx + 2, by + 2, bw - 4, bh - 4, C.Green)
end

-- ---- toast banners -------------------------------------------------------

function UI.Toast(appId, title, body)
    local app = WolfyPhone.GetApp(appId)
    if app and isfunction(app.OnNotify) then
        pcall(app.OnNotify, { title = title, body = body })
    end
    if not IsValid(UI.Screen) then
        -- Phone closed: still surface it once it reopens via unread state.
        return
    end

    local sw = UI.Screen:GetWide()
    local toast = vgui.Create("DPanel", UI.Screen)
    toast:SetSize(sw - 16, 52)
    toast:SetPos(8, -60)
    toast.title = title
    toast.body = string.sub(body or "", 1, 80)
    toast.iconColor = (app and app.color) or C.Accent
    toast.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(30, 30, 36, 240))
        draw.RoundedBox(6, 8, 12, 28, 28, self.iconColor)
        draw.SimpleText(string.upper(self.title or ""),
            "WolfyPhone.Small", 44, 14, C.TextDim)
        draw.SimpleText(self.body or "",
            "WolfyPhone.Body", 44, 32, C.Text)
    end
    toast:MoveTo(8, STATUS_H + 6, 0.25, 0, -1)
    table.insert(UI.Toasts, toast)

    timer.Simple(4, function()
        if IsValid(toast) then
            toast:MoveTo(8, -60, 0.25, 0, -1, function()
                if IsValid(toast) then toast:Remove() end
            end)
        end
    end)
end

-- ---- home screen ---------------------------------------------------------

local function buildHome(content)
    content:Clear()
    content.Paint = function(_, w, h)
        -- big clock at top
        draw.SimpleText(WolfyPhone.Util.FormatClock(),
            "WolfyPhone.Time", w / 2, 52, C.Text, TEXT_ALIGN_CENTER)
        draw.SimpleText(os.date("%A, %B %d"),
            "WolfyPhone.Body", w / 2, 84, C.TextDim, TEXT_ALIGN_CENTER)
        local unread = WolfyPhone.TotalUnread()
        if unread > 0 then
            draw.SimpleText(unread .. " unread message" .. (unread == 1 and "" or "s"),
                "WolfyPhone.Small", w / 2, 106, C.Accent, TEXT_ALIGN_CENTER)
        end
    end

    local grid = vgui.Create("DIconLayout", content)
    grid:Dock(FILL)
    grid:DockMargin(24, 120, 24, 12)
    grid:SetSpaceX(18)
    grid:SetSpaceY(16)

    for _, appId in ipairs(WolfyPhone.SortedApps()) do
        local app = WolfyPhone.GetApp(appId)
        local cell = grid:Add("DButton")
        cell:SetSize(64, 86)
        cell:SetText("")
        cell.app = app
        cell.Paint = function(self, w, h)
            local hover = self:IsHovered()
            local col = self.app.color or C.Accent
            draw.RoundedBox(14, 0, 0, 64, 64,
                Color(col.r, col.g, col.b, hover and 255 or 225))
            draw.SimpleText(self.app.glyph,
                "WolfyPhone.Glyph", 32, 32, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(self.app.name,
                "WolfyPhone.AppName", 32, 76, C.Text, TEXT_ALIGN_CENTER)
            -- unread badge on the Messages app
            if self.app.id == "messages" then
                local n = WolfyPhone.TotalUnread()
                if n > 0 then
                    draw.RoundedBox(9, 46, -4, 20, 20, C.Red)
                    draw.SimpleText(tostring(n), "WolfyPhone.Small", 56, 6,
                        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
        cell.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            UI.OpenApp(appId)
        end
    end
end

-- ---- app hosting ---------------------------------------------------------

function UI.OpenApp(appId)
    local app = WolfyPhone.GetApp(appId)
    if not app or not IsValid(UI.Content) then return end
    UI.AppId = appId

    UI.Content:Clear()
    UI.Content.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.Screen)
    end

    -- header bar
    local header = vgui.Create("DPanel", UI.Content)
    header:Dock(TOP)
    header:SetTall(40)
    header.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
        draw.SimpleText(app.name, "WolfyPhone.Title",
            w / 2, h / 2, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local back = vgui.Create("DButton", header)
    back:Dock(LEFT)
    back:SetWide(70)
    back:SetText("")
    back.Paint = function(self, w, h)
        local col = self:IsHovered() and C.Accent or C.TextDim
        draw.SimpleText("< Home", "WolfyPhone.Body",
            10, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    back.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        UI.GoHome()
    end

    local body = vgui.Create("DPanel", UI.Content)
    body:Dock(FILL)
    body.Paint = nil

    if isfunction(app.OnOpen) then
        local ok, err = pcall(app.OnOpen, body)
        if not ok then
            ErrorNoHalt("[WolfyPhone] app '" .. appId .. "' OnOpen failed: " .. tostring(err) .. "\n")
            local lbl = vgui.Create("DLabel", body)
            lbl:Dock(TOP)
            lbl:SetTall(40)
            lbl:SetContentAlignment(5)
            lbl:SetText("This app failed to open.")
            lbl:SetTextColor(C.Red)
        end
    end
end

function UI.GoHome()
    local app = UI.AppId and WolfyPhone.GetApp(UI.AppId)
    if app and isfunction(app.OnClose) then
        pcall(app.OnClose)
    end
    UI.AppId = nil
    UI._viewingConvo = nil
    if IsValid(UI.Content) then
        buildHome(UI.Content)
    end
end

-- Live-refresh hook for apps: WolfyPhone.UI.OnRefresh[appId] = fn(panel)
UI.OnRefresh = UI.OnRefresh or {}

function UI.Refresh()
    if not IsValid(UI.Frame) then return end
    if UI.AppId then
        local fn = UI.OnRefresh[UI.AppId]
        if isfunction(fn) then pcall(fn) end
    else
        -- keep home clock/unread fresh
        buildHome(UI.Content)
    end
end

-- ---- open / close --------------------------------------------------------

function UI.Open()
    if IsValid(UI.Frame) then UI.Frame:Remove() end

    local pw, ph = Cfg.PhoneWidth, Cfg.PhoneHeight
    local frame = vgui.Create("DFrame")
    frame:SetSize(pw + BEZEL * 2, ph + BEZEL * 2)
    frame:SetPos(ScrW() - frame:GetWide() - 60, (ScrH() - frame:GetTall()) / 2)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:SetDeleteOnClose(false)
    frame:SetVisible(true)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame.app = nil

    frame.Paint = function(self, w, h)
        -- phone body
        draw.RoundedBox(24, 0, 0, w, h, C.Bezel)
        draw.RoundedBox(24, 0, 0, w, 2, Color(255, 255, 255, 24)) -- top glint
        -- side buttons
        draw.RoundedBox(2, -3, 90, 3, 26, C.Bezel)
        draw.RoundedBox(2, -3, 124, 3, 40, C.Bezel)
        draw.RoundedBox(2, w, 100, 3, 40, C.Bezel)
    end

    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            WolfyPhone.ClosePhone()
        end
    end

    frame.OnRemove = function()
        UI.Frame = nil
        UI.Content = nil
        UI.Screen = nil
        UI.AppId = nil
        UI._viewingConvo = nil
        for _, t in ipairs(UI.Toasts) do
            if IsValid(t) then t:Remove() end
        end
        UI.Toasts = {}
    end

    UI.Frame = frame

    -- screen
    local screen = vgui.Create("DPanel", frame)
    screen:SetPos(BEZEL, BEZEL)
    screen:SetSize(pw, ph)
    screen.Paint = paintWallpaper
    UI.Screen = screen

    local status = vgui.Create("DPanel", screen)
    status:SetPos(0, 0)
    status:SetSize(pw, STATUS_H)
    status.Paint = paintStatusBar
    UI.StatusBar = status

    local nav = vgui.Create("DPanel", screen)
    nav:SetPos(0, ph - NAV_H)
    nav:SetSize(pw, NAV_H)
    nav.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
        -- home pill
        draw.RoundedBox(10, w / 2 - 40, h / 2 - 5, 80, 10, Color(255, 255, 255, 140))
    end
    UI.NavBar = nav

    local homeBtn = vgui.Create("DButton", nav)
    homeBtn:Dock(FILL)
    homeBtn:SetText("")
    homeBtn.Paint = nil
    homeBtn.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        UI.GoHome()
    end

    local content = vgui.Create("DPanel", screen)
    content:SetPos(0, STATUS_H)
    content:SetSize(pw, ph - STATUS_H - NAV_H)
    content.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.Screen)
    end
    UI.Content = content

    buildHome(content)

    -- keep the clock/status fresh
    timer.Create("WolfyPhone.Clock", 10, 0, function()
        if IsValid(UI.StatusBar) then UI.StatusBar:InvalidateLayout() end
    end)
end

function UI.Close()
    if IsValid(UI.Frame) then
        UI.Frame:Remove()
    end
end

-- Center the phone when the resolution changes.
hook.Add("OnScreenSizeChanged", "WolfyPhone.Resize", function()
    if IsValid(UI.Frame) then
        UI.Frame:SetPos(ScrW() - UI.Frame:GetWide() - 60,
            (ScrH() - UI.Frame:GetTall()) / 2)
    end
end)

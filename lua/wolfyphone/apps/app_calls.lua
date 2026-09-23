-- Calls app: contact list to dial, incoming-call accept/decline, active
-- call screen with live duration. Transport/state machine is in sv_core.lua;
-- voice routing is handled by the PlayerCanHearPlayersVoice hook there.

WolfyPhone.RegisterApp({
    id = "calls",
    name = "Phone",
    color = Color(52, 199, 89),
    glyph = "P",
    order = 20,
})

if SERVER then return end

local L = WolfyPhone.Local
local C = WolfyPhone.Colors

local activePanel

local function button(parent, dock, text, col, onClick)
    local b = vgui.Create("DButton", parent)
    b:Dock(dock)
    b:DockMargin(16, 6, 16, 6)
    b:SetTall(44)
    b:SetText("")
    b.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, self:IsHovered() and col or Color(
            math.max(col.r - 30, 0), math.max(col.g - 30, 0), math.max(col.b - 30, 0)))
        draw.SimpleText(text, "WolfyPhone.Body", w / 2, h / 2,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = onClick
    return b
end

local function buildCallScreen(body, call)
    body:Clear()

    local info = vgui.Create("DPanel", body)
    info:Dock(TOP)
    info:SetTall(140)
    info.Paint = function(_, w, h)
        draw.RoundedBox(28, w / 2 - 32, 18, 64, 64, C.BubbleIn)
        draw.SimpleText(string.upper(string.sub(call.otherName, 1, 1)),
            "WolfyPhone.Glyph", w / 2, 50, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(call.otherName, "WolfyPhone.Title",
            w / 2, 108, C.Text, TEXT_ALIGN_CENTER)
    end

    local status = vgui.Create("DPanel", body)
    status:Dock(TOP)
    status:SetTall(36)
    status.Paint = function(_, w, h)
        local label
        if call.state == "ringing" then
            label = "Calling..."
        elseif call.state == "incoming" then
            label = "Incoming call"
        else
            label = WolfyPhone.Util.FormatDuration(os.time() - (call.since or os.time()))
        end
        draw.SimpleText(label, "WolfyPhone.Body", w / 2, h / 2,
            C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    status.Think = function()
        if call.state == "active" then status:InvalidateLayout() end
    end

    local controls = vgui.Create("DPanel", body)
    controls:Dock(BOTTOM)
    controls:SetTall(120)
    controls.Paint = nil

    if call.state == "incoming" then
        button(controls, BOTTOM, "Decline", C.Red, function()
            WolfyPhone.CallAction("decline", call.otherKey)
        end)
        button(controls, BOTTOM, "Accept", C.Green, function()
            WolfyPhone.CallAction("accept", call.otherKey)
        end)
    else
        button(controls, BOTTOM, "Hang Up", C.Red, function()
            WolfyPhone.CallAction("end_call", call.otherKey)
        end)
    end
end

local function buildDialList(body)
    body:Clear()

    local list = vgui.Create("DScrollPanel", body)
    list:Dock(FILL)
    local sbar = list:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 60))
    end

    local me = WolfyPhone.Util.PlayerKey(LocalPlayer())
    local shown = 0
    for _, ply in ipairs(player.GetAll()) do
        local key = WolfyPhone.Util.PlayerKey(ply)
        if key ~= me then
            shown = shown + 1
            local row = list:Add("DButton")
            row:Dock(TOP)
            row:DockMargin(8, 4, 8, 0)
            row:SetTall(48)
            row:SetText("")
            row.key = key
            row.name = WolfyPhone.Util.DisplayName(ply)
            row.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h,
                    self:IsHovered() and Color(50, 52, 62) or Color(36, 38, 46))
                draw.RoundedBox(16, 8, 8, 32, 32, C.BubbleIn)
                draw.SimpleText(string.upper(string.sub(self.name, 1, 1)),
                    "WolfyPhone.Body", 24, 24, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(self.name, "WolfyPhone.Body", 50, h / 2,
                    C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Call", "WolfyPhone.Small", w - 14, h / 2,
                    C.Green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function()
                WolfyPhone.CallAction("start", key)
                surface.PlaySound("buttons/button15.wav")
            end
        end
    end

    if shown == 0 then
        local lbl = vgui.Create("DLabel", list)
        lbl:Dock(TOP)
        lbl:SetTall(60)
        lbl:SetContentAlignment(5)
        lbl:SetFont("WolfyPhone.Body")
        lbl:SetTextColor(C.TextDim)
        lbl:SetText("No other players online")
    end
end

local function buildPanel(body)
    activePanel = vgui.Create("DPanel", body)
    activePanel:Dock(FILL)
    activePanel.Paint = nil

    local function render()
        if not IsValid(activePanel) then return end
        if L.call and L.call.state ~= "idle" then
            buildCallScreen(activePanel, L.call)
        else
            buildDialList(activePanel)
        end
    end

    render()

    WolfyPhone.UI.OnRefresh.calls = render
end

WolfyPhone.Apps.calls.OnOpen = buildPanel
WolfyPhone.Apps.calls.OnClose = function()
    WolfyPhone.UI.OnRefresh.calls = nil
    activePanel = nil
end

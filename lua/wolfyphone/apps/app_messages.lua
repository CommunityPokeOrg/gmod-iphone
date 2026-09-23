-- Messages app: conversation list -> chat thread -> send.
-- Client UI lives here; message transport/validation lives in sv_core.lua.

WolfyPhone.RegisterApp({
    id = "messages",
    name = "Messages",
    color = Color(52, 199, 89),
    glyph = "M",
    order = 10,
})

if SERVER then return end

local L = WolfyPhone.Local
local C = WolfyPhone.Colors

local convoPanel -- current thread view, if open

local function buildConvoList(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 60))
    end

    local convos = WolfyPhone.Conversations()
    if #convos == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:Dock(TOP)
        lbl:SetTall(60)
        lbl:SetContentAlignment(5)
        lbl:SetText("No conversations yet")
        lbl:SetTextColor(C.TextDim)
        lbl:SetFont("WolfyPhone.Body")
    end

    for _, key in ipairs(convos) do
        local convo = L.inbox[key]
        local last = convo[#convo]
        local row = scroll:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(8, 4, 8, 0)
        row:SetTall(52)
        row:SetText("")

        row.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(50, 52, 62) or Color(36, 38, 46)
            draw.RoundedBox(8, 0, 0, w, h, bg)
            -- avatar circle
            draw.RoundedBox(16, 8, 10, 32, 32, C.BubbleIn)
            draw.SimpleText(string.upper(string.sub(WolfyPhone.NameFor(key), 1, 1)),
                "WolfyPhone.Body", 24, 26, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(WolfyPhone.NameFor(key),
                "WolfyPhone.Body", 50, 12, C.Text)
            draw.SimpleText(string.sub(last and last.text or "", 1, 34),
                "WolfyPhone.Small", 50, 32, C.TextDim)
            if last and last.ts then
                draw.SimpleText(WolfyPhone.Util.FormatClock(last.ts),
                    "WolfyPhone.Small", w - 10, 12, C.TextDim, TEXT_ALIGN_RIGHT)
            end
            local n = L.unread[key] or 0
            if n > 0 then
                draw.RoundedBox(9, w - 26, h - 26, 18, 18, C.Accent)
                draw.SimpleText(tostring(n), "WolfyPhone.Small", w - 17, h - 17,
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        row.DoClick = function()
            WolfyPhone.MarkRead(key)
            WolfyPhone.UI._viewingConvo = key
            surface.PlaySound("buttons/button15.wav")
            if IsValid(convoPanel) then
                convoPanel:ShowThread(key)
            end
        end
    end
end

local function addBubble(scroll, msg)
    local mine = msg.mine or false
    local row = scroll:Add("DPanel")
    row:Dock(TOP)
    row:DockMargin(8, 2, 8, 2)
    row:SetPaintBackgroundEnabled(false)

    local lbl = vgui.Create("DLabel", row)
    lbl:SetFont("WolfyPhone.Body")
    lbl:SetTextColor(color_white)
    lbl:SetText(msg.text)
    lbl:SetWrap(true)
    lbl:SetAutoStretchVertical(true)
    row.lbl = lbl

    row.Paint = function(self, w, h)
        local lw, lh = lbl:GetWide(), lbl:GetTall()
        local col = mine and C.BubbleOut or C.BubbleIn
        if mine then
            draw.RoundedBox(12, w - lw - 20, 0, lw + 16, lh + 12, col)
        else
            draw.RoundedBox(12, 4, 0, lw + 16, lh + 12, col)
        end
    end

    row.PerformLayout = function(self, w)
        local lw = math.min(w * 0.68, w - 40)
        lbl:SetWide(lw)
        lbl:InvalidateLayout(true)
        if mine then
            lbl:SetPos(w - lw - 12, 6)
        else
            lbl:SetPos(12, 6)
        end
        self:SetTall(lbl:GetTall() + 12)
    end

    return row
end

local function buildThread(parent, key)
    parent:Clear()

    -- thread header strip
    local head = vgui.Create("DPanel", parent)
    head:Dock(TOP)
    head:SetTall(30)
    head.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 80))
        draw.SimpleText(WolfyPhone.NameFor(key), "WolfyPhone.Body",
            w / 2, h / 2, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local backBtn = vgui.Create("DButton", head)
    backBtn:Dock(LEFT)
    backBtn:SetWide(56)
    backBtn:SetText("")
    backBtn.Paint = function(self, w, h)
        draw.SimpleText("< Back", "WolfyPhone.Small", 8, h / 2,
            self:IsHovered() and C.Accent or C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    backBtn.DoClick = function()
        WolfyPhone.UI._viewingConvo = nil
        convoPanel:ShowList()
    end

    -- bubbles
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 60))
    end

    for _, msg in ipairs(L.inbox[key] or {}) do
        addBubble(scroll, msg)
    end
    timer.Simple(0, function()
        if IsValid(scroll) then
            local vbar = scroll:GetVBar()
            vbar:SetScroll(vbar.CanvasSize or 99999)
        end
    end)

    -- input bar
    local bar = vgui.Create("DPanel", parent)
    bar:Dock(BOTTOM)
    bar:SetTall(38)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
    end

    local entry = vgui.Create("DTextEntry", bar)
    entry:Dock(FILL)
    entry:DockMargin(6, 5, 2, 5)
    entry:SetFont("WolfyPhone.Body")
    entry:SetPlaceholderText("iMessage")
    entry:SetPlaceholderColor(C.TextDim)
    entry:SetTextColor(C.Text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 42, 50))
        self:DrawTextEntryText(C.Text, C.Accent, C.Text)
    end

    local send = vgui.Create("DButton", bar)
    send:Dock(RIGHT)
    send:DockMargin(2, 5, 6, 5)
    send:SetWide(52)
    send:SetText("")

    local function doSend()
        local text = WolfyPhone.Util.SanitizeMessage(entry:GetText())
        if #text == 0 then return end
        WolfyPhone.SendMessage(key, text)
        entry:SetText("")
        entry:RequestFocus()
    end

    send.Paint = function(self, w, h)
        local col = self:IsHovered() and C.Accent or C.BubbleIn
        draw.RoundedBox(8, 0, 0, w, h, col)
        draw.SimpleText("Send", "WolfyPhone.Small", w / 2, h / 2,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    send.DoClick = doSend
    entry.OnEnter = doSend
end

local function buildPanel(body)
    local panel = vgui.Create("DPanel", body)
    panel:Dock(FILL)
    panel.Paint = nil

    function panel:ShowList()
        self:Clear()
        WolfyPhone.UI._viewingConvo = nil
        buildConvoList(self)
    end

    function panel:ShowThread(key)
        buildThread(self, key)
        WolfyPhone.UI._viewingConvo = key
    end

    -- restore the thread if one was open
    if WolfyPhone.UI._viewingConvo then
        panel:ShowThread(WolfyPhone.UI._viewingConvo)
    else
        panel:ShowList()
    end

    convoPanel = panel

    -- new-message button
    local newBtn = vgui.Create("DButton", body)
    newBtn:Dock(BOTTOM)
    newBtn:SetTall(34)
    newBtn:SetText("")
    newBtn.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 110))
        draw.SimpleText("+ New Message", "WolfyPhone.Body",
            w / 2, h / 2, self:IsHovered() and C.Accent or C.Text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    newBtn.DoClick = function()
        -- simple recipient picker: a dropdown of online players
        local menu = DermaMenu()
        for _, ply in ipairs(player.GetAll()) do
            local k = WolfyPhone.Util.PlayerKey(ply)
            menu:AddOption(WolfyPhone.Util.DisplayName(ply), function()
                WolfyPhone.UI._viewingConvo = k
                panel:ShowThread(k)
            end)
        end
        menu:Open()
    end
end

WolfyPhone.Apps.messages.OnOpen = buildPanel
WolfyPhone.Apps.messages.OnClose = function()
    convoPanel = nil
    WolfyPhone.UI._viewingConvo = nil
end

WolfyPhone.UI.OnRefresh.messages = function()
    if not IsValid(convoPanel) then return end
    if WolfyPhone.UI._viewingConvo then
        convoPanel:ShowThread(WolfyPhone.UI._viewingConvo)
    else
        convoPanel:ShowList()
    end
end

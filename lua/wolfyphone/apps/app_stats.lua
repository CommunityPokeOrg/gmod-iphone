-- Wallet app: DarkRP money/job/salary card when DarkRP is installed,
-- generic team/score card in sandbox. Server keeps the client's cached
-- fields fresh via OnDarkRPVarChanged / periodic sync.

WolfyPhone.RegisterApp({
    id = "wallet",
    name = "Wallet",
    color = Color(255, 159, 10),
    glyph = "W",
    order = 40,
})

if SERVER then
    -- Registered unconditionally: if DarkRP is installed it fires
    -- OnDarkRPVarChanged, on other gamemodes the hook simply never runs.
    hook.Add("OnDarkRPVarChanged", "WolfyPhone.Wallet", function(ply, var)
        if var == "money" or var == "job" or var == "salary" then
            WolfyPhone.Server.Sync(ply)
        end
    end)
    return
end

local C = WolfyPhone.Colors
local L = WolfyPhone.Local

local function row(parent, label, value)
    local p = vgui.Create("DPanel", parent)
    p:Dock(TOP)
    p:DockMargin(12, 5, 12, 0)
    p:SetTall(46)
    p.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(36, 38, 46))
        draw.SimpleText(label, "WolfyPhone.Small", 12, h / 2,
            C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "WolfyPhone.Body", w - 12, h / 2,
            C.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return p
end

local function buildPanel(body)
    local isDarkRP = WolfyPhone.Util.HasDarkRP()

    local hero = vgui.Create("DPanel", body)
    hero:Dock(TOP)
    hero:DockMargin(12, 10, 12, 6)
    hero:SetTall(110)
    hero.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(255, 159, 10, 200))
        draw.SimpleText(isDarkRP and "Balance" or "Score", "WolfyPhone.Small",
            w / 2, 26, color_white, TEXT_ALIGN_CENTER)
        local big = isDarkRP
            and (DarkRP.formatMoney and DarkRP.formatMoney(tonumber(L.wallet) or 0)
                 or ("$" .. tostring(L.wallet)))
            or tostring(L.wallet)
        draw.SimpleText(big, "WolfyPhone.Time", w / 2, 62,
            color_white, TEXT_ALIGN_CENTER)
    end

    row(body, "Job", L.job)
    row(body, "Gamemode", isDarkRP and "DarkRP" or engine.ActiveGamemode())
    row(body, "Players", tostring(#player.GetAll()))

    local note = vgui.Create("DLabel", body)
    note:Dock(TOP)
    note:DockMargin(12, 14, 12, 0)
    note:SetTall(50)
    note:SetWrap(true)
    note:SetAutoStretchVertical(true)
    note:SetFont("WolfyPhone.Small")
    note:SetTextColor(C.TextDim)
    note:SetText(isDarkRP
        and "Wallet syncs automatically when your money or job changes."
        or "DarkRP not detected — showing your sandbox score instead.")

    WolfyPhone.RequestSync() -- fresh numbers on open
end

WolfyPhone.Apps.wallet.OnOpen = buildPanel

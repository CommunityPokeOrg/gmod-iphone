-- Contacts app: online players plus client-persisted favorites
-- (garrysmod/data/wolfyphone_contacts.json on the client).

WolfyPhone.RegisterApp({
    id = "contacts",
    name = "Contacts",
    color = Color(90, 200, 250),
    glyph = "C",
    order = 30,
})

if SERVER then return end

local C = WolfyPhone.Colors
local STORE = "wolfyphone_contacts.json"

local function loadFavorites()
    if not file.Exists(STORE, "DATA") then return {} end
    local ok, data = pcall(util.JSONToTable, file.Read(STORE, "DATA") or "")
    return (ok and istable(data)) and data or {}
end

local function saveFavorites(favs)
    file.Write(STORE, util.TableToJSON(favs))
end

local function buildPanel(body)
    local list = vgui.Create("DScrollPanel", body)
    list:Dock(FILL)
    local sbar = list:GetVBar()
    sbar:SetWide(4)
    sbar.Paint = nil
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 60))
    end

    local favs = loadFavorites()
    local me = WolfyPhone.Util.PlayerKey(LocalPlayer())

    -- favorites first, then everyone else
    local entries = {}
    for _, ply in ipairs(player.GetAll()) do
        local key = WolfyPhone.Util.PlayerKey(ply)
        if key ~= me then
            table.insert(entries, { ply = ply, key = key,
                name = WolfyPhone.Util.DisplayName(ply), fav = favs[key] and true or false })
        end
    end
    -- also list known-but-offline favorites so the section isn't empty
    for key in pairs(favs) do
        if not WolfyPhone.Util.FindPlayerByKey(key) then
            table.insert(entries, { ply = nil, key = key,
                name = WolfyPhone.NameFor(key), fav = true, offline = true })
        end
    end
    table.sort(entries, function(a, b)
        if a.fav ~= b.fav then return a.fav end
        if a.offline ~= b.offline then return not a.offline end
        return a.name < b.name
    end)

    for _, e in ipairs(entries) do
        local row = list:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(8, 4, 8, 0)
        row:SetTall(52)
        row:SetText("")

        row.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(50, 52, 62) or Color(36, 38, 46)
            if e.offline then bg = Color(28, 29, 36) end
            draw.RoundedBox(8, 0, 0, w, h, bg)
            draw.RoundedBox(16, 8, 10, 32, 32, e.fav and C.Accent or C.BubbleIn)
            draw.SimpleText(string.upper(string.sub(e.name, 1, 1)),
                "WolfyPhone.Body", 24, 26, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(e.name, "WolfyPhone.Body", 50, 14,
                e.offline and C.TextDim or C.Text)
            draw.SimpleText(e.offline and "offline" or "online",
                "WolfyPhone.Small", 50, 34,
                e.offline and C.TextDim or C.Green)
            draw.SimpleText(e.fav and "*" or "+", "WolfyPhone.Title",
                w - 14, h / 2, e.fav and Color(255, 214, 10) or C.TextDim,
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- click the row: quick actions; the star area toggles favorite
        row.DoClick = function(self)
            local x = self:CursorPos()
            if x > self:GetWide() - 44 then
                favs[e.key] = not favs[e.key] and true or nil
                saveFavorites(favs)
                WolfyPhone.UI.Refresh()
                return
            end
            if e.offline then return end
            local menu = DermaMenu()
            menu:AddOption("Message " .. e.name, function()
                WolfyPhone.UI._viewingConvo = e.key
                WolfyPhone.UI.OpenApp("messages")
            end)
            menu:AddOption("Call " .. e.name, function()
                WolfyPhone.CallAction("start", e.key)
                WolfyPhone.UI.OpenApp("calls")
            end)
            menu:Open()
        end
    end
end

WolfyPhone.Apps.contacts.OnOpen = buildPanel

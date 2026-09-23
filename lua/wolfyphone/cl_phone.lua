-- Client state: local copy of the inbox, call state, open/close lifecycle,
-- inbound net receivers, and the bindable toggle commands.

local Util = WolfyPhone.Util
local NET = WolfyPhone.NET
local Cfg = WolfyPhone.Config

WolfyPhone.Local = WolfyPhone.Local or {
    open = false,
    inbox = {},            -- [otherKey] = { {fromKey, fromName, text, ts}, ... }
    names = {},            -- [playerKey] = last seen display name
    unread = {},           -- [otherKey] = count
    call = nil,            -- { state, otherKey, otherName, since }
    wallet = "0",
    job = "None",
}
local L = WolfyPhone.Local

-- ---- state helpers -----------------------------------------------------

function WolfyPhone.NameFor(key)
    local ply = Util.FindPlayerByKey(key)
    if IsValid(ply) then return Util.DisplayName(ply) end
    return L.names[key] or key
end

function WolfyPhone.Conversations()
    local keys = {}
    for k in pairs(L.inbox) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        local ca, cb = L.inbox[a], L.inbox[b]
        local ta = ca[#ca] and ca[#ca].ts or 0
        local tb = cb[#cb] and cb[#cb].ts or 0
        return ta > tb
    end)
    return keys
end

function WolfyPhone.TotalUnread()
    local n = 0
    for _, c in pairs(L.unread) do n = n + c end
    return n
end

function WolfyPhone.MarkRead(key)
    L.unread[key] = nil
end

local function appendLocal(otherKey, msg)
    L.inbox[otherKey] = L.inbox[otherKey] or {}
    table.insert(L.inbox[otherKey], msg)
    while #L.inbox[otherKey] > (Cfg.MaxMessagesPerConvo or 100) do
        table.remove(L.inbox[otherKey], 1)
    end
end

-- ---- open / close -------------------------------------------------------

function WolfyPhone.OpenPhone()
    if L.open then return end
    L.open = true
    WolfyPhone.UI.Open()          -- defined in cl_frame.lua
    surface.PlaySound(Cfg.OpenSound)
    net.Start(NET.OPEN)
    net.SendToServer()
end

function WolfyPhone.ClosePhone()
    if not L.open then return end
    L.open = false
    WolfyPhone.UI.Close()
    surface.PlaySound(Cfg.CloseSound)
end

function WolfyPhone.TogglePhone()
    if L.open then
        WolfyPhone.ClosePhone()
    else
        WolfyPhone.OpenPhone()
    end
end

concommand.Add("wolfyphone", WolfyPhone.TogglePhone)
concommand.Add("+wolfyphone", WolfyPhone.OpenPhone)
concommand.Add("-wolfyphone", WolfyPhone.ClosePhone)

-- Plays a UI sound unless the user muted them in Settings.
function WolfyPhone.PlaySound(name)
    if cookie.GetString("wolfyphone_sounds", "1") ~= "1" then return end
    surface.PlaySound(name)
end

-- ---- inbound receivers --------------------------------------------------

net.Receive(NET.MSG_PUSH, function()
    local msg = {
        fromKey = net.ReadString(),
        fromName = net.ReadString(),
        text = net.ReadString(),
        ts = net.ReadUInt(32),
    }
    L.names[msg.fromKey] = msg.fromName
    appendLocal(msg.fromKey, msg)

    -- Notify only when the conversation isn't on screen.
    local viewing = L.open and WolfyPhone.UI.CurrentApp() == "messages"
        and WolfyPhone.UI.MessagesViewing() == msg.fromKey
    if not viewing then
        L.unread[msg.fromKey] = (L.unread[msg.fromKey] or 0) + 1
        WolfyPhone.UI.Toast("messages", msg.fromName, msg.text)
        WolfyPhone.PlaySound(Cfg.NotifySound)
    end
    WolfyPhone.UI.Refresh()
end)

net.Receive(NET.MSG_ACK, function()
    local ok = net.ReadBool()
    local detail = net.ReadString()
    if ok then
        WolfyPhone.PlaySound(Cfg.SendSound)
    else
        WolfyPhone.UI.Toast("messages", "Message failed", detail)
    end
    WolfyPhone.UI.Refresh()
end)

net.Receive(NET.CALL_STATE, function()
    local state = net.ReadString()
    local otherKey = net.ReadString()
    local otherName = net.ReadString()
    local since = net.ReadUInt(32)

    if state == "idle" then
        L.call = nil
    else
        if otherName ~= "" then L.names[otherKey] = otherName end
        L.call = {
            state = state,
            otherKey = otherKey,
            otherName = otherName ~= "" and otherName or WolfyPhone.NameFor(otherKey),
            since = since,
        }
        if state == "incoming" then
            WolfyPhone.PlaySound(Cfg.RingSound)
            WolfyPhone.UI.Toast("calls", "Incoming call", L.call.otherName)
        end
    end
    WolfyPhone.UI.Refresh()
end)

net.Receive(NET.SYNC, function()
    local inbox = net.ReadTable()
    local wallet = net.ReadString()
    local job = net.ReadString()
    if istable(inbox) then
        L.inbox = inbox
        -- Rebuild the name cache from stored senders.
        for _, convo in pairs(inbox) do
            for _, msg in ipairs(convo) do
                if msg.fromName and msg.fromName ~= "" then
                    L.names[msg.fromKey] = msg.fromName
                end
            end
        end
    end
    L.wallet = wallet
    L.job = job
    WolfyPhone.UI.Refresh()
end)

net.Receive(NET.NOTIFY, function()
    local appId = net.ReadString()
    local title = net.ReadString()
    local body = net.ReadString()
    WolfyPhone.UI.Toast(appId, title, body)
    WolfyPhone.PlaySound(Cfg.NotifySound)
end)

-- ---- client -> server senders -------------------------------------------

function WolfyPhone.SendMessage(toKey, text)
    net.Start(NET.MSG_SEND)
        net.WriteString(toKey)
        net.WriteString(text)
    net.SendToServer()
    -- Optimistic local echo; the server copy is authoritative on next sync.
    appendLocal(toKey, {
        fromKey = Util.PlayerKey(LocalPlayer()),
        fromName = Util.DisplayName(LocalPlayer()),
        text = text,
        ts = os.time(),
        mine = true,
    })
end

function WolfyPhone.CallAction(action, toKey)
    net.Start(NET.CALL_ACT)
        net.WriteString(action)
        net.WriteString(toKey or "")
    net.SendToServer()
end

function WolfyPhone.RequestSync()
    net.Start(NET.SYNC_REQ)
    net.SendToServer()
end

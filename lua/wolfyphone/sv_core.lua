-- Server core: message store, offline inbox persistence, call state machine,
-- net receivers, voice routing, and gamemode hooks (DarkRP-aware).

local Server = WolfyPhone.Server
local Util = WolfyPhone.Util
local Cfg = WolfyPhone.Config
local NET = WolfyPhone.NET

---------------------------------------------------------------------
-- Optional convar overrides (checked at read time, so they can be tuned
-- from server.cfg or the console without editing sh_config.lua).

CreateConVar("wolfyphone_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Master switch for WolfyPhone messaging and calls.")
CreateConVar("wolfyphone_globalvoice", "1", FCVAR_ARCHIVE,
    "Players in an active call hear each other regardless of distance.")
CreateConVar("wolfyphone_maxmsglen", tostring(Cfg.MaxMessageLength), FCVAR_ARCHIVE,
    "Max message length in characters.")

local function enabled()
    return GetConVar("wolfyphone_enabled"):GetBool()
end

---------------------------------------------------------------------
-- Inbox store
--
-- Server.Inboxes[ownerKey][otherKey] = { {fromKey, fromName, text, ts}, ... }
-- Persisted per owner to garrysmod/data/wolfyphone/inbox_<key>.json.

Server.Inboxes = Server.Inboxes or {}

local DATA_DIR = "wolfyphone"
file.CreateDir(DATA_DIR)

local function inboxPath(key)
    return DATA_DIR .. "/inbox_" .. key .. ".json"
end

function Server.GetInbox(ownerKey)
    Server.Inboxes[ownerKey] = Server.Inboxes[ownerKey] or {}
    return Server.Inboxes[ownerKey]
end

function Server.AppendMessage(ownerKey, otherKey, msg)
    local convo = Server.GetInbox(ownerKey)
    convo[otherKey] = convo[otherKey] or {}
    table.insert(convo[otherKey], msg)
    while #convo[otherKey] > (Cfg.MaxMessagesPerConvo or 100) do
        table.remove(convo[otherKey], 1)
    end
end

function Server.LoadInbox(key)
    local path = inboxPath(key)
    if not file.Exists(path, "DATA") then return end
    local raw = file.Read(path, "DATA")
    local ok, data = pcall(util.JSONToTable, raw or "")
    if ok and istable(data) then
        Server.Inboxes[key] = data
    end
end

function Server.SaveInbox(key)
    local inbox = Server.Inboxes[key]
    if not inbox then return end
    file.Write(inboxPath(key), util.TableToJSON(inbox))
end

function Server.SaveAll()
    for key in pairs(Server.Inboxes) do
        Server.SaveInbox(key)
    end
end

timer.Create("WolfyPhone.Autosave", Cfg.SaveInterval or 120, 0, function()
    Server.SaveAll()
end)

hook.Add("ShutDown", "WolfyPhone.Save", function()
    Server.SaveAll()
end)

hook.Add("PlayerInitialSpawn", "WolfyPhone.Join", function(ply)
    local key = Util.PlayerKey(ply)
    if not key then return end
    Server.LoadInbox(key)
    if Cfg.GiveToNewPlayers then
        ply:Give("weapon_wolfyphone")
    end
end)

hook.Add("PlayerDisconnected", "WolfyPhone.Leave", function(ply)
    local key = Util.PlayerKey(ply)
    if key then Server.SaveInbox(key) end
    Server.EndCallFor(ply, "disconnected")
end)

---------------------------------------------------------------------
-- Rate limiting (messages + calls share a small per-player table)

Server._cooldowns = {}

local function cooled(ply, slot, seconds)
    local key = Util.PlayerKey(ply) or "?"
    Server._cooldowns[key] = Server._cooldowns[key] or {}
    local last = Server._cooldowns[key][slot] or 0
    if CurTime() - last < seconds then return false end
    Server._cooldowns[key][slot] = CurTime()
    return true
end

---------------------------------------------------------------------
-- Messaging (receiver registered here; the Messages app owns the UI)

net.Receive(NET.MSG_SEND, function(_, sender)
    if not enabled() then return end
    if not Util.IsValidPlayer(sender) then return end
    if not cooled(sender, "msg", Cfg.MessageCooldown or 1) then
        Server.AckMessage(sender, false, "Sending too fast")
        return
    end

    local toKey = net.ReadString()
    local text = Util.SanitizeMessage(net.ReadString())
    if #text == 0 then
        Server.AckMessage(sender, false, "Empty message")
        return
    end

    local target = Util.FindPlayerByKey(toKey)
    local fromKey = Util.PlayerKey(sender)
    local msg = {
        fromKey = fromKey,
        fromName = Util.DisplayName(sender),
        text = text,
        ts = os.time(),
    }

    -- Always log into the sender's own copy of the conversation.
    Server.AppendMessage(fromKey, toKey, msg)

    if Util.IsValidPlayer(target) then
        Server.AppendMessage(Util.PlayerKey(target), fromKey, msg)
        Server.PushMessage(target, msg)
        Server.AckMessage(sender, true, toKey)
    elseif Cfg.DeliverOfflineMessages and isstring(toKey) and #toKey > 0 then
        -- Queued for delivery when the recipient next joins.
        Server.AppendMessage(toKey, fromKey, msg)
        Server.SaveInbox(toKey)
        Server.AckMessage(sender, true, toKey)
    else
        Server.AckMessage(sender, false, "No such player")
    end
end)

net.Receive(NET.SYNC_REQ, function(_, ply)
    if not enabled() then return end
    if not Util.IsValidPlayer(ply) then return end
    Server.Sync(ply)
end)

-- Clients ping this when the phone opens; lets us resync + count usage later.
net.Receive(NET.OPEN, function(_, ply)
    if not enabled() then return end
    if not Util.IsValidPlayer(ply) then return end
    Server.Sync(ply)
end)

---------------------------------------------------------------------
-- Calls
--
-- Server.Calls[key] = { peer = otherKey, state = "ringing"|"active",
--                       since = os.time(), started = CurTime() }

Server.Calls = Server.Calls or {}

local function callFor(key)
    return Server.Calls[key]
end

local function clearCall(key)
    Server.Calls[key] = nil
end

function Server.InCallWith(keyA, keyB)
    local c = callFor(keyA)
    return c ~= nil and c.state == "active" and c.peer == keyB
end

function Server.EndCallFor(ply, reason)
    local key = Util.PlayerKey(ply)
    if not key then return end
    local c = callFor(key)
    if not c then return end
    local peer = Util.FindPlayerByKey(c.peer)
    clearCall(key)
    clearCall(c.peer)
    Server.SendCallState(ply, "idle")
    if Util.IsValidPlayer(peer) then
        Server.SendCallState(peer, "idle")
        Server.Notify(peer, "calls", "Call ended",
            reason == "disconnected" and "The other player disconnected." or "Call ended.")
    end
end

local CALL_ACTIONS = { start = true, accept = true, decline = true, end_call = true }

net.Receive(NET.CALL_ACT, function(_, ply)
    if not enabled() then return end
    if not Util.IsValidPlayer(ply) then return end

    local action = net.ReadString()
    local toKey = net.ReadString()
    if not CALL_ACTIONS[action] then return end

    local key = Util.PlayerKey(ply)
    local name = Util.DisplayName(ply)

    if action == "start" then
        if not cooled(ply, "call", Cfg.CallCooldown or 5) then
            Server.Notify(ply, "calls", "Slow down", "Wait before calling again.")
            return
        end
        local target = Util.FindPlayerByKey(toKey)
        if not Util.IsValidPlayer(target) or toKey == key then
            Server.Notify(ply, "calls", "Call failed", "Player is not online.")
            return
        end
        local targetKey = Util.PlayerKey(target)
        if callFor(key) or callFor(targetKey) then
            Server.Notify(ply, "calls", "Busy", "A call is already in progress.")
            return
        end
        Server.Calls[key] = { peer = targetKey, state = "ringing", since = os.time() }
        Server.Calls[targetKey] = { peer = key, state = "ringing", since = os.time() }
        Server.SendCallState(ply, "ringing", targetKey, Util.DisplayName(target), os.time())
        Server.SendCallState(target, "incoming", key, name, os.time())
        Server.Notify(target, "calls", "Incoming call", name .. " is calling you.")

        -- Auto-drop unanswered calls.
        timer.Create("WolfyPhone.Ring." .. key, Cfg.CallRingTimeout or 30, 1, function()
            local c = callFor(key)
            if c and c.state == "ringing" and c.peer == targetKey then
                local caller = Util.FindPlayerByKey(key)
                local callee = Util.FindPlayerByKey(targetKey)
                clearCall(key)
                clearCall(targetKey)
                if Util.IsValidPlayer(caller) then
                    Server.SendCallState(caller, "idle")
                    Server.Notify(caller, "calls", "No answer", Util.DisplayName(callee) .. " didn't pick up.")
                end
                if Util.IsValidPlayer(callee) then
                    Server.SendCallState(callee, "idle")
                end
            end
        end)

    elseif action == "accept" then
        local c = callFor(key)
        if not c or c.state ~= "ringing" then return end
        c.state = "active"
        local pc = callFor(c.peer)
        if pc then pc.state = "active" end
        timer.Remove("WolfyPhone.Ring." .. c.peer)
        timer.Remove("WolfyPhone.Ring." .. key)
        local peer = Util.FindPlayerByKey(c.peer)
        local now = os.time()
        Server.SendCallState(ply, "active", c.peer, peer and Util.DisplayName(peer) or "", now)
        if Util.IsValidPlayer(peer) then
            Server.SendCallState(peer, "active", key, name, now)
        end

    elseif action == "decline" or action == "end_call" then
        local c = callFor(key)
        if not c then
            Server.SendCallState(ply, "idle")
            return
        end
        timer.Remove("WolfyPhone.Ring." .. key)
        timer.Remove("WolfyPhone.Ring." .. c.peer)
        Server.EndCallFor(ply, action == "decline" and "declined" or "ended")
    end
end)

-- Voice routing: while two players share an active call, let them hear each
-- other anywhere on the map when the override convar is on.
hook.Add("PlayerCanHearPlayersVoice", "WolfyPhone.CallVoice", function(listener, talker)
    if not GetConVar("wolfyphone_globalvoice"):GetBool() then return end
    local lk, tk = Util.PlayerKey(listener), Util.PlayerKey(talker)
    if lk and tk and Server.InCallWith(lk, tk) then
        return true, true
    end
end)

---------------------------------------------------------------------
-- Chat command: "!phone" gives the SWEP.

hook.Add("PlayerSay", "WolfyPhone.ChatCmd", function(ply, text)
    if not enabled() or not Cfg.GiveOnCommand then return end
    if string.lower(string.Trim(text)) ~= Cfg.ChatCommand then return end
    if not ply:HasWeapon("weapon_wolfyphone") then
        ply:Give("weapon_wolfyphone")
        ply:ChatPrint("[WolfyPhone] Phone added to your weapons.")
    else
        ply:ChatPrint("[WolfyPhone] You already have a phone. Use it to open the UI.")
    end
    return ""
end)

concommand.Add("wolfyphone_give", function(ply)
    if not Util.IsValidPlayer(ply) then return end
    ply:Give("weapon_wolfyphone")
end)

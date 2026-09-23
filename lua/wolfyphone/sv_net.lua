-- Server: network channel registration and outbound helpers.
-- Channel names must stay <= 16 chars (engine limit).

WolfyPhone.NET = {
    MSG_SEND   = "wp_msg_send",   -- C->S: toKey, text
    MSG_PUSH   = "wp_msg_push",   -- S->C: fromKey, fromName, text, ts
    MSG_ACK    = "wp_msg_ack",    -- S->C: ok, detail
    CALL_ACT   = "wp_call_act",   -- C->S: action, toKey
    CALL_STATE = "wp_call_state", -- S->C: state, otherKey, otherName, since
    SYNC_REQ   = "wp_sync_req",   -- C->S: (empty) request full sync
    SYNC       = "wp_sync",       -- S->C: inbox table + wallet + job
    NOTIFY     = "wp_notify",     -- S->C: appId, title, body
    OPEN       = "wp_open",       -- C->S: phone opened (activity hint)
}

for _, name in pairs(WolfyPhone.NET) do
    util.AddNetworkString(name)
end

WolfyPhone.Server = WolfyPhone.Server or {}

-- Push a single inbound message to a client.
function WolfyPhone.Server.PushMessage(to, msg)
    net.Start(WolfyPhone.NET.MSG_PUSH)
        net.WriteString(msg.fromKey or "")
        net.WriteString(msg.fromName or "")
        net.WriteString(msg.text or "")
        net.WriteUInt(msg.ts or os.time(), 32)
    net.Send(to)
end

-- Ack/decline a client -> server send.
function WolfyPhone.Server.AckMessage(to, ok, detail)
    net.Start(WolfyPhone.NET.MSG_ACK)
        net.WriteBool(ok)
        net.WriteString(detail or "")
    net.Send(to)
end

-- Tell a client about its call state. state: "idle"|"ringing"|"incoming"|"active"
function WolfyPhone.Server.SendCallState(to, state, otherKey, otherName, since)
    net.Start(WolfyPhone.NET.CALL_STATE)
        net.WriteString(state)
        net.WriteString(otherKey or "")
        net.WriteString(otherName or "")
        net.WriteUInt(since or 0, 32)
    net.Send(to)
end

-- Toast notification routed to an app's OnNotify handler (and banner).
function WolfyPhone.Server.Notify(to, appId, title, body)
    net.Start(WolfyPhone.NET.NOTIFY)
        net.WriteString(appId or "")
        net.WriteString(title or "")
        net.WriteString(body or "")
    net.Send(to)
end

-- Full state sync: inbox history + profile (wallet/job) fields.
function WolfyPhone.Server.Sync(to)
    local key = WolfyPhone.Util.PlayerKey(to)
    net.Start(WolfyPhone.NET.SYNC)
        net.WriteTable(WolfyPhone.Server.GetInbox(key))
        net.WriteString(tostring(WolfyPhone.Util.Wallet(to)))
        net.WriteString(WolfyPhone.Util.JobName(to))
    net.Send(to)
end

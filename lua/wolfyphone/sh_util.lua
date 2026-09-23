-- Shared helpers: validation, sanitizing, identity, DarkRP-aware lookups.
-- Everything here is pure or defensive — safe to call from either realm.

WolfyPhone.Util = WolfyPhone.Util or {}

local Util = WolfyPhone.Util

-- Stable per-player key used in storage tables and net payloads. Bots get a
-- session-scoped key since they have no real SteamID64.
function Util.PlayerKey(ply)
    if not IsValid(ply) then return nil end
    if ply:IsBot() then return "BOT_" .. ply:EntIndex() end
    return ply:SteamID64() or ply:SteamID()
end

function Util.IsValidPlayer(ply)
    return IsValid(ply) and ply:IsPlayer()
end

-- Trim, strip control characters, clamp to Config.MaxMessageLength.
-- Returns "" for invalid input so callers can reject with a length check.
function Util.SanitizeMessage(text)
    if not isstring(text) then return "" end
    text = string.gsub(text, "[%z\1-\8\11\12\14-\31\127]", "")
    text = string.Trim(text)
    -- wolfyphone_maxmsglen convar overrides the config default where present
    local maxLen = WolfyPhone.Config.MaxMessageLength or 280
    if GetConVar then
        local cv = GetConVar("wolfyphone_maxmsglen")
        if cv and cv:GetInt() > 0 then maxLen = cv:GetInt() end
    end
    if #text > maxLen then
        text = string.sub(text, 1, maxLen)
    end
    return text
end

function Util.DisplayName(ply)
    if not Util.IsValidPlayer(ply) then return "Unknown" end
    local name = ply:Nick()
    return isstring(name) and name or "Unknown"
end

function Util.FindPlayerByKey(key)
    if not isstring(key) then return nil end
    for _, ply in ipairs(player.GetAll()) do
        if Util.PlayerKey(ply) == key then return ply end
    end
    return nil
end

-- DarkRP-aware lookups with sandbox fallbacks.
function Util.Wallet(ply)
    if not Util.IsValidPlayer(ply) then return 0 end
    if DarkRP and ply.getDarkRPVar then
        return ply:getDarkRPVar("money") or 0
    end
    return ply:Frags() or 0
end

function Util.JobName(ply)
    if not Util.IsValidPlayer(ply) then return "None" end
    if DarkRP and ply.getDarkRPVar then
        local job = ply:getDarkRPVar("job")
        if isstring(job) then return job end
    end
    local t = team.GetName(ply:Team())
    return t or "None"
end

function Util.HasDarkRP()
    return DarkRP ~= nil and DarkRP ~= false
end

-- Seconds -> "m:ss" for call timers.
function Util.FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Util.FormatClock(ts)
    return os.date("%H:%M", ts or os.time())
end

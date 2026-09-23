-- WolfyPhone smoke test: stubs the Garry's Mod API and exercises the shared +
-- server code under plain LuaJIT 5.1 (the same runtime GMod ships).
--
-- Usage (from the repo root):  luajit tests/smoke.lua
--
-- What it verifies:
--   * every lua/ file compiles (syntax)
--   * shared modules + server core + all apps load without runtime errors
--   * message send/ack/delivery, cooldown + sanitization, offline queue
--   * inbox persistence round-trip via the DATA-dir stub
--   * call invite -> accept -> voice routing -> hangup state machine
--   * DarkRP fallback vs DarkRP-present wallet lookup

local ROOT = arg and arg[0] and arg[0]:gsub("tests/smoke%.lua$", "") or "./"
package.path = ROOT .. "?.lua;" .. package.path

---------------------------------------------------------------------------
-- Minimal GLua type predicates + globals the addon expects
---------------------------------------------------------------------------

function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return v ~= nil and (type(v) ~= "table" or v._valid ~= false) end

function Color(r, g, b, a) return { r = r or 0, g = g or 0, b = b or 0, a = a or 255 } end
function color_white() end
color_white = Color(255, 255, 255)

-- CurTime() in GMod is seconds since server start (a large number), not
-- process CPU time; cooldown logic depends on that.
function CurTime() return os.time() end

function table.Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

function string.Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

SERVER = true
CLIENT = false

FCVAR_ARCHIVE = 1
FCVAR_NOTIFY = 2
FCVAR_REPLICATED = 4

KEY_ESCAPE = 27

---------------------------------------------------------------------------
-- Convars
---------------------------------------------------------------------------

local convars = {}
function CreateConVar(name, default, _, _)
    convars[name] = tostring(default)
end
function GetConVar(name)
    return {
        GetBool = function() return convars[name] == "1" or convars[name] == "true" end,
        GetString = function() return convars[name] or "" end,
        GetInt = function() return tonumber(convars[name]) or 0 end,
    }
end

---------------------------------------------------------------------------
-- include / AddCSLuaFile
---------------------------------------------------------------------------

function include(path)
    local fn, err = loadfile(ROOT .. "lua/" .. path)
    assert(fn, "include failed for " .. path .. ": " .. tostring(err))
    return fn()
end
function AddCSLuaFile() end

---------------------------------------------------------------------------
-- file.* — backed by tests/.smoke_tmp/data
---------------------------------------------------------------------------

local TMP = ROOT .. "tests/.smoke_tmp"
os.execute("rm -rf " .. TMP)
local DATA = TMP .. "/data/"
os.execute("mkdir -p " .. DATA)

file = {
    CreateDir = function() os.execute("mkdir -p " .. DATA .. "wolfyphone") end,
    Write = function(path, contents)
        local f = assert(io.open(DATA .. path, "wb"))
        f:write(contents)
        f:close()
    end,
    Read = function(path)
        local f = io.open(DATA .. path, "rb")
        if not f then return nil end
        local s = f:read("*a")
        f:close()
        return s
    end,
    Exists = function(path)
        local f = io.open(DATA .. path, "rb")
        if f then f:close() return true end
        return false
    end,
    Find = function(pattern)
        -- only pattern used: wolfyphone/apps/*.lua
        local dir = pattern:gsub("/%*%.lua$", "")
        local files = {}
        local p = io.popen("ls -1 " .. ROOT .. "lua/" .. dir .. " 2>/dev/null")
        for name in p:lines() do
            if name:match("%.lua$") then table.insert(files, name) end
        end
        p:close()
        return files
    end,
}

---------------------------------------------------------------------------
-- util.* — JSON round-trip
---------------------------------------------------------------------------

local function jenc(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local isArr = #v > 0
        local parts = {}
        if isArr then
            for _, e in ipairs(v) do table.insert(parts, jenc(e)) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, e in pairs(v) do
            table.insert(parts, jenc(tostring(k)) .. ":" .. jenc(e))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local jdec
do
    local function ws(s, i) local _, j = s:find("^[ \t\r\n]*", i) return (j or i - 1) + 1 end
    local function val(s, i)
        i = ws(s, i)
        local ch = s:sub(i, i)
        if ch == "{" then
            local t = {}
            i = ws(s, i + 1)
            if s:sub(i, i) == "}" then return t, i + 1 end
            while true do
                local k; k, i = val(s, i)
                i = ws(s, i)
                assert(s:sub(i, i) == ":", "bad json object")
                local v; v, i = val(s, i + 1)
                t[k] = v
                i = ws(s, i)
                if s:sub(i, i) == "," then i = ws(s, i + 1)
                else return t, i + 1 end
            end
        elseif ch == "[" then
            local t = {}
            i = ws(s, i + 1)
            if s:sub(i, i) == "]" then return t, i + 1 end
            while true do
                local v; v, i = val(s, i)
                table.insert(t, v)
                i = ws(s, i)
                if s:sub(i, i) == "," then i = i + 1
                else return t, i + 1 end
            end
        elseif ch == '"' then
            local j = i + 1
            while true do
                j = s:find('"', j, true)
                if s:sub(j - 1, j - 1) ~= "\\" then break end
                j = j + 1
            end
            local raw = s:sub(i + 1, j - 1)
            raw = raw:gsub("\\(.)", { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\" })
            return raw, j + 1
        elseif ch == "t" then return true, i + 4
        elseif ch == "f" then return false, i + 5
        elseif ch == "n" then return nil, i + 4
        else
            local num = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
            return tonumber(num), i + #num
        end
    end
    jdec = function(s) local v = val(s, 1) return v end
end

util = {
    AddNetworkString = function() end,
    TableToJSON = function(t) return jenc(t) end,
    JSONToTable = function(s) return jdec(s) end,
}

---------------------------------------------------------------------------
-- net.* — message capture; SendToServer invokes registered receivers
---------------------------------------------------------------------------

net = { _receivers = {}, _buf = nil, _readq = nil, _lastSend = nil }

function net.Receive(name, fn) net._receivers[name] = fn end
function net.Start(name) net._buf = { name = name, fields = {} } end
local function push(v) table.insert(net._buf.fields, v) end
function net.WriteString(v) push(v) end
function net.WriteUInt(v) push(v) end
function net.WriteBool(v) push(v) end
function net.WriteTable(v) push(v) end
local function pop()
    local v = table.remove(net._readq.fields, 1)
    return v
end
net.ReadString = pop
net.ReadUInt = pop
net.ReadBool = pop
net.ReadTable = pop

-- Client -> server (only meaningful direction in this harness)
function net.SendToServer()
    local buf = net._buf
    net._buf = nil
    local fn = net._receivers[buf.name]
    assert(fn, "no receiver for " .. buf.name)
    net._readq = buf
    fn(#buf.fields, net._from)
    net._readq = nil
end
function net.Send(ply)
    ply.outbox = ply.outbox or {}
    table.insert(ply.outbox, { name = net._buf.name, fields = net._buf.fields })
    net._lastSend = { to = ply, name = net._buf.name, fields = net._buf.fields }
    net._buf = nil
end
function net.Broadcast()
    for _, p in ipairs(player.GetAll()) do net.Send(p) end
end

-- harness: send a client->server message
local function c2s(name, ply, ...)
    net._from = ply
    net.Start(name)
    for _, v in ipairs({ ... }) do
        if type(v) == "string" then net.WriteString(v)
        elseif type(v) == "boolean" then net.WriteBool(v)
        elseif type(v) == "table" then net.WriteTable(v)
        else net.WriteUInt(v) end
    end
    net.SendToServer()
    net._from = nil
end

---------------------------------------------------------------------------
-- hook / timer / concommand / player / team / engine
---------------------------------------------------------------------------

hook = { _h = {} }
function hook.Add(name, id, fn) hook._h[name] = hook._h[name] or {}; hook._h[name][id] = fn end
function hook.Remove(name, id) if hook._h[name] then hook._h[name][id] = nil end end
local function hookRun(name, ...)
    local ret
    for _, fn in pairs(hook._h[name] or {}) do
        local r = fn(...)
        if r ~= nil then ret = r end
    end
    return ret
end

timer = { _t = {} }
function timer.Create(name, delay, reps, fn)
    timer._t[name] = { delay = delay, reps = reps, fn = fn }
end
function timer.Remove(name) timer._t[name] = nil end
function timer.Simple(_, fn) fn() end
local function timerFire(name)
    local t = timer._t[name]
    if t then t.fn(); if t.reps == 1 then timer._t[name] = nil end end
end

concommand = { _c = {} }
function concommand.Add(name, fn) concommand._c[name] = fn end

team = { GetName = function() return "Players" end }
engine = { ActiveGamemode = function() return "sandbox" end }

local PlayerMT = {}
PlayerMT.__index = PlayerMT
function PlayerMT:IsPlayer() return true end
function PlayerMT:IsBot() return self.bot or false end
function PlayerMT:EntIndex() return self.eidx end
function PlayerMT:SteamID64() return self.sid64 end
function PlayerMT:SteamID() return self.sid end
function PlayerMT:Nick() return self.name end
function PlayerMT:Team() return 1 end
function PlayerMT:Frags() return self.frags or 0 end
function PlayerMT:Give(w) self.weapons[w] = true end
function PlayerMT:HasWeapon(w) return self.weapons[w] == true end
function PlayerMT:ChatPrint() end
function PlayerMT:getDarkRPVar(v) return self.darkrp and self.darkrp[v] or nil end

local allPlayers = {}
local function mkPlayer(name, sid64)
    local p = setmetatable({
        name = name, sid64 = sid64, sid = "STEAM_0:0:1",
        eidx = #allPlayers + 1, weapons = {}, outbox = {},
    }, PlayerMT)
    table.insert(allPlayers, p)
    return p
end

player = { GetAll = function() return allPlayers end }

---------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------

local passed, failed = 0, 0
local function ok(cond, label)
    if cond then
        passed = passed + 1
        print("  PASS  " .. label)
    else
        failed = failed + 1
        print("  FAIL  " .. label)
    end
end

---------------------------------------------------------------------------
-- 0. Syntax-check every Lua file in lua/ (client files too)
---------------------------------------------------------------------------

print("== syntax ==")
local find = io.popen("find " .. ROOT .. "lua -name '*.lua' | sort")
local nfiles = 0
for path in find:lines() do
    nfiles = nfiles + 1
    local fn, err = loadfile(path)
    ok(fn ~= nil, "syntax: " .. path:gsub(ROOT, "") .. (err and ("  -> " .. err) or ""))
end
find:close()
ok(nfiles > 8, "found " .. nfiles .. " lua files")

---------------------------------------------------------------------------
-- 1. Load the addon (server realm)
---------------------------------------------------------------------------

print("== load ==")
local okLoad, loadErr = pcall(include, "autorun/wolfyphone_init.lua")
ok(okLoad, "autorun loads: " .. tostring(loadErr or "ok"))
ok(WolfyPhone and WolfyPhone.Apps and WolfyPhone.Apps.messages ~= nil, "apps registered")
ok(#WolfyPhone.AppOrder >= 5, "at least 5 apps (" .. #WolfyPhone.AppOrder .. ")")

---------------------------------------------------------------------------
-- 2. Players + messaging
---------------------------------------------------------------------------

print("== messages ==")
local alice = mkPlayer("Alice", "76561198000000001")
local bob = mkPlayer("Bob", "76561198000000002")

hookRun("PlayerInitialSpawn", alice)
hookRun("PlayerInitialSpawn", bob)

c2s(WolfyPhone.NET.MSG_SEND, alice, "76561198000000002", "hi bob")
local last = bob.outbox[#bob.outbox]
ok(last and last.name == WolfyPhone.NET.MSG_PUSH, "push delivered to Bob")
ok(last and last.fields[3] == "hi bob", "message body intact")

local aliceAck = alice.outbox[#alice.outbox]
ok(aliceAck and aliceAck.name == WolfyPhone.NET.MSG_ACK and aliceAck.fields[1] == true,
    "sender ack ok")

-- stored on both sides
local ak, bk = "76561198000000001", "76561198000000002"
ok(#WolfyPhone.Server.GetInbox(ak)[bk] == 1, "sender-side copy stored")
ok(#WolfyPhone.Server.GetInbox(bk)[ak] == 1, "recipient-side copy stored")

-- validation: empty message rejected
c2s(WolfyPhone.NET.MSG_SEND, alice, bk, "   ")
aliceAck = alice.outbox[#alice.outbox]
ok(aliceAck.fields[1] == false, "empty message rejected")

-- cooldown: immediate resend rejected
c2s(WolfyPhone.NET.MSG_SEND, alice, bk, "again")
aliceAck = alice.outbox[#alice.outbox]
ok(aliceAck.fields[1] == false, "cooldown enforced")

-- sanitization strips control chars
local dirty = WolfyPhone.Util.SanitizeMessage("a\1b\0c")
ok(dirty == "abc", "control chars stripped (" .. dirty .. ")")

-- offline delivery queue
WolfyPhone.Server._cooldowns = {} -- reset cooldowns for test flow
c2s(WolfyPhone.NET.MSG_SEND, alice, "76561198000000099", "offline hello")
ok(WolfyPhone.Server.GetInbox("76561198000000099")[ak] ~= nil,
    "offline message queued")
ok(file.Exists("wolfyphone/inbox_76561198000000099.json", "DATA"),
    "offline inbox persisted to data/")

---------------------------------------------------------------------------
-- 3. Persistence round-trip
---------------------------------------------------------------------------

print("== persistence ==")
WolfyPhone.Server.SaveInbox(bk)
WolfyPhone.Server.Inboxes[bk] = nil
ok(file.Exists("wolfyphone/inbox_" .. bk .. ".json", "DATA"), "inbox file written")
WolfyPhone.Server.LoadInbox(bk)
local restored = WolfyPhone.Server.GetInbox(bk)[ak]
ok(restored and #restored == 1 and restored[1].text == "hi bob",
    "inbox round-trips through JSON")

---------------------------------------------------------------------------
-- 4. Calls
---------------------------------------------------------------------------

print("== calls ==")
c2s(WolfyPhone.NET.CALL_ACT, alice, "start", bk)
ok(WolfyPhone.Server.Calls[ak] and WolfyPhone.Server.Calls[ak].state == "ringing",
    "call created ringing")
ok(WolfyPhone.Server.Calls[bk] ~= nil, "callee has ringing state")

c2s(WolfyPhone.NET.CALL_ACT, bob, "accept", ak)
ok(WolfyPhone.Server.Calls[ak].state == "active", "call active for caller")
ok(WolfyPhone.Server.InCallWith(ak, bk), "InCallWith true")

local hear = hookRun("PlayerCanHearPlayersVoice", alice, bob)
ok(hear == true, "voice routed between call peers")
local hearOther = hookRun("PlayerCanHearPlayersVoice", alice, mkPlayer("Eve", "9"))
ok(hearOther ~= true, "non-peer unaffected")

c2s(WolfyPhone.NET.CALL_ACT, alice, "end_call", bk)
ok(WolfyPhone.Server.Calls[ak] == nil and WolfyPhone.Server.Calls[bk] == nil,
    "hangup clears both sides")

-- ring timeout: start, never accept, fire the timer
c2s(WolfyPhone.NET.CALL_ACT, alice, "start", bk)
timerFire("WolfyPhone.Ring." .. ak)
ok(WolfyPhone.Server.Calls[ak] == nil, "unanswered call drops after timeout")

---------------------------------------------------------------------------
-- 5. Sync + wallet lookups
---------------------------------------------------------------------------

print("== sync/darkrp ==")
c2s(WolfyPhone.NET.SYNC_REQ, bob)
local sync = bob.outbox[#bob.outbox]
ok(sync.name == WolfyPhone.NET.SYNC, "sync packet sent")
ok(sync.fields[2] == "0", "sandbox wallet fallback = frags")

DarkRP = {}
bob.darkrp = { money = 1500, job = "Citizen" }
ok(WolfyPhone.Util.Wallet(bob) == 1500, "DarkRP wallet lookup")
ok(WolfyPhone.Util.JobName(bob) == "Citizen", "DarkRP job lookup")

---------------------------------------------------------------------------
-- 6. Disconnect cleanup
---------------------------------------------------------------------------

print("== disconnect ==")
c2s(WolfyPhone.NET.CALL_ACT, alice, "start", bk)
hookRun("PlayerDisconnected", bob)
ok(WolfyPhone.Server.Calls[ak] == nil, "disconnect ends the call")

print()
print(string.format("== %d passed, %d failed ==", passed, failed))
os.exit(failed == 0 and 0 or 1)

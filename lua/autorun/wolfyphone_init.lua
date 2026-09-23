-- WolfyPhone bootstrap: loads shared/server/client modules and every app
-- dropped into lua/wolfyphone/apps/. App files are shared: each one guards
-- its realm-specific code with `if SERVER ... else ... end`.

WolfyPhone = WolfyPhone or {}
WolfyPhone.Version = "1.0.0"

local function loadShared(path)
    if SERVER then AddCSLuaFile(path) end
    include(path)
end

local function loadClient(path)
    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end
end

local function loadServer(path)
    if SERVER then include(path) end
end

loadShared("wolfyphone/sh_config.lua")
loadShared("wolfyphone/sh_util.lua")
loadShared("wolfyphone/sh_apps.lua")

loadServer("wolfyphone/sv_net.lua")
loadServer("wolfyphone/sv_core.lua")

loadClient("wolfyphone/cl_phone.lua")
loadClient("wolfyphone/cl_frame.lua")

-- Auto-discover app modules. A file in this directory is a self-contained
-- app: it registers itself via WolfyPhone.RegisterApp on both realms and may
-- add net receivers, hooks, or Derma UI.
local appFiles = file.Find("wolfyphone/apps/*.lua", "LUA")
table.sort(appFiles)
for _, name in ipairs(appFiles) do
    loadShared("wolfyphone/apps/" .. name)
end

if SERVER then
    print("[WolfyPhone] v" .. WolfyPhone.Version .. " loaded (" .. #WolfyPhone.AppOrder .. " apps)")
end

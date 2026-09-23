-- Shared app registry. Apps register themselves from any file under
-- lua/wolfyphone/apps/ on both realms; the client turns them into home
-- screen icons, the server just keeps a catalog.

-- App definition:
--   id        string  unique, lowercase (required)
--   name      string  display name (required)
--   color     Color   icon background
--   glyph     string  1-2 char monogram drawn on the icon
--   order     number  home screen sort order (lower = earlier)
--   OnOpen    fn(contentPanel)     client: build the app's UI
--   OnClose   fn()                 client: optional teardown
--   OnNotify  fn(payload)          client: optional push-notification hook
--   ServerInit fn()                server: optional post-load setup

WolfyPhone.Apps = WolfyPhone.Apps or {}
WolfyPhone.AppOrder = WolfyPhone.AppOrder or {}

function WolfyPhone.RegisterApp(def)
    assert(istable(def), "RegisterApp expects a table")
    assert(isstring(def.id) and #def.id > 0, "RegisterApp requires id")
    assert(isstring(def.name) and #def.name > 0, "RegisterApp requires name")
    assert(not WolfyPhone.Apps[def.id], "Duplicate app id: " .. def.id)

    def.color = def.color or WolfyPhone.Colors.Accent
    def.glyph = def.glyph or string.sub(def.name, 1, 1)
    def.order = def.order or 100

    WolfyPhone.Apps[def.id] = def
    table.insert(WolfyPhone.AppOrder, def.id)
    return def
end

function WolfyPhone.GetApp(id)
    return WolfyPhone.Apps[id]
end

-- Sorted ids for home-screen layout.
function WolfyPhone.SortedApps()
    local ids = table.Copy(WolfyPhone.AppOrder)
    table.sort(ids, function(a, b)
        local A, B = WolfyPhone.Apps[a], WolfyPhone.Apps[b]
        if A.order == B.order then return A.name < B.name end
        return A.order < B.order
    end)
    return ids
end

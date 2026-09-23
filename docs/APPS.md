# Writing a WolfyPhone app

Every file in `lua/wolfyphone/apps/` is auto-loaded on both realms. A single
file defines the whole app: shared registration, optional server logic, and
the client UI.

## Minimal app

```lua
-- lua/wolfyphone/apps/app_mine.lua
WolfyPhone.RegisterApp({
    id    = "mine",            -- unique, used in net + unread routing
    name  = "My App",          -- home-screen label + header title
    color = Color(255, 80, 80),
    glyph = "M",               -- 1-2 chars drawn on the icon
    order = 60,                -- home grid position (lower = earlier)
})

if SERVER then
    -- optional: net.Receive, hooks, timers
    return
end

WolfyPhone.Apps.mine.OnOpen = function(body)
    -- body: a blank DPanel docked FILL inside the phone, below the app header
    local lbl = vgui.Create("DLabel", body)
    lbl:Dock(FILL)
    lbl:SetContentAlignment(5)
    lbl:SetText("hello from my app")
end
```

## App definition fields

| Field | Realm | Purpose |
|---|---|---|
| `id`, `name` | both | required |
| `color`, `glyph`, `order` | client | icon appearance/position |
| `OnOpen(body)` | client | builds UI into the given panel |
| `OnClose()` | client | teardown (release panel refs) |
| `OnNotify(payload)` | client | receives `Server.Notify` for this app |
| `ServerInit()` | server | optional post-load setup |

## Client helpers

- `WolfyPhone.UI.Toast(appId, title, body)` — slide-down banner
- `WolfyPhone.UI.OpenApp(id)` / `WolfyPhone.UI.GoHome()`
- `WolfyPhone.UI.OnRefresh[appId] = fn` — called on state updates
- `WolfyPhone.UI.Refresh()` — request a repaint/refresh now
- `WolfyPhone.NameFor(key)` — display name for a stored player key
- `WolfyPhone.PlaySound(name)` — respects the sounds setting

## Server helpers

- `WolfyPhone.Server.Notify(ply, appId, title, body)` — push a toast
- `WolfyPhone.Server.Sync(ply)` — resend inbox + wallet/job
- `WolfyPhone.Server.GetInbox(key)` — stored conversations
- `WolfyPhone.Server.InCallWith(keyA, keyB)` — active-call check
- `WolfyPhone.Util.PlayerKey(ply)` / `FindPlayerByKey(key)` /
  `SanitizeMessage(text)` / `IsValidPlayer(ply)`

## Networking rules

- Register channels in `sv_net.lua`'s `WolfyPhone.NET` table — names **must
  be <= 16 characters** (engine limit).
- Validate everything server-side: use `Util.IsValidPlayer`,
  `Util.SanitizeMessage`, and per-player cooldowns like `sv_core.lua` does.
- Never trust client-sent player objects — send player keys (SteamID64) and
  resolve them server-side with `Util.FindPlayerByKey`.

## Notifications

`WolfyPhone.Server.Notify(ply, "mine", "Title", "Body")` reaches the client
as a toast banner and (if set) `OnNotify({title=, body=})`.

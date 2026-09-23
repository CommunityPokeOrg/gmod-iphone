# WolfyPhone

An iPhone-style in-game phone system for **Garry's Mod** — a SWEP plus a
Derma-rendered phone with a home screen, status bar, toast notifications, and
an extensible app framework. Built for Wolfy, works anywhere.

Features:

- **iPhone-like UI** — phone bezel, home screen icon grid, nav pill,
  slide-down toast banners, badge counts. 100% Derma/draw library, zero
  custom content.
- **Messages app** — player-to-player texting with conversation threads,
  unread badges, offline delivery, and server-side persistence
  (`data/wolfyphone/inbox_*.json`).
- **Phone app** — voice calls between players. Incoming-call accept/decline,
  ring timeout, live call timer, and a `PlayerCanHearPlayersVoice` override
  so call partners hear each other anywhere on the map.
- **Contacts app** — online player directory with client-persisted
  favorites and quick message/call actions.
- **Wallet app** — DarkRP money/job card when DarkRP is installed; falls
  back to score/team display in sandbox.
- **Notes app** — local notepad persisted client-side.
- **Settings app** — accent color, notification-sound toggle, about page.
- **Extensible apps** — drop a file into `lua/wolfyphone/apps/` and call
  `WolfyPhone.RegisterApp()` — see [docs/APPS.md](docs/APPS.md).
- **DarkRP integration** — wallet/job sync via `OnDarkRPVarChanged`,
  `DarkRP.formatMoney` display, `wolfyphone_*` convars. Everything degrades
  gracefully on sandbox.

## Install

1. Clone or extract into your server's addons folder:

   ```
   garrysmod/addons/gmod-iphone/
   ```

   (the repo root *is* the addon root — `lua/` sits directly inside it)

2. Restart the server or run `lua_openscript autorun/wolfyphone_init.lua`
   on a dev server.

3. In-game:
   - say `!phone` to get the SWEP, or spawn **Weapons → Wolfy → WolfyPhone**
   - hold the phone and left-click to open the UI (right-click closes)
   - or bind a key: `bind g wolfyphone`

See [docs/INSTALL.md](docs/INSTALL.md) for dedicated-server notes,
workshop publishing, and convars.

## Layout

```
lua/
  autorun/wolfyphone_init.lua   bootstrap + app auto-loader
  wolfyphone/
    sh_config.lua               colors, limits, sounds, model
    sh_util.lua                 validation/sanitize/DarkRP helpers
    sh_apps.lua                 app registry (RegisterApp, sorting)
    sv_net.lua                  net channels (<=16 char names) + senders
    sv_core.lua                 inbox store, persistence, calls, hooks
    cl_phone.lua                client state + net receivers + commands
    cl_frame.lua                phone shell: bezel, home, nav, toasts
    apps/                       one file per app (auto-loaded)
  weapons/weapon_wolfyphone.lua the SWEP
tests/smoke.lua                 LuaJIT smoke test (no GMod needed)
docs/                           install, app API, testing
```

## Server config

`lua/wolfyphone/sh_config.lua` holds every tunable. Runtime overrides:

```
wolfyphone_enabled 1        -- master switch
wolfyphone_globalvoice 1    -- calls audible map-wide
wolfyphone_maxmsglen 280    -- message cap
```

## Testing

Headless smoke test (real LuaJIT 5.1, stubbed GMod API — 44 checks):

```
luajit tests/smoke.lua    # or: bash tests/run_smoke.sh
```

Manual in-game checklist: [docs/TESTING.md](docs/TESTING.md).

## License

MIT — see [LICENSE](LICENSE).

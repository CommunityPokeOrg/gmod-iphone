# Testing WolfyPhone

## Headless smoke test

`tests/smoke.lua` runs the addon's shared + server code under plain
**LuaJIT 5.1** — the same runtime GMod uses — with a stubbed GMod API. It
syntax-checks every file, loads the autorun + all apps, and simulates two
players messaging, calling, persisting, and disconnecting.

```
bash tests/run_smoke.sh      # installs nothing; expects luajit on PATH
luajit tests/smoke.lua       # or run directly from the repo root
```

Expected output ends with `== 44 passed, 0 failed ==`.

Install LuaJIT if needed: `sudo apt-get install luajit`.

## In-game checklist (sandbox)

Two-player test — join a second client (or `bot_add` + `bot` won't trigger
UI; use a second machine/listen-server friend):

1. **Load**: console shows `[WolfyPhone] v1.0.0 loaded (6 apps)`.
2. **Get the SWEP**: say `!phone` → "Phone added to your weapons."
   Also try spawnmenu (Q → Weapons → Wolfy) and `wolfyphone_give`.
3. **Open/close**: equip phone, left-click → Derma phone appears on the
   right edge; right-click or Escape or the home pill closes it.
   Also `bind g wolfyphone` works holstered.
4. **Home screen**: 6 icons (Messages, Phone, Contacts, Wallet, Notes,
   Settings), live clock in the status bar.
5. **Messages**: send to the other player → toast + badge on recipient;
   thread view, bubbles, offline text to a disconnected key delivers on
   their next join (check `data/wolfyphone/inbox_*.json` on the server).
6. **Calls**: call the other player → they hear the ring + get
   accept/decline; accept → timer counts up; move far apart → still
   audible (if `wolfyphone_globalvoice 1`); hang up → both back to dialer.
   Wait out a ring to see the 30s no-answer drop.
7. **Contacts**: star a player, reopen app — favorite pinned on top.
8. **Wallet**: shows score in sandbox; shows DarkRP money/job on DarkRP.
9. **Notes**: create/save/edit/delete — survives map reload
   (`data/wolfyphone_notes.json` client-side).
10. **Settings**: accent color persists across sessions (cookies);
    sounds toggle silences toasts.
11. **Convars**: `wolfyphone_enabled 0` → messages/calls rejected;
    set back to 1.

## DarkRP test

On a DarkRP server: wallet shows `DarkRP.formatMoney(money)`; change job or
money (e.g. `/job`, paycheck) → Wallet app updates live via
`OnDarkRPVarChanged`.

## Troubleshooting

- **"apps" count is 0 / icons missing**: `file.Find` needs the addon under
  `garrysmod/addons/<dir>/lua/...` — don't nest an extra folder.
- **No UI on click**: check console for Lua errors; ensure the addon is
  installed server-side (not client-side `downloads/`).
- **Players can't hear calls**: `wolfyphone_globalvoice` convar, or another
  voice addon returning a value in `PlayerCanHearPlayersVoice` after ours.

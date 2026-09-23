# Installing WolfyPhone

## From source (recommended for development)

```
cd garrysmod/addons
git clone https://github.com/CommunityPokeOrg/gmod-iphone.git gmod-iphone
```

The repository root is the addon root. The folder name inside `addons/` does
not matter, but keep it stable so `file.Find` keeps resolving app files.

## Workshop / .gma publishing

`addon.json` is already set up for `gmpublish`:

```
gmad create -folder . -out wolfyphone.gma
gmpublish update -addon wolfyphone.gma -id <workshop_id>
```

`docs/`, `tests/`, git files, and markdown are excluded via `ignore`.

## Giving players the phone

| Method | How |
|---|---|
| Chat command | Say `!phone` (config: `Config.ChatCommand`, `GiveOnCommand`) |
| Spawnmenu | Q → Weapons → Wolfy → WolfyPhone (sandbox) |
| Console | `wolfyphone_give` |
| Auto-give | `Config.GiveToNewPlayers = true` |
| Keybind | `bind g wolfyphone` opens/closes without the SWEP |

## Server configuration

Edit `lua/wolfyphone/sh_config.lua` for persistent changes, or set convars:

- `wolfyphone_enabled` (default 1) — disables all receivers when 0
- `wolfyphone_globalvoice` (default 1) — map-wide call audio
- `wolfyphone_maxmsglen` (default 280)

## DarkRP

No extra setup. When `DarkRP` exists the addon automatically:

- shows real wallet/job/salary in the Wallet app
- re-syncs clients on `OnDarkRPVarChanged` (money/job/salary)
- formats currency with `DarkRP.formatMoney`

On sandbox/other gamemodes the Wallet app shows score and team instead.

## Requirements / limitations

- No custom models, materials, or sounds — everything uses stock HL2/GMod
  assets, so there are no downloads for players.
- Voice calls use Garry's Mod voice; nothing to install.
- Persistence is file-based (`data/wolfyphone/`) — no SQL.
- The world model defaults to `models/props/cs_office/phone.mdl`
  (Counter-Strike content — mounted by default in most installs). Change
  `Config.PhoneWorldModel` if you run a stripped-down server.

# Void of Exile Launcher

Installs, updates and starts [Void of Exile](https://github.com/huggan360/void_of_exile), and runs a
[Void of Exile server](https://github.com/huggan360/void_of_exile_server) of your own. Built with Godot 4.7
(stock, GL Compatibility) for Linux, Windows and macOS.

**Game** and **Server** at the top pick what the big button does.

- Sign in, switch between saved accounts (only session tokens are kept, never passwords)
- Newest release image, version and notes from `https://void.plainshow.se/launcher/v1/latest`
- Delta updates: a changed file is rebuilt from the chunks already on disk; only new chunks are downloaded and every chunk is SHA-256 checked
- The game only starts on the latest release; the signed-in session is passed to it in `VOID_LAUNCHER_SESSION`

Game files go to the launcher's data folder (`VoidOfExileLauncher/game`); Settings has Open folder and Repair files.

## Server

Signed in only. The Server page installs the server build (`server_build/`, from `/launcher/v1/server`; its files
are the game's under another name, so it shares chunks with the game), and keeps its settings, key and world
saves in `server/`. A host can set name, message, players, port, memory, player contact and public listing;
everything else is the official game (release servers are locked). The key comes from the account service
(`POST /api/host/key`) the first time a signed-in account starts it.

While it runs, the page lists players (class, level, where, ping) with Kick, and shows the log. The launcher
talks to its server on the status port (port + 1) with `VRADMIN <token> players|kick <name>|stop`, only on this
computer, with a token it sets in `VOID_ADMIN_TOKEN`. Stop and closing the launcher save every player first.
Linux only for now, like the game.

## Build

```bash
./build.sh /path/to/godot Linux Windows macOS   # zips land in build/
```

Pushing a `v*` tag builds all three on GitHub Actions and attaches `VoidOfExileLauncher-{Linux,Windows,macOS}.zip` to the release. The website's download buttons point at the latest release.

The macOS build is ad-hoc signed and not notarized: open it with right click > Open the first time.

## Layout

| File | |
| --- | --- |
| `scripts/launcher.gd` | Screen: sidebar, play area, login, patch notes, settings |
| `scripts/updater.gd` | Install and delta update from the release store (game and server) |
| `scripts/server_host.gd` | The hosted server: install, settings, key, start/stop, log, players, kick |
| `scripts/accounts.gd` | Saved sessions |
| `scripts/net.gd` | HTTP helpers |
| `scripts/ui.gd` | The game's black stone UI look |
| `scripts/voxel_drift.gd`, `scripts/ink_weapon.gd` | Drifting voxels, the game's ink loader |

Bree Serif is licensed under the SIL Open Font License (`assets/OFL.txt`).

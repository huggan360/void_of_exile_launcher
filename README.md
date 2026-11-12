# Void of Exile Launcher

Installs, updates and starts [Void of Exile](https://github.com/huggan360/void_of_exile). Built with Godot 4.7 (stock, GL Compatibility) for Linux, Windows and macOS.

- Sign in, switch between saved accounts (only session tokens are kept, never passwords)
- Newest release image, version and notes from `https://void.plainshow.se/launcher/v1/latest`
- Delta updates: a changed file is rebuilt from the chunks already on disk; only new chunks are downloaded and every chunk is SHA-256 checked
- The game only starts on the latest release; the signed-in session is passed to it in `VOID_LAUNCHER_SESSION`

Game files go to the launcher's data folder (`VoidOfExileLauncher/game`); Settings has Open folder and Repair files.

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
| `scripts/updater.gd` | Install and delta update from the release store |
| `scripts/accounts.gd` | Saved sessions |
| `scripts/net.gd` | HTTP helpers |
| `scripts/ui.gd` | The game's black stone UI look |
| `scripts/voxel_drift.gd`, `scripts/ink_weapon.gd` | Drifting voxels, the game's ink loader |

Bree Serif is licensed under the SIL Open Font License (`assets/OFL.txt`).

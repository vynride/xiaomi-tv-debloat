# xiaomi-tv-debloat

By [vynride](https://github.com/vynride).

Removes ads and tracking from a Xiaomi Mi TV and reduces input lag, using ADB without root. The scripts work on other Android TVs.

## What it does

| Change | How |
|---|---|
| Disables analytics, PatchWall, recommendation feeds and unused preinstalled apps | `pm disable-user --user 0` |
| Stops streaming apps from running in the background | `appops set <pkg> RUN_IN_BACKGROUND ignore` |
| Blocks ad and tracker domains | Private DNS → `dns.adguard-dns.com` |
| Halves UI animation time | `settings put global *_animation_scale 0.5` |
| Replaces the stock home screen with a lighter launcher | install launcher, disable stock one |
| Turns off home-screen previews, Play Store auto-update, ad ID | on-screen settings |

## Results (approx.)

| | Before | After |
|---|---|---|
| Free RAM | ~250 MB | ~320 MB |
| CPU idle after boot | ~10% | ~35% |

## Quick start

Requirements: [`adb`](https://developer.android.com/tools/releases/platform-tools) (macOS: `brew install android-platform-tools`), TV and computer on the same network.

1. On the TV: Settings → Device Preferences → About → press OK on *Build* seven times, then Developer options → USB debugging on. Most Mi TVs then accept ADB on port 5555.
2. Connect, and accept the prompt on the TV:
   ```sh
   export TV_HOST=192.168.1.50      # your TV's IP
   adb connect $TV_HOST:5555
   ```
3. Check the current state:
   ```sh
   ./scripts/audit.sh > before.txt
   ```
4. Copy `profiles/xiaomi-mitv-android9` (or `profiles/generic-android-tv`) and remove anything you use.
5. Apply, reboot, check again:
   ```sh
   ./scripts/apply.sh profiles/my-tv
   adb reboot
   ./scripts/audit.sh > after.txt
   ```
6. Optional: install [Projectivy Launcher](https://play.google.com/store/apps/details?id=com.spocky.projengmenu) from the Play Store, then:
   ```sh
   ./scripts/swap-launcher.sh com.spocky.projengmenu/.ui.home.MainActivity
   ```
7. Turn USB debugging off when done.

To undo: `./backups/<timestamp>/undo.sh`, then `adb reboot`.

## Notes

- Use `pm disable-user`, not `pm uninstall`. Uninstalling system packages can break Home or HDMI input switching.
- Leave inputs/tuner (`com.droidlogic.*`, `com.android.tv*`, `com.android.providers.tv`), Play Services (`gms`, `gsf`), system UI, settings, voice search (`katniss`), casting (`mediashell`) and the update service alone.
- Install the new launcher before disabling the stock one.
- Run `adb shell cmd appops write-settings` and wait ~20 s before rebooting, or changes can be lost. The scripts do this.

## Docs

- [docs/METHODOLOGY.md](docs/METHODOLOGY.md): step-by-step process
- [docs/PROMPT.md](docs/PROMPT.md): prompt for doing this with an AI coding agent

## License

GPL-3.0, see [LICENSE](LICENSE).

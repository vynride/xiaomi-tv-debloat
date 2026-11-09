# Methodology

The process used on the test TV, in order, with the reasoning behind each step. The same order works for any Android TV.

## 0. Diagnose first

Slow Android TVs are almost never slow because of the CPU. On the test TV (1 GB RAM), `audit.sh` showed:

- `MemAvailable` around 220–265 MB, and the 256 MB zram swap almost completely full
- `kswapd0` (the kernel's memory reclaimer) near the top of `top`
- 77% of CPU time spent waiting on storage (`iow`), i.e. the TV was swapping and re-reading evicted apps
- Every installed streaming app running in the background seconds after boot
- The manufacturer's content hub (PatchWall) holding ~65 MB even though it wasn't the home screen

That's memory pressure: too many apps competing for too little RAM, so the system spends its time evicting and reloading instead of responding to the remote. **Everything below is about reducing what's resident in memory.**

Useful read-only commands:

```sh
adb shell cat /proc/meminfo | head -4
adb shell top -b -n 1 -m 15
adb shell dumpsys meminfo | sed -n '/by process/,/by OOM/p' | head -30
adb shell pm list packages -s    # system packages
adb shell pm list packages -3    # user-installed packages
```

## 1. Snapshot the current state

Before touching anything, save the package list, disabled packages, global settings and current home activity. `scripts/apply.sh` does this automatically into `backups/<timestamp>/` and builds an `undo.sh` from it.

## 2. Disable telemetry, ad hubs and bloat

Sort the package list into three groups:

| Group | Examples | Action |
|---|---|---|
| Analytics / telemetry | `com.miui.tv.analytics`, `com.xiaomi.statistic`, `com.google.android.feedback` | Disable |
| Sponsored content / recommendation feeders | `com.mitv.tvhome.atv` (PatchWall), `com.google.android.tvrecommendations` | Disable |
| Preinstalled apps you don't use | Play Movies, Play Games, user manual, print spooler | Disable |
| Core system, inputs, tuner, Play Services, voice, casting, updates | `com.droidlogic.*`, `com.android.tv*`, `gms`, `gsf`, `katniss`, `mediashell` | **Leave alone** |

Rank candidates by what they cost: something in the `dumpsys meminfo` top 20 is worth far more than a package that never runs. Disabling an inert gallery app gains nothing measurable.

```sh
adb shell pm disable-user --user 0 <package>   # undo: adb shell pm enable <package>
```

## 3. Stop apps from running in the background

Streaming apps start at boot to refresh "continue watching" rows and keep themselves warm. On a 1 GB TV that's tens of MB each. Denying `RUN_IN_BACKGROUND` stops their background services. The app still opens and plays normally, just a few seconds slower to cold-start.

```sh
adb shell cmd appops set <package> RUN_IN_BACKGROUND ignore
adb shell cmd appops write-settings    # flush to disk before any reboot
```

Exclude anything you control from your phone (Spotify Connect, casting receivers), or the TV stops showing up as a target.

## 4. System settings

```sh
# Faster UI
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5

# Network-wide ad/tracker blocking via DNS-over-TLS (Android 9+)
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier dns.adguard-dns.com

# No background Wi-Fi/Bluetooth scanning
adb shell settings put global wifi_scan_always_enabled 0
adb shell settings put global ble_scan_always_enabled 0
```

Verify Private DNS is actually in use. `UsePrivateDns: true` and a `VALIDATED` network mean it's working:

```sh
adb shell dumpsys connectivity | grep -E "UsePrivateDns|VALIDATED" | head -3
```

## 5. Reboot and verify persistence

Reboot, wait for `sys.boot_completed`, and re-run `audit.sh`. On the test TV the first attempt **lost every package change** because it rebooted before Android had written them to disk. Flush (`cmd appops write-settings`), wait ~20 s, then reboot.

```sh
adb reboot
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 5; done
./scripts/audit.sh
```

## 6. Settings that only exist in the UI

Some settings aren't exposed to `adb shell settings`. They're set by opening the right screen with `am start` and pressing remote keys with `input keyevent`:

| Setting | How to open it | Why |
|---|---|---|
| Play Store auto-update → off | `am start -n com.android.vending/com.google.android.finsky.tvsettings.TvSettingsActivity` | Background downloads and recompilation are a major source of lag on low-end TVs |
| Home-screen video/audio previews → off | `am start -n com.google.android.tvlauncher/.settings.HomeScreenSettingsActivity` | Autoplaying previews start a video decoder just from hovering a tile |
| Delete advertising ID | `am start -a com.google.android.gms.settings.ADS_PRIVACY` | Stops cross-app ad tracking |

Navigate with `adb shell input keyevent KEYCODE_DPAD_DOWN` / `KEYCODE_DPAD_CENTER`. Check where you are with a screenshot (`adb exec-out screencap -p > s.png`) or a UI dump (`adb shell uiautomator dump /sdcard/ui.xml`). Don't press keys blind: menus remember their last position, and lists scroll.

Set auto-update off only if you'll update apps by hand now and then.

## 7. Replace the launcher

The stock home screen is both a memory cost (~44 MB on the test TV) and where the sponsored rows live. Every guide that measures anything ends up replacing it. Order matters:

1. Install the new launcher from the Play Store. The test TV used **Projectivy Launcher**. On the setup screens, allow TV listings (needed for HDMI inputs), and decline notification access and usage reporting.
2. Confirm it registers as a HOME app:
   `adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME`
3. Make it the home screen. `set-home-activity` alone may not work, because the stock launcher can have a higher priority, so disable the stock launcher too:
   ```sh
   ./scripts/swap-launcher.sh com.spocky.projengmenu/.ui.home.MainActivity
   ```
4. Reboot and confirm it comes up on boot.

## 8. Replacement apps

| Removed / avoided | Replacement | Notes |
|---|---|---|
| YouTube ads | [SmartTube](https://github.com/yuliskov/SmartTube) | Not on the Play Store. Download the `armeabi-v7a` (32-bit ARM) or `arm64-v8a` APK from the official GitHub releases, check the file size matches the release listing, then `adb install`. Updates itself. |
| Manufacturer media/USB players | [VLC](https://play.google.com/store/apps/details?id=org.videolan.vlc) | Has a proper remote-friendly TV UI. mpv-android is touch-oriented. |

Find the TV's architecture with `adb shell getprop ro.product.cpu.abi`.

## 9. Optional extras

- **Precompile apps:** `adb shell cmd package bg-dexopt-job` runs the optimisation Android normally does overnight while idle, which TVs rarely are. It took 17 minutes on the test TV and failed on its final step with a permission error, but the main compilation step completed. Run it after updates finish, not during.
- **Free cache:** `adb shell pm trim-caches 999G`. Only useful when storage is nearly full.
- **TRIM storage:** `adb shell sm fstrim`.

## 10. Clean up

- Turn **USB debugging off** on the TV. On many TVs, it leaves port 5555 open to your whole network.
- Keep the `backups/` folder. It has your undo script.

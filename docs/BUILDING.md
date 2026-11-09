# Building and testing

## Requirements
- Godot **4.7.2 stable** (standard build, not .NET)
- Android export templates for 4.7.2. Either install the full template bundle from the Godot editor,
  or fetch only the Android entries (about 230 MB instead of 1.2 GB):
  `python tools/fetch_android_templates.py 4.7.2`
- JDK 17 or 21, Android SDK with build-tools (for `apksigner`)
- A debug keystore (Godot creates one, or use
  `keytool -genkeypair -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -dname "CN=Android Debug,O=Android,C=US"`)

Set in Godot *Editor Settings → Export → Android*: SDK path, Java SDK path, debug keystore.
Nothing secret is stored in `export_presets.cfg`.

## Commands
```bash
# import (first run)
godot --headless --path . --import

# headless test suite (47 checks: data, generator determinism, structures, loot,
# mesher winding, inventory/crafting/survival logic, threaded streaming, edits)
godot --headless --path . res://tests/test_scene.tscn

# windowed end-to-end bot (19 checks: spawn, walk, mine, place, craft, save/load,
# combat, loot, machines, offline simulation, rover, planet jump). Writes test_output/*.png
godot --path . -- autotest

# menu screenshots (title, settings, new expedition, store)
godot --path . -- menutest

# Android APK
godot --headless --path . --export-debug "Android" build/PlanetCraft-debug.apk
```

## Release builds
For a Play-Store-style release build, create your own keystore and supply it through Godot's
environment variables. Never commit it:
```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.jks
GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
godot --headless --path . --export-release "Android" build/PlanetCraft.apk
```
The public GitHub Release currently ships the **debug-signed** APK built by CI.

## Device testing
`tools/device.ps1` (Windows PowerShell) wraps adb for screenshots and log reading:
```
powershell -ExecutionPolicy Bypass -File tools/device.ps1 shot my_screen
powershell -ExecutionPolicy Bypass -File tools/device.ps1 perf
```
The game prints a `[PERF] fps=… chunks=… creatures=… draw_calls=…` line to logcat every 5 seconds.

## Continuous integration
`.github/workflows/android.yml` runs on every push to `main`. On `ubuntu-latest` it:
1. downloads Godot 4.7.2 and the Android template entries,
2. generates a throwaway debug keystore and editor settings,
3. imports the project and runs the headless test suite,
4. exports the debug APK and uploads it as an artifact,
5. on a `v*` tag, attaches the APK to a GitHub Release.

# Building and testing

## Requirements
- Godot **4.7.2 stable** (standard build, not .NET)
- Android export templates for 4.7.2. Either install the full template bundle from the Godot editor,
  or fetch only the Android entries:
  `python tools/fetch_android_templates.py 4.7.2`
- **JDK 17 or 21** and the Android SDK (build-tools + platform 36). The Gradle build downloads its
  wrapper and Maven dependencies on the first run, so network access is required once.
- A debug keystore (Godot creates one, or use
  `keytool -genkeypair -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -dname "CN=Android Debug,O=Android,C=US"`)

Set in Godot *Editor Settings → Export → Android*: SDK path, Java SDK path, debug keystore.
Nothing secret is stored in `export_presets.cfg`.

## Gradle build template and ad plugins
The store build uses Gradle because v2 Android plugins (AdMob, Play Billing) require it. `android/build/`
is generated and gitignored; recreate it after a fresh clone:

```bash
mkdir -p android/build
unzip -q "$APPDATA/Godot/export_templates/4.7.2.stable/android_source.zip" -d android/build
printf '4.7.2.stable\n' > android/.build_version
touch android/build/.gdignore   # keep the Gradle template out of the game resource scan
```

The AdMob addon (`addons/admob`, Poing Studios v5.1.0) expects its Android binaries in
`addons/admob/android/bin/`. They are gitignored by the addon; fetch the matching template pack once:

```bash
curl -L -o /tmp/admob-template.zip \
  https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.7.2.zip
mkdir -p addons/admob/android/bin
unzip -q /tmp/admob-template.zip 'package.gd' 'ads/*' -d addons/admob/android/bin
```

Play Billing ships its AAR inside `addons/GodotGooglePlayBilling/bin/` and is committed.

## AdMob and Play Billing configuration
The repository ships Google's **test** values so the feature works immediately:

| Where | Key | Shipped value |
|---|---|---|
| `project.godot` | `admob/general/android/app_id` | Google sample app id `ca-app-pub-3940256099942544~3347511713` |
| `project.godot` | `planetcraft/ads/banner_unit` | adaptive-banner test unit |
| `project.godot` | `planetcraft/ads/interstitial_unit` | interstitial test unit |
| `project.godot` | `planetcraft/ads/rewarded_unit` | rewarded test unit |
| `scripts/autoload/iap.gd` | `PRODUCT` | `remove_ads` |

Before publishing:
1. Create the Android app and banner/interstitial/rewarded ad units in AdMob; replace the four IDs.
   Configure a GDPR/IAB message under *AdMob → Privacy & messaging* (UMP). The code asks for consent
   before initialising the SDK and exposes *Privacy options* in Settings/About.
2. In Play Console create a one-time in-app product with **product ID `remove_ads`**, price **USD 4.99**,
   and activate it. Upload a signed build to an internal/closed track, add license testers, and run a
   purchase and a restore. The code acknowledges the purchase and stores the entitlement in
   `user://profile.dat`; a successful `queryPurchases` with no purchase on explicit restore revokes it.
3. Add a privacy policy URL to the Play listing and mention AdMob/Play Billing.
4. Replace the debug keystore with a release keystore (below) and export an AAB.

Note: a sideloaded debug APK without the Play Console product shows *Remove Ads is not available* —
that is expected; the UI fails gracefully and never crashes.

## Commands
```bash
# import (first run)
godot --headless --path . --import

# headless test suite (53 checks: data, generator determinism, structures, loot,
# mesher winding, inventory/crafting/survival logic, entitlements, banner safe area,
# threaded streaming, edits). Exit code 0 = all passed.
godot --headless --path . res://tests/test_scene.tscn

# windowed end-to-end bot (19 checks). Writes test_output/*.png
godot --path . -- autotest

# menu screenshots (title, settings, new expedition, store)
godot --path . -- menutest

# first-run Field Guide screenshots
godot --path . -- onboardtest

# splash chain screenshots (title cinematic, F7 brand, menu); takes ~35 s
godot --path . -- splashtest

# cinematic intro + F7 brand OGV rebuild (needs ffmpeg with libtheora/libvorbis, edge-tts, fontTools)
python tools/build_intro.py

# Android APK (Gradle, ads + billing)
godot --headless --path . --export-debug "Android" build/PlanetCraft-store-debug.apk
```
Gradle debug APKs are large (~140 MB) because the debug Godot template carries symbols. For a Play
release use a release build/AAB; the intro OGV adds ~8.6 MB, the ads/billing SDKs a few MB.

## Release builds
Create your own keystore and supply it through Godot's environment variables. Never commit it:
```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.jks
GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
godot --headless --path . --export-release "Android" build/PlanetCraft.aab
```
Set `gradle_build/export_format=1` in `export_presets.cfg` for an AAB (0 = APK for device tests).

## Device testing
`tools/device.ps1` (Windows PowerShell) wraps adb for screenshots and log reading:
```
powershell -ExecutionPolicy Bypass -File tools/device.ps1 shot my_screen
powershell -ExecutionPolicy Bypass -File tools/device.ps1 perf
```
The game prints a `[PERF] fps=… chunks=… creatures=… draw_calls=…` line to logcat every 5 seconds.
Ad logs are tagged `GoogleMobileAdsNetwork`, `UserMessagingPlatform` and `godot`.

## Continuous integration
`.github/workflows/android.yml` runs on every push to `main`. On `ubuntu-latest` it:
1. downloads Godot 4.7.2 and the Android template entries,
2. generates a throwaway debug keystore and editor settings,
3. installs the Gradle build template and the AdMob Android binaries, writes `.build_version`,
4. imports the project, runs the headless suite,
5. exports the Gradle debug APK and uploads it as an artifact,
6. on a `v*` tag, attaches the APK to a GitHub Release.

The CI APK uses Google test ads unless the four IDs in `project.godot` are replaced.

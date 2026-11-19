# Third-party notices

PlanetCraft's own source code, art, music and the F7 Developer brand ident are MIT-licensed or
original F7 content (see `LICENSE`). The following third-party software and assets are used to build
or run the game. None of it is modified.

| Component | Use | License |
|---|---|---|
| [Godot Engine 4.7.2](https://godotengine.org) | Game engine; the Android APK contains the official Godot export template binary | MIT (Godot Engine contributors, Juan Linietsky, Ariel Manzur) |
| Libraries bundled inside the Godot template (FreeType, HarfBuzz, libpng, zlib/zstd, Mbed TLS, etc.) | Font rendering, image and compression support in the engine | Various permissive licenses; full list in Godot's `COPYRIGHT.txt` and in-engine *Help → About → Third-party Licenses* |
| Godot default font (Open Sans, bundled in the engine) | In-game UI text | SIL Open Font License 1.1 |
| [Poing Studios AdMob plugin](https://github.com/poingstudios/godot-admob-plugin) v5.1.0 | Android bridge for banner/interstitial/rewarded ads and UMP consent | MIT (Poing Studios); its Android AARs are fetched into `addons/admob/android/bin` and are not committed |
| [Google Mobile Ads SDK](https://developers.google.com/admob/android/sdk) 1.4.0 | Ad serving (Google test app/unit IDs by default) | Google APIs Terms of Service / Mobile Ads SDK terms |
| [Google User Messaging Platform (UMP)](https://developers.google.com/admob/android/privacy) | Consent form and privacy options | Google APIs Terms of Service |
| [GodotGooglePlayBilling](https://github.com/godot-sdk-integrations/godot-google-play-billing) v3.3.0 | Android bridge for the Remove Ads product | MIT (Godot Engine contributors) |
| [Google Play Billing Library](https://developer.android.com/google/play/billing) 9.1.0 | Purchase, acknowledgement and restore | Google Play Billing Library terms |
| Outfit SemiBold and DM Sans Medium fonts | Typography rendered into the intro video only | SIL Open Font License 1.1 (see the trailer kit's `OFL-*.txt`) |
| Microsoft Edge neural TTS (`en-US-AndrewNeural`) | Generated English voice-over in the intro (placeholder; see `docs/ASSETS.md`) | Microsoft Edge/Speech service terms; replace with a licensed VO before commercial release |
| [ffmpeg](https://ffmpeg.org) (Gyan full build) | Offline asset generation for the intro; not shipped | LGPL/GPL build used as a build tool |
| [fontTools](https://github.com/fonttools/fonttools), [Pillow](https://python-pillow.org), [edge-tts](https://github.com/rany2/edge-tts) | Build tooling for the intro | MIT / HPND / GPL-3.0 build tool, not shipped |
| [GitHub Actions](https://github.com/features/actions): `actions/checkout`, `actions/setup-java`, `actions/upload-artifact`, `softprops/action-gh-release` | CI only, not shipped | MIT |
| Eclipse Temurin JDK, Android SDK build tools | Build tools only, not shipped | GPLv2 with Classpath Exception / Android SDK License |

**Android permissions:** the store build requests `INTERNET` and `ACCESS_NETWORK_STATE` for ads and
Play Billing, and the Google SDKs declare `AD_ID`. The offline Kiroween v0.1.2 APK requests no
permissions. Remove Ads stops all banner, interstitial and rewarded requests after purchase.

The Godot license text: https://godotengine.org/license

# Third-party notices

PlanetCraft's own source code is MIT-licensed (see `LICENSE`). The following third-party
software is used to build or run the game. None of it is modified.

| Component | Use | License |
|---|---|---|
| [Godot Engine 4.7.2](https://godotengine.org) | Game engine; the Android APK contains the official Godot export template binary | MIT (Godot Engine contributors, Juan Linietsky, Ariel Manzur) |
| Libraries bundled inside the Godot template (FreeType, HarfBuzz, libpng, zlib/zstd, Mbed TLS, etc.) | Font rendering, image and compression support in the engine | Various permissive licenses; full list in Godot's `COPYRIGHT.txt` and in-engine *Help → About → Third-party Licenses* |
| Godot default font (Open Sans, bundled in the engine) | UI text | SIL Open Font License 1.1 |
| [GitHub Actions](https://github.com/features/actions): `actions/checkout`, `actions/setup-java`, `actions/upload-artifact`, `softprops/action-gh-release` | CI only, not shipped | MIT |
| Eclipse Temurin JDK, Android SDK build tools | Build tools only, not shipped | GPLv2 with Classpath Exception / Android SDK License |

The Godot license text: https://godotengine.org/license

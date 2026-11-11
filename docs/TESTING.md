# Test results

All results below were produced on November 9, 2026 during development. Re-run them with the
commands in [BUILDING.md](BUILDING.md).

## Headless suite: `tests/test_runner.gd`
**47 / 47 passed** (Windows, Godot 4.7.2 headless; also run in CI on Ubuntu for every push).

Covers: data integrity (every recipe input/output and block drop exists), Texture2DArray layer
count, deterministic generation for all 6 worlds (same seed = same chunk, other seed = different),
structures appearing over 256 chunks (ruins, obelisks, hives, wrecks, shrines), loot table rolls,
store/rarity data, greedy mesher output and clockwise front-face winding (0 bad triangles of 3,490),
inventory stacking/removal/crafting/serialisation, survival oxygen damage and refill, med kits,
threaded streaming of a radius-4 area, block edits, border-edit neighbour invalidation, remesh after
edit, and edit deltas surviving regeneration.

Sample timings on the dev PC: chunk generation about 8–17 ms, meshing a full column about 31–42 ms
(both off the main thread).

## End-to-end bot: `tests/autoplay.gd`
**19 / 19 passed** (windowed, 1600×720). Steps: world load and spawn, crash pod built, walking,
mining adds items, placing consumes a block, crafting a Fabricator, jump/jetpack, save and reload of
edits and inventory, plasma pistol kills a creature, loot orbs deliver drops, machines register,
hydroponics produces, offline simulation produces, rover drives and exits, a jump to Kryos lands
and carries the inventory. Desktop FPS during the run: 59–60.

## CI
GitHub Actions `Android build`: green on every commit since the SDK fix (the first run failed in
`setup-android`, fixed by using the runner's preinstalled SDK). Each run exports a debug APK.

## On-device (Redmi Note 11, 2201117TY, Snapdragon 680 "bengal", Adreno 610, Android 13, 2400×1080)
| Build | Scenario | Result (logcat `[PERF]`) |
|---|---|---|
| Phase 1, native resolution, bloom on | Walking on Verdania | 16–21 FPS (too slow) |
| Phase 1 after tuning (60% resolution scale, bloom off on mobile, per-vertex sun light) | Same | **50 FPS**, 149 chunks |
| Phases 2–4 (creatures, machines, rover) | New game at crash pod, 11 creatures | 43–46 FPS |
| Same + merged creature meshes, cap 8 on mobile | Continue, 8 creatures | 36–42 FPS while chunks streamed, then 41–42 |
| Touch input via `adb shell input` (swipe-look, hold MINE) | | Worked; screen captured in `docs/screenshots/android_05_spawn.jpg` |

**v0.1.0 build on the device (Nov 10):** installed and launched. Title screen, Continue, the HUD and touch
buttons work. FPS was 40–47 while exploring with 8 creatures, dipping to 28–30 while new chunks
streamed in. Problems found and fixed in v0.1.1: menus and settings could not be scrolled by touch
(mouse emulation was off), the title menu overflowed the screen, the mining laser launched
creatures, and there was a constant noise "hiss" in the sound.

**v0.1.1 build:** passed the headless suite (47/47), the autoplay bot (19/19) and the creature
knockback test on desktop. It was **not** installed on the phone because the USB/adb connection
dropped. Install it from the release and re-check scrolling and FPS.

**v0.1.2 build:** new icon, splash, intro, settings, Rate/Share. Headless 47/47 and the menu screenshots pass on desktop. Not yet run on the phone (adb disconnected). Share and vibration use Android-only APIs and are **untested on a device**.

## Not covered by automated tests
Story progression past the first directives, every side job, the obelisk trial and starfall events,
terraforming to 100%, the boss fight and the store purchase flow were implemented and compile, but
were only partly exercised (menu screenshots show the store UI; nothing was bought in a test).

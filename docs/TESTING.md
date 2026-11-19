# Test results

Results below were produced on November 9–19, 2026 during development. Re-run them with the
commands in [BUILDING.md](BUILDING.md).

## Headless suite: `tests/test_runner.gd`
**53 / 53 passed** (Windows, Godot 4.7.2 headless; also run in CI on Ubuntu for every push).
The v0.2.0 additions check that the onboarding flag and Remove Ads entitlement persist, that the
banner keeps 56 dp clear of bottom and side Android navigation bars, that the title and F7 brand
splash videos exist, and that the IAP product id/list price are correct.

Covers: data integrity (every recipe input/output and block drop exists), Texture2DArray layer
count, deterministic generation for all 6 worlds (same seed = same chunk, other seed = different),
structures appearing over 256 chunks (ruins, obelisks, hives, wrecks, shrines), loot table rolls,
store/rarity data, greedy mesher output and clockwise front-face winding (0 bad triangles of 3,490),
inventory stacking/removal/crafting/serialisation, survival oxygen damage and refill, med kits,
threaded streaming of a radius-4 area, block edits, border-edit neighbour invalidation, remesh after
edit, and edit deltas surviving regeneration. v0.2.0 adds six checks: onboarding flag persists,
Remove Ads entitlement persists, banner bottom/side safe margins, splash videos present, and the
Remove Ads product id and USD 4.99 list price.

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

**v0.2.0 store build (Nov 19, 2026, on-device):** Gradle APK with AdMob + Play Billing installed
over v0.1.2 data. Verified on the Redmi Note 11:
- Cinematic title splash plays with English voice-over and burned-in captions; the F7 Developer
  brand ident follows and the menu appears. Tap-to-skip is present.
- Google UMP consent check ran (`IABTCF_gdprApplies=0` in Indonesia, no form), AdMob initialised and
  served a Google test banner on the title screen. The banner sits bottom-right, 56 dp above the
  bottom edge and clear of the menu buttons; it disappears when the Store, Remove Ads, Settings or
  Field Guide are open and returns on close.
- Stellar Store shows **WATCH AD · +25 SHARDS**. The test rewarded video played to completion; AdMob
  reported "Reward diberikan", the store returned with **25 Stellar Shards** and the message
  "+25 Stellar Shards. Thank you."
- Remove Ads overlay opens from the menu and Settings with BUY · $4.99 and RESTORE. With no Play
  Console product in this sideloaded build the status reads "Remove Ads is not available"; the tap
  fails gracefully (no crash). A real purchase/restore still needs the Play Console product.
- Settings shows PURCHASES (Buy/Restore, price, status) and PRIVACY (Ad privacy → Privacy options).
- Interstitial and rewarded ads preloaded (GMA requests visible); the interstitial show path after a
  planet jump was not exercised on this build.

Onboarding (Field Guide): the three pages were rendered and captured on desktop
(`test_output/onboard_0*.png`); the device profile was already marked onboarded by earlier
interaction, so the first-run card was not shown again in this session.

**v0.1.2 build:** new icon, splash, intro, settings, Rate/Share. Headless 47/47 and the menu screenshots pass on desktop. Share and vibration use Android-only APIs.

## Not covered by automated tests
Story progression past the first directives, every side job, the obelisk trial and starfall events,
terraforming to 100%, the boss fight and the Stellar Store purchase flow were implemented and
compile, but were only partly exercised (menu screenshots show the store UI; nothing was bought in a
test). For the store build: a real Remove Ads purchase, refund/revocation, EEA consent forms, the
interstitial display after a planet jump, and banner placement on a device with visible 3-button
navigation are still untested. The English voice-over is neural TTS (Edge, en-US-AndrewNeural) and
is a placeholder for a licensed recording; see ASSETS.md.

# Roadmap and known limitations

## Done (v0.1.0)
Phases 1–4 from the original brief are implemented in a first version: one-world foundation,
core gameplay, expansion (6 worlds, ship, NPCs, quests, dungeon-style structures, boss) and full-game
systems (terraforming, colony automation, events, store). Tested as described in
[TESTING.md](TESTING.md).

## Known limitations (honest list)
- **Balancing is first-pass.** Costs, drop rates, drain rates and the story pace have not been
  tuned with real players. Getting Stellar Shards is intentionally slow.
- **Space station:** you can build anywhere in the Kessler Belt, but there is no dedicated station
  module system or zero-gravity building mode.
- **Conveyors and cables** are placeable blocks but are not simulated. The power grid is one shared
  pool per planet (no wiring), and item transport is done by the miner drone and machine storage.
- **Colony NPC civilisation:** the colony level is computed from your machines, but colonists do
  not build autonomously.
- **Dungeons** are surface structures (ruins, obelisk trials, hives, wrecks) rather than
  multi-room underground dungeons.
- **Lighting:** no real-time shadows; sky light is approximated per column, so overhangs are slightly
  too dark and lamps light at most 8 positions near the player.
- **LOD:** there is no low-detail far-terrain mesh; view distance plus fog bound the cost.
- **Water** does not flow; it is generated as a static sea level.
- **Audio** is synthesised: functional and original, but simple compared to recorded sound design.
- The release APK is **debug-signed**.
- **Intro voice-over** is a generated neural-TTS placeholder, not a licensed studio recording.
- **Ad IDs** ship as Google test values; the Remove Ads Product ID exists in code but not yet in
  Play Console, so a sideloaded build cannot complete a real purchase.
- **Intro footage** is real captured gameplay, so the in-game HUD is visible in the montage.
- **Onboarding** was screenshot-tested on desktop; a fresh-install device capture is still pending.
- Tested on one physical device (Redmi Note 11 / Snapdragon 680). Performance on other GPUs is unknown.

## Next steps (planned, not implemented)
1. Wired power networks and real conveyor item transport.
2. Modular space-station building in the Kessler Belt with zero-g movement.
3. Underground multi-room dungeons with locked doors and a second boss.
4. Colonist AI that builds from blueprints.
5. Far-terrain LOD meshes for larger view distances on high-end phones.
6. Flowing water and lava.
7. Balancing pass from playtest telemetry collected locally (opt-in, offline).
8. Release-signed builds and a Play Store listing.

## Store build: implemented in v0.2.0
The main branch now carries the Play Store shell requested after the hackathon. The Kiroween v0.1.2
APK remains the offline build.

Implemented and exercised on the reference phone (with Google test ad IDs):
- Cinematic title intro with English voice-over and captions, followed by the F7 Developer brand
  ident; tap/key skips the current clip.
- First-run three-page Field Guide, skippable, stored in the profile; also reopenable from the menu.
- AdMob banner on the title screen only, bottom-right and 56 dp clear of bottom/side navigation
  bars, hidden in overlays and gameplay.
- Interstitials after a planet jump or respawn (60 s warm-up, 120 s gap, max 2 per session).
- Opt-in rewarded ad in the Stellar Store: +25 Stellar Shards; the test ad completed and the
  balance updated on device.
- Google UMP consent before SDK initialisation; Privacy options in Settings/About.
- Remove Ads: one-time Google Play product `remove_ads`, USD 4.99 list, persisted entitlement,
  restore path, graceful failure when the Play Console product does not exist.

Still required before publishing:
- Replace the AdMob app id and the three ad unit ids in `project.godot` (currently Google test IDs).
- Create and activate the `remove_ads` in-app product (USD 4.99) in Play Console, run a license-test
  purchase and a restore, and verify refund/revocation.
- Configure the UMP GDPR message, add a privacy policy URL, and test the EEA consent flow.
- Test banner placement with visible 3-button navigation bars and exercise the interstitial display
  path after a planet jump.
- Replace the placeholder neural-TTS voice-over with a licensed recording (see ASSETS.md).
- Release signing and an AAB for the Play track.

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

## Decided: no ads in the hackathon build
The Kiroween build stays fully offline (no ads SDK, no network permissions), as required by
`.kiro/steering/product.md`. Monetisation is planned only for a **separate Play Store build
after the hackathon**:
- AdMob banner placed clear of the Android navigation bar, interstitials only after a planet jump
  or a death, opt-in rewarded ads (for example bonus Stellar Shards)
- A "Remove Ads" in-app purchase (USD 4.99) through Google Play Billing
- Required work: Gradle build, AdMob and Play Billing plugins, INTERNET/AD_ID permissions,
  UMP consent dialog, privacy policy, and the publisher's own AdMob and Play Console IDs

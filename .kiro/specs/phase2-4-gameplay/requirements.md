# Requirements: Phases 2-4 Gameplay Expansion

Goal: turn the Phase 1 foundation into a full loop: explore, fight, automate, travel, terraform.
User direction (Nov 9 2026): "upgrade all visuals, gameplay and animation; much more massive
and fun". Mobile performance on the reference device stays at >= 30 FPS.

## R10 Feedback and feel
1. Procedural sound effects for mining, breaking, placing, footsteps, jetpack, weapons, hits,
   creature calls, pickups and UI. No audio files from third parties.
2. Pooled particle bursts tinted from the broken block's texture, jetpack flame, ambient
   spores/fireflies, weather particles.
3. Camera shake on impacts and explosions; floating damage numbers.

## R11 Alien ecosystem
1. Creatures are defined in `data/creatures.json` (body plan, colours, size, stats, behaviour,
   drops, tameable, planets, day/night).
2. Bodies are built from voxel parts with procedural walk/fly animation.
3. AI states: wander, graze, flee, chase, attack, follow (tamed). Update rate drops with distance;
   creatures beyond the despawn radius are removed. Spawns respect a population cap.
4. Tamed creatures follow the player and fight hostiles.

## R12 Combat
1. Ranged weapons fire pooled projectiles; melee weapons hit in an arc. Weapons use suit energy.
2. Creatures and enemy drones damage the player; armor upgrade reduces damage.
3. Ruins can contain guardian drones; one planet hosts a boss.

## R13 Machines, power and automation
1. Power grid per planet: solar (scaled by daylight), reactor, battery storage; machines draw power.
2. Powered oxygen generator and heater create safe zones; without power they stop.
3. Hydroponic trays grow food over time; miner bays send a drone that mines nearby ore into the bay;
   smelters auto-smelt ore stored in them; crates store items. Interaction opens a machine panel.
4. Machines keep producing while the planet is not loaded (time-delta simulation on return).

## R14 Vehicles and space travel
1. Rover: deployable vehicle, faster than walking, climbs one block, enter/exit with USE.
2. Spaceship: built at a launch pad from hull frame, engine and nav computer. Engine tier sets
   which planets are reachable. The star map lists planets with tier, hazards and resources.
3. Travelling saves the current planet and loads the target; the ship lands with the player.

## R15 Quests and progression
1. A data-driven quest chain (`data/quests.json`) guides from crash landing to terraforming.
2. Objectives: collect, craft, place, kill, visit planet. Rewards: items and XP.

## R16 Living universe
1. Weather per planet: storms reduce visibility and hurt unsheltered players; meteor showers drop
   meteorites that leave craters with rare ore.
2. Events are rolled per in-game day from the planet's weather table.

## R17 Planet evolution and terraforming
1. Each planet stores evolution stats: pollution (mining, smelting), atmosphere, water, life.
2. Terraformers raise atmosphere/water/life over time when powered and fed catalysts.
3. Stats change the sky, fog and oxygen rules; at high life the terraformer converts nearby ground
   to soil and grass and grows plants. At full atmosphere the planet becomes breathable.
4. Colonies grow: placed habitat machines raise a colony level; colonists (NPC drones) appear.

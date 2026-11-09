# Requirements: Phase 1 Foundation

Goal: one playable voxel planet (Verdania) on Android with movement, mining, building,
inventory, crafting, survival stats and save/load.

## R1 Voxel world
1. WHEN the game starts a world THEN the system SHALL generate terrain from a numeric seed,
   so the same seed always produces the same terrain.
2. The world SHALL be split into 16x16x128 chunk columns that load and unload around the
   player (chunk streaming) without freezing the main thread.
3. Chunk meshes SHALL use greedy meshing, per-vertex ambient occlusion and a texture array.
4. Terrain SHALL include at least: hills/mountains, water, caves, ore veins, glowing
   crystals in caves, alien trees and plants, and small precursor ruins.

## R2 Player
1. The player SHALL walk, sprint, jump and use a jetpack that consumes suit energy.
2. Collision SHALL be AABB vs voxel grid; the player SHALL NOT fall through terrain while
   chunks are loading.
3. A first-person camera with a crosshair SHALL target the block under the crosshair
   within 6 blocks.

## R3 Mining and building
1. Holding "mine" SHALL break the targeted block after a time based on block hardness and
   tool speed; blocks above the tool tier SHALL NOT break.
2. Broken blocks SHALL add their drop item to the inventory.
3. "Place" SHALL put the selected block on the targeted face if it does not overlap the player.
4. Every change SHALL be stored as a per-chunk delta and survive unload/reload and save/load.

## R4 Inventory and crafting
1. Inventory: 9-slot hotbar + 27 slots, stacking up to each item's stack limit.
2. Crafting SHALL use `data/recipes.json`. A recipe's station (hand, fabricator, smelter...)
   SHALL be required within 5 blocks of the player.
3. Block items SHALL show an isometric cube icon generated from their tile textures.

## R5 Survival
1. Stats: health, oxygen, suit energy, food. Oxygen drains on worlds without breathable air;
   at zero oxygen or food the player loses health.
2. Consumables (food, O2 canister, power cell, med kit) SHALL restore their stat.
3. On death the player SHALL respawn at the landing site with full stats.

## R6 Day/night and atmosphere
1. A day/night cycle SHALL move the sun, change sky, fog and terrain light colors.
2. A helmet lamp SHALL light nearby terrain at night and in caves.

## R7 Controls
1. Touch: virtual joystick (left), drag-to-look (right), buttons for jump, mine, place,
   inventory and pause; tap a hotbar slot to select it.
2. Desktop: WASD, mouse look, LMB mine, RMB place, 1-9 hotbar, E inventory, Space jump.

## R8 Save/load
1. The game SHALL autosave every 60 s and on pause/exit, and offer Continue on the title screen.
2. Saves SHALL be local files under `user://` only.

## R9 Performance
1. On the reference device the game SHALL hold at least 30 FPS while walking on the surface
   at the default render distance. FPS SHALL be logged to logcat every 5 s for measurement.

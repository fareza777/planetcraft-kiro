# Tasks: Phase 1 Foundation

Status legend: [x] done and verified, [ ] not done. Verification notes added on completion.

- [x] 1. Project skeleton: project.godot, autoloads, data JSON files (R1, R4)
  - Verified: `godot --headless --import` clean.
- [x] 2. Registry loads all JSON and builds lookup arrays (R1, R4)
  - Verified: headless "registry" checks (all recipe items and drops exist).
- [x] 3. TextureFactory: procedural 32x32 tiles, Texture2DArray, item and cube icons (R4.3)
  - Verified: `test_output/tiles.png`, `icons.png` inspected; layer count test.
- [x] 4. TerrainGenerator: heights, biomes, caves, ores, crystals, trees, flora, ruins (R1.1, R1.4)
  - Verified: determinism tests for 6 planets; screenshots.
- [x] 5. Mesher: greedy meshing with AO, sky light, plants, fluids (R1.3)
  - Verified: winding test (0 bad triangles), 3,005 quads per sample column.
- [x] 6. VoxelWorld: threaded streaming, mesh budget, block edits, deltas (R1.2, R3.4)
  - Verified: streaming radius 4 in about 1.5 s, edit/remesh/regenerate tests.
- [x] 7. Headless test: determinism, mesh output, edit/reload round trip, timings
- [x] 8. Shaders: voxel opaque/cutout/fluid, sky with stars and ringed planet (R6)
- [x] 9. Player: AABB physics, jetpack, raycast, mining, placing (R2, R3)
  - Verified: autoplay walk/mine/place checks. Found and fixed spawn inside a cave entrance.
- [x] 10. Inventory and crafting logic (R4)
- [x] 11. Survival stats and consumables, death/respawn (R5)
- [x] 12. HUD, touch controls, desktop controls, inventory/crafting screen (R7)
  - Verified on device with `adb shell input` swipes and holds. Found and fixed zero-size HUD.
- [x] 13. Title screen, settings, save/load, autosave (R8)
  - Verified: autoplay save/reload checks.
- [x] 14. Android export preset, APK build, install on device, logcat FPS check (R9)
  - Verified: Redmi Note 11. 20 FPS at first, 50 FPS after render-scale and lighting changes.

# Tech stack and conventions

## Stack
- Engine: Godot 4.7.2 stable, GDScript only (no C#, no GDExtension) so the project
  exports with the stock Android templates.
- Renderer: GL Compatibility (OpenGL ES 3.0 on Android). Chosen over Mobile/Vulkan
  because it is faster and more stable on Adreno 6xx class GPUs.
- Android export: stock template APK (no Gradle build), arm64-v8a, min SDK from template.
- Tooling on the dev machine: JDK 17/21, Android SDK at `C:\Android\Sdk`, adb.

## Conventions
- Static typing everywhere (`var x: int`, typed arrays, typed returns).
- Tabs for indentation (Godot default). `snake_case` files and functions, `PascalCase` classes.
- Content is data-driven: blocks, tiles, items, recipes, planets, creatures and quests live
  in `res://data/*.json`. Code must not hard-code content that belongs in data.
- Autoloads: `Reg` (registry of all data, built textures) and `Game` (session state,
  settings, save/load). Keep other singletons out.
- Worker threads (WorkerThreadPool) may only touch plain data (PackedArrays, Dictionaries,
  RefCounted helpers). Never touch nodes, resources in the scene tree, or RenderingServer
  from a worker. ArrayMesh creation happens on the main thread with a per-frame budget.

## Performance rules (Android first)
- Chunk columns 16x16x128, meshed per 16^3 section with greedy meshing.
- Terrain uses one unshaded custom shader with a Texture2DArray; lighting (sun, sky, AO,
  headlamp, lamp array) is computed in the shader. No real-time shadows on terrain.
- No physics engine for terrain: player and entity collision is AABB vs voxel grid.
- Pool frequently spawned objects (projectiles, particles, drops).
- AI update frequency drops with distance; far entities are frozen or despawned.
- Only the current planet is loaded. Other planets advance with a cheap time-delta
  simulation when the player returns.

## Validation before claiming done
- `Godot --headless --path . --import` then the headless test scene must pass.
- Export the Android APK, install on the device with adb, launch it, and check logcat
  for script errors and the FPS log line.

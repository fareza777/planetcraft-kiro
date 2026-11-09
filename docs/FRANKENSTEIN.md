# Frankenstein write-up

> Frankenstein: stitch together a chimera of technologies into one app.

PlanetCraft stitches together parts that usually live in separate products, and runs them inside a
single 29 MB offline APK on a mid-range phone.

## The genre chimera
| Part | Usually found in | In PlanetCraft |
|---|---|---|
| Block-by-block voxel building | Sandbox builders | Streaming 16×16×128 chunk engine with greedy meshing |
| Multi-planet exploration and space travel | Space exploration games | 6 seed-generated worlds, ship assembly, star map, jumps |
| Factory automation | Automation sims | Power grid, miner drones, auto-smelting, offline production |
| Survival | Survival games | O2, energy, food, temperature, radiation, storms |
| RPG loot, elites, bosses, bestiary | Action RPGs | Rarity tiers, unique drops, gear recipes, Void Guardian |
| Planet-scale simulation | Terraforming / god games | Planet Evolution: pollution, atmosphere, water, life change sky, air and ground |
| Story, NPCs, side jobs, trade | Narrative RPGs | 25-step campaign, 6 NPCs, 14 jobs |

## The technology chimera
| Technology | Role |
|---|---|
| Godot 4.7 (GDScript) | Engine, scene graph, UI, Android export with stock templates |
| A custom voxel engine written in GDScript | Seeded generation, padded-volume greedy mesher, WorkerThreadPool streaming, DDA raycasts, AABB voxel physics |
| Custom shaders (Godot shading language, GL ES 3.0) | Unshaded terrain with in-shader lighting from a Texture2DArray, wind sway, fluids, a procedural sky with ringed planet, stars, clouds and storms |
| Procedural pixel-art synthesis | Every block texture and item icon generated from JSON recipes at boot |
| Procedural audio synthesis | 28 SFX from oscillators and noise, plus generative day/night music rendered on a background thread |
| JSON data layer | 12 data files drive content, so new planets, creatures or quests need no code |
| Python | Range-request fetcher that pulls only the Android templates out of a 1.2 GB archive |
| PowerShell + adb | Device test harness: install, simulated touch, logcat FPS, screenshots |
| GitHub Actions (Linux, headless Godot) | Tests and APK export on every push, release on tag |
| Kiro CLI (steering, specs, agentic tests) | Planned, built, tested and documented the whole project |

## Why the pieces are hard to combine
- Voxel meshing and world generation are CPU-heavy, and GDScript is an interpreted language on a
  phone. The answer was threading plus data layout (column-contiguous blocks, padded volumes) and a
  per-frame mesh budget.
- Automation and planet simulation want the whole universe running, but phones can afford one
  planet. Other worlds advance with a time-delta simulation when you return.
- Original art and sound for dozens of systems with no artist: everything is synthesised by code,
  which also keeps the APK small and the style consistent.

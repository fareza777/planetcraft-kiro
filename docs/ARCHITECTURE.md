# Architecture

```
data/*.json ──► Reg (autoload) ──► lookup arrays + Texture2DArray + icons
                                   │
     TerrainGenerator ◄────────────┘   (worker threads)
            │ PackedByteArray per 16×16×128 column (+ edit deltas)
            ▼
         Mesher (greedy, AO, sky light; worker threads)
            │ mesh arrays per 16³ section
            ▼
       VoxelWorld (main thread: ArrayMesh budget per frame, block API, DDA raycast)
            ▲            ▲              ▲
   Player (AABB physics) │      Machines / Evolution / Events / Npcs / Creatures
                         │
                     WorldRoot ──► Hud, TouchControls, InventoryScreen, MachinePanel,
                                   DialogPanel, PauseMenu (code-built UI)
Game (autoload): settings, saves, per-planet state, profile (Stellar Shards, cosmetics)
```

## Key decisions
| Decision | Why |
|---|---|
| GL Compatibility renderer | Faster and more stable than Vulkan/Mobile on Adreno 6xx. Measured 50 FPS vs 20 FPS before tuning on the reference phone. |
| Unshaded terrain with lighting in the shader | One cheap shader. Sun and ambient per vertex, helmet lamp and 8 placed lamps per fragment, no shadow maps. |
| Texture2DArray instead of an atlas | Greedy quads tile with `fract(UV)` without bleeding. Mipmaps work per layer. |
| Column-contiguous block index `y + 128·(x + 16·z)` | The mesher builds its padded 18×18×128 copy with 324 slice copies. |
| No physics engine for terrain | AABB vs voxel collision for the player, creatures and rover is cheaper and never desyncs with edits. |
| Edits stored as deltas | Worlds regenerate from the seed; only changed blocks are saved (zstd-compressed `store_var`). |
| Everything procedural | No asset pipeline, 29 MB APK, consistent original style. |
| Data-driven content | Blocks, tiles, items, recipes, planets, creatures, quests, side jobs, NPCs, trades, loot and store live in JSON. |

## Threads
Generation and meshing run in `WorkerThreadPool` tasks that only see plain data
(PackedArrays, dictionaries, RefCounted helpers). Results come back through a mutex-protected queue,
and the main thread creates at most `mesh_budget` ArrayMeshes per frame. Each chunk has a `version`;
an edit during meshing marks sections dirty again. Music is rendered on its own `Thread`.

## Performance techniques
- Greedy meshing per 16³ section; empty sections skipped; one MeshInstance per section.
- Distance-tiered creature AI: full updates under 28 m, batched updates every 0.15 s under 60 m,
  despawn beyond 76 m. Population cap of 8 on mobile.
- Creature bodies merged into one mesh per animated joint (a few draw calls per creature).
- Pooled projectiles, particle bursts and damage numbers.
- Resolution scale (default 60% on phones), optional bloom and clouds.
- Only the current planet is loaded; other planets advance with a time-delta simulation.

## Save format (`user://saves/slot0/`)
| File | Content |
|---|---|
| `meta.dat` | Version, seed, current planet, player (position, inventory, stats, upgrades, XP), ship, quests, bestiary |
| `<planet>.mods` | Block edit deltas per chunk (zstd) |
| `<planet>.state` | Machines and storage, battery, evolution stats, pets, rover, outpost, boss flag, last-visit time |
| `user://profile.dat` | Stellar Shards, store purchases, equipped cosmetics (shared by all expeditions) |
| `user://settings.cfg` | Settings |

Writes go to a temp file first and are then renamed, so an interrupted save cannot corrupt the
previous one.

## Source map
| Path | Responsibility |
|---|---|
| `scripts/autoload/registry.gd` | Loads all JSON and builds lookup tables, textures, icons, loot rolls |
| `scripts/autoload/game.gd` | Settings, saves, per-planet state, profile/store |
| `scripts/voxel/` | Texture factory, terrain generator (+ structures), mesher, streaming world |
| `scripts/player/` | Player controller, inventory/crafting, survival stats |
| `scripts/world/` | Session root, sky, machines, evolution, events, quests, creatures, NPCs, rover, SFX, music, FX |
| `scripts/ui/` | Theme, HUD, touch controls, item screen, panels, title, settings, store, icons |
| `shaders/` | Terrain (opaque, cutout, fluid), sky |
| `tests/` | Headless suite and windowed autoplay bot |
| `tools/` | Android template fetcher, patch helper, device helper |

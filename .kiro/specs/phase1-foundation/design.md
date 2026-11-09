# Design: Phase 1 Foundation

## Data flow
```
data/*.json --> Reg (registry.gd) --> lookup arrays (kind, solid, face tiles, hardness)
                     |                 Texture2DArray built by TextureFactory
                     v
TerrainGenerator (RefCounted, worker thread) --> PackedByteArray per chunk column
                     v
Mesher (static, worker thread) --> mesh arrays per 16^3 section (opaque/cutout/fluid)
                     v
VoxelWorld (main thread) --> ArrayMesh + MeshInstance3D, budgeted per frame
                     ^
Player (AABB physics, DDA raycast) --> set_block() --> delta store --> remesh task
```

## Chunk storage
- Column of 16 x 16 x 128 bytes. Index `y + 128 * (x + 16 * z)`, so a column of one (x, z)
  is contiguous. This lets the mesher build an 18 x 18 x 128 padded copy with 324 slices.
- Block id is one byte (max 255 block types).
- Edits: `mods[chunk_key][index] = block_id`. Applied after generation, saved to disk.

## Meshing
- For each non-empty section and each of 6 directions, build a 16 x 16 mask of face keys.
  Key = tile+1 | AO of 4 corners (2 bits each) | sky light (4 bits) | emissive bit.
  Equal keys merge into larger quads (greedy). Merging only identical keys keeps AO exact.
- Sky light per face: 15 above the column's top opaque block, falling 2 per block below it.
  Cheap and good enough to make caves dark.
- Plants are two crossed quads in the cutout surface. Fluids get their own transparent surface.
- Godot front faces are clockwise; quads are emitted so `cross(v1-v0, v2-v0) = -normal`.

## Shader lighting (unshaded)
`color = albedo * ao * (ambient * sky + sun * max(n.l, 0) * sky + lamp(dist) + sum(lamps))`.
Emissive tiles skip lighting and output at a boosted value so glow picks them up.
Uniforms are updated by the sky controller each frame.

## Threads
- WorkerThreadPool tasks for generation and meshing. Results go into a mutex-protected
  queue. Main thread applies at most N meshes per frame.
- Each chunk has a `version`; a mesh result for an older version is applied and the chunk
  is queued again.

## Player physics
- AABB 0.6 x 1.8 x 0.6, eye at 1.62. Move per axis and clamp against solid voxels.
- Gravity from the planet definition. Jetpack thrust while jump is held in the air.
- Auto-step onto 1-block ledges when walking into them on the ground (helps touch play).
- Frozen until the chunk under the player has data.

## UI
- Theme built in code (dark translucent panels, cyan/orange accents).
- HUD: stat bars, hotbar, crosshair, mining progress ring, toast messages, FPS label.
- Inventory screen: slot grid + recipe list filtered by nearby stations.

## Save format
- `user://saves/slot0/meta.json`: version, seed, planet, player position, stats, inventory, time.
- `user://saves/slot0/<planet>.mods`: `store_var` of the mods dictionary, compressed.

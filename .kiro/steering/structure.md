# Project structure

```
project.godot            Godot project config (GL Compatibility, landscape)
export_presets.cfg       Android export preset (no secrets; keystore comes from env/editor settings)
data/                    JSON content: tiles, blocks, items, recipes, planets, creatures, quests
scenes/                  Minimal .tscn files; most nodes are built in code
scripts/autoload/        Reg (registry.gd), Game (game.gd)
scripts/voxel/           texture_factory, terrain_generator, mesher, voxel_world
scripts/player/          player controller, inventory, survival stats
scripts/world/           world root, sky/day-night, entities, machines, events
scripts/ui/              theme factory, HUD, touch controls, menus, inventory/crafting screens
shaders/                 voxel opaque/cutout/fluid shaders, sky shader
tests/                   headless test scene and scripts
docs/                    README companions: architecture, gameplay, build, roadmap, Kiro usage
.kiro/                   steering, specs, settings (committed on purpose)
.github/workflows/       CI that exports the Android APK
```

Rules:
- New content types get a JSON file in `data/` and a loader in `registry.gd`.
- New systems get their own script under the matching folder; avoid god-objects.
- Tests live in `tests/` and must run headless without a display.

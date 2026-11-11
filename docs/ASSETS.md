# Asset provenance

PlanetCraft ships **no third-party art, model, music or sound assets**.

| Asset type | Source | Where |
|---|---|---|
| Block textures (78 tiles) | Generated at startup from recipes in `data/tiles.json` | `scripts/voxel/texture_factory.gd` |
| Item icons, isometric block icons | Generated at startup from `data/items.json` | `scripts/voxel/texture_factory.gd` |
| UI icons (touch buttons, HUD) | Drawn with vector primitives | `scripts/ui/icon_painter.gd` |
| Creatures, NPCs, rover, ship, tool | Built from box primitives in code | `scripts/world/creature.gd`, `npcs.gd`, `rover.gd`, `world_root.gd`, `scripts/player/player.gd` |
| Sky, terrain lighting, water | Shaders written for this project | `shaders/` |
| Sound effects (28) | Synthesised at startup | `scripts/world/sfx.gd` |
| Music (day/night loops) | Generative synthesis on a background thread | `scripts/world/music.gd` |
| App icon, adaptive icon layers, boot splash | Hand-written SVG rendered by `tools/render_icons.gd` | `art/icon_full.svg`, `art/generated/` |
| Font | Godot's built-in default font (OFL 1.1) | Engine |

All of the above, except the Godot font, is original work covered by the repository's MIT license.

Note: a Blender MCP connection was configured on the development machine (`.kiro/settings/mcp.json`)
but no Blender-made assets are included. Every model is procedural, which keeps the APK small and
the visual style consistent.

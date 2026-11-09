# How PlanetCraft was built with Kiro

PlanetCraft was built from an empty folder in **Kiro CLI** sessions on November 9, 2026. This file
describes what was actually used. Nothing here is hypothetical.

## 1. Steering (`.kiro/steering/`)
Three always-included steering files were written at the start of the project and were loaded into
every later agent turn:

| File | What it pins down |
|---|---|
| `product.md` | Vision, pillars, hard constraints (offline, original art, mid-range Android target, honesty rule for docs) |
| `tech.md` | Godot 4.7.2 + GDScript only, GL Compatibility renderer, threading rules (no nodes in worker threads), performance rules, validation steps before claiming "done" |
| `structure.md` | Folder layout and where new systems and content go |

Concrete effects visible in the code: all content is in `data/*.json` (tech.md), worker threads only
touch packed arrays (`voxel_world.gd`, `mesher.gd`), and the docs list limitations instead of
overstating features (product.md honesty rule).

## 2. Specs (`.kiro/specs/`)
| Spec | Contents |
|---|---|
| `phase1-foundation/` | `requirements.md` (R1–R9 with acceptance criteria), `design.md` (data flow, chunk layout, greedy meshing keys, shader lighting, threading, physics, save format), `tasks.md` (14 tasks) |
| `phase2-4-gameplay/` | Requirements R10–R17 and tasks 15–28 for feedback, ecosystem, combat, machines, vehicles, travel, quests, events and terraforming |

The design doc decided things before the code was written, for example the column-contiguous block
index used by the mesher's padding step, the face-key format that keeps AO exact when quads merge,
and clockwise winding (later checked by a test).

## 3. Agentic implementation with verification
Kiro wrote the code and ran Godot itself:
- `godot --headless --import` after each change to catch GDScript parse errors. Errors such as
  type-inference failures and a `_set` override clash were fixed in the same turn.
- `tests/test_scene.tscn`, a headless suite grown alongside the features (now 47 checks).
- `tests/autoplay.gd`, a gameplay bot whose screenshots Kiro inspected as images. This is how bugs
  were found: a zero-size HUD (anchors without offsets), spawning inside a cave entrance, and a
  planet jump that reloaded the old planet (meta saved before the destination was set).
- On a real phone over adb: install, launch, simulated touch input, logcat `[PERF]` lines and
  screenshots. The first device run showed 20 FPS, which led to the render-scale and lighting
  changes that reached about 50 FPS.

## 4. Live steering during development
The user redirected the work several times mid-session (for example "make everything much more
massive and fun", "the item page isn't responsive", "add a main story, side quests, NPCs, music",
"add an offline store and rare drops"). Each request was folded into the plan
(`phase2-4-gameplay` spec) and implemented, while the steering rules (performance, offline,
honesty) still applied.

## 5. MCP
The workspace has `.kiro/settings/mcp.json` pointing at a local MCP gateway that exposes Blender and
Godot tools. The connection was set up and verified in this session (Blender 4.5 add-on status,
scene query). **It was not used to make game assets.** All art is procedural by design. It is listed
here only so the configuration file is not mistaken for evidence of Blender-made content.

## 6. Hooks
No agent hooks were used for this project.

## 7. Repository and CI set up by the agent
The agent created the `.gitignore` (which deliberately does not ignore `/.kiro`), the MIT license,
the GitHub Actions workflow, a small Python tool that fetches only the Android entries from the
1.2 GB Godot template archive with HTTP range requests (needed when GitHub's CDN returned 504s), and
a patch helper used to make reliable multi-hunk edits. Commits are authored as "F7 Developer".

# Tasks: Phases 2-4 Gameplay Expansion

Status legend: [x] implemented and verified as noted, [~] implemented with partial verification,
[ ] not done.

- [x] 15. Procedural SFX bank and pooled players (R10.1)
- [x] 16. Particle pool: block debris, jetpack, ambient spores, weather (R10.2)
- [x] 17. Camera shake, damage numbers (R10.3)
- [x] 18. creatures.json + voxel body builder + procedural animation (R11.1, R11.2)
- [x] 19. Creature AI, spawning, distance LOD, taming (R11.3, R11.4)
  - Verified: autoplay kill; device FPS with 8–11 creatures 36–46.
- [x] 20. Weapons, projectiles, melee, player damage, drops (R12)
- [~] 21. Power grid, machine panels, hydro, miner drone, smelter, crate (R13)
  - Simplification: one shared power pool per planet, no cable wiring (see ROADMAP).
- [x] 22. Offline machine simulation (R13.4) — autoplay check
- [x] 23. Rover vehicle (R14.1) — autoplay check
- [x] 24. Launch pad, ship assembly, star map, planet travel (R14.2, R14.3) — autoplay jump to Kryos
- [~] 25. quests.json + quest tracker (R15) — 25 main + 14 side jobs; only early steps exercised
- [~] 26. Weather and meteor showers (R16) — runs in sessions, no dedicated test
- [~] 27. Planet evolution stats, terraformer, colony level (R17) — not played to 100% in a test
- [~] 28. Re-run tests and device check; update docs
  - Headless 47/47, autoplay 19/19, CI green. Final build not yet re-tested on the phone.

## Added by live steering (user requests during the session)
- [x] Item screen rebuilt (tabs, responsive slots, in-place updates), title menu, settings panel
- [x] Vector icons for touch buttons/HUD; polished item icons
- [x] Story chapters with narrated beats, NPCs, side jobs, trading, journal, waypoints
- [x] Generative music, foliage sway, pulsing emissives
- [x] Stellar Store, rarity tiers, elites, unique rare drops, gear recipes, bestiary
- [x] Structures with events: obelisk trials, starfall shrines, alien hives, crashed freighters

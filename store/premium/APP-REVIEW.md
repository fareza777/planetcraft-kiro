# PlanetCraft: Galactic Survival — game review

## Project

- Godot 4.7.2, project version 0.1.2, Android package com.f7developer.planetcraft.
- Landscape, single-player offline voxel survival. The project data defines six worlds and 75 recipes.
- The walkthrough focuses on the crash landing, mining, the Fabricator, powered machines, alien fauna, rover driving, starship travel and planet evolution.

## Checked during this work

- The current project copy passed all 47 headless tests.
- The built-in desktop autoplay suite completed with 19 successes on the second run at a maximum of 60 FPS. The first, uncapped run passed 17 checks and missed the plasma-pistol kill and its downstream loot check. Both passed on the second run. The cause of the first run's missed kill was not isolated.
- The desktop autoplay covered initial spawn, movement, mining, block placement, Fabricator crafting, saves, combat and loot, hydroponic production, offline production, rover driving, and landing on Kryos with carried inventory.
- The staged Aridus capture reached 100% atmosphere, water and life using the game's evolution simulation with accelerated time. Ground and sky changes were visible in the before/after captures.
- A connected Redmi Note 11 reported the installed package as version 0.1.2. The checks above were run on Windows. Android touch, Android FPS and a complete phone playthrough were not rerun. The shipped source files were left untouched.

The test logs archive the two gameplay trials and the current headless run.


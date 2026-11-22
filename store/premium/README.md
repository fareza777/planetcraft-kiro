# PlanetCraft: Galactic Survival — Play Store and trailer kit

## Deliverables

| Asset | File | Format |
| --- | --- | --- |
| Store icon | icon-512.png | 512 × 512, RGBA PNG |
| Icon master | icon-1024.png | 1024 × 1024, RGBA PNG |
| Play Store feature graphic | feature-graphic-1024x500.png | 1024 × 500, RGB PNG |
| Phone gallery | screenshots/01–08 | Eight 1920 × 1080 RGB PNGs |
| Gallery proof | preview-screenshots.jpg | Overview of the eight files |
| YouTube trailer | planetcraft-youtube-1920x1080.mp4 | 1920 × 1080, 30 fps, 38 seconds |
| Vertical trailer | planetcraft-vertical-1080x1920.mp4 | 1080 × 1920, 30 fps, 38 seconds |
| Editable timeline | video/ | Remotion source, locked dependencies, fonts, captured game clips and original score |

The landscape and vertical cuts use the same edit with distinct layouts. The vertical cut preserves the complete landscape game frame inside a portrait composition. The original score has impact cues at the scene cuts. The end card credits F7 Developer. The ZIP contains the PNGs and editable files. The two ready-to-play MP4s are supplied separately.

## Gallery order and alt text

| Position | File | Alt text |
| --- | --- | --- |
| 1 | 01-crash-adapt-survive.png | A first-person view over purple Glowwood trees and turquoise voxel terrain on Verdania. |
| 2 | 02-dig-into-alien-worlds.png | The mining laser breaks a ferrite ore block next to the crash pod. |
| 3 | 03-craft-what-keeps-you-alive.png | The Fabricate screen shows the Fabricator recipe and its ingredients. |
| 4 | 04-put-your-colony-to-work.png | Solar panels, hydroponic trays and powered machines on a player-built platform. |
| 5 | 05-tame-the-wild.png | A Mossback and a Veil Glider near the settlement on Verdania. |
| 6 | 06-go-off-road.png | A yellow six-wheeled rover in the dunes of Aridus. |
| 7 | 07-jump-between-six-worlds.png | Three gameplay views show the forests of Verdania, the snow of Kryos and the deserts of Aridus. |
| 8 | 08-give-a-planet-life.png | The same Aridus settlement before and after terraforming changes the ground and sky. |

## Render again

From the kit directory, open the video folder and run:

~~~powershell
npm ci
npm run studio
~~~

Open the Studio URL printed in your terminal. The landscape composition is PlanetCraftWide and the portrait composition is PlanetCraftVertical. To export:

~~~powershell
npm run render:wide
npm run render:vertical
~~~

The renderable media is in video/public. The reusable motion layouts are in video/src/scenes.tsx. The scene edit and timing are in video/src/index.tsx. The original score generator is make-score.py, and build-assets.py recreates the gallery and store graphics from the source captures with Pillow, NumPy, FontTools and Brotli.

## Provenance

The screenshot gallery and moving footage use the game's native Godot viewport. The capture sessions used a separate project copy and prepared game states to show the colony, creatures, starship and terraforming. The before/after comparison shows the same Aridus site and the game's own terrain and atmosphere changes with time accelerated for recording. The icon and the cover/end-card landscape are original marketing illustrations created with the built-in ImageGen tool.

See APP-REVIEW.md for test coverage and limitations. The original game license and notices are included, along with the fonts' OFL licenses. See [Google Play preview asset specifications](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).


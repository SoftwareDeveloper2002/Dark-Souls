# Dark Souls mobile - Unreal Engine 5.6 port

A C++ port of the Godot 4 game in this repo. The project is `unreal/DarkSouls/DarkSouls.uproject`.

**Status: written but not compiled.** Unreal Engine is not installed on the machine this was written on, so nothing here has been built or run. Expect a few compile errors on first build (fix them from the compiler output).

## Getting it running

1. Install Unreal Engine 5.6 with the *Game development with C++* workload (Visual Studio 2022) and the Android/iOS target platforms if you want mobile builds.
2. Right-click `DarkSouls.uproject` > *Generate Visual Studio project files*, open the `.sln`, build `DarkSoulsEditor` (Development Editor, Win64), or just double-click the `.uproject` and let it build.
3. In the editor create the level: *File > New Level > Empty Level*, save it as `/Game/Maps/DarkSoulsMap` (the path `Config/DefaultEngine.ini` expects).
4. Add the terrain (optional but recommended, see below). Without a Landscape the game lays a flat 6 km floor so it is playable immediately.
5. Press Play. The game director (`ADSGame`) is spawned by `ADSGameMode`; it builds the camera, lights, fog and everything else at runtime.

Controls: touch (left half = floating stick; buttons on the right) - the mouse acts as a finger on desktop. Keyboard: WASD/arrows move, J/Space attack, K roll, E estus, U/1 and I/2 skills, Q swap weapon, L/Shift block, Esc pause.

## Terrain

The Godot terrain (Terrain3D, 3 regions of 1024 m) was decoded and exported by `unreal/tools/export_terrain.py`:

- `Content/ImportSource/dark_souls_heightmap_1009x3025.r16`
- `Content/ImportSource/LANDSCAPE_IMPORT.txt` - the exact Landscape Mode > *Import from File* settings (location, scale, resolution).

Heights are in the same metres as the game, so the road (`DSRoute.inc`, generated from `scripts/world.gd`) lines up with the terrain. The route height check (largest step between neighbouring route points) was 4.1 m, so the region mapping is right. The Terrain3D texture splat maps were not exported; paint a Landscape material yourself.

Rerun `python unreal/tools/export_terrain.py` (Python 3.14, needs `compression.zstd`) if the Godot terrain or `world.gd` route changes.

## What was ported

| Godot | Unreal (`Source/DarkSouls/`) |
|---|---|
| `game.gd` player, combat, enemy AI, projectiles, zones | `DSGamePlayer.cpp`, `DSGameEnemy.cpp`, `DSGame.cpp` |
| `bosses.gd` (Demon, Serpent Queen, Cyborg Titan, Malakar incl. phases and forms) | `DSGameBoss.cpp` |
| `quests.gd`, quest flow, wayside groups, chests, shop, dialogue, save | `DSData.cpp`, `DSGameQuest.cpp`, `DSSaveGame.*` |
| `weapons.gd` (4 weapons, combos, armour, skills) | `DSData.cpp` |
| `world.gd` (road, quest sites) | `DSData.cpp` + `DSRoute.inc` |
| `touch_controls.gd`, HUD, `dialogue.gd`, `shop.gd` | `DSPlayerController.*`, `DSHUD.*` |
| `settings/project.godot` | `Config/*.ini` (mobile forward renderer, landscape orientation) |

All numbers (HP, damage, speeds, timings, costs, quest scaling) are copied from the GDScript, and the simulation runs in the same 2D plane in metres. `ADSGame` is the direct counterpart of `game.gd`.

### Added in the second pass

| Godot | Unreal |
|---|---|
| `structures.gd` (walls, tunnel, labyrinth with chests, bridge), `forest.gd` | `DSGameWorld.cpp` (instanced-mesh walls, collision grid, procedural trees) |
| `torch.gd`, `civilians.gd` (dark labyrinth, rescue, follow/stay, mauling, fail + retry) | `DSGameWorld.cpp` |
| `boss_talk.gd` (speech bubbles; lines generated into `DSBossLines.inc`) | `DSGameExtras.cpp`, `DSHUD.cpp` |
| `emblems.gd` (12 hidden emblems, unlimited ammo reward, saved) | `DSGameExtras.cpp` |
| `execution.gd` (GRAB finishers, camera orbit, slow-mo, 11 named fatalities) | `DSGameExtras.cpp` |
| `map_view.gd` (relief map + minimap, drag/zoom) | `DSGameExtras.cpp`, `DSHUD.cpp` |
| `comic.gd` + credits (epilogue after the final boss) | `DSData.cpp`, `DSHUD.cpp` |
| `fx.gd` rain/lightning/darkness, `music.gd`, `sfx.gd` | `DSGameExtras.cpp` (+ `tools/make_sfx.py`) |

Terrain edits the Godot game makes at runtime (boss arena flattening, labyrinth floor, the bridge chasm) are baked into the exported heightmap, because Unreal cannot edit a Landscape while playing.

### Audio setup

Sounds are looked up by name at runtime, and silently skipped when missing:

1. `python unreal/tools/make_sfx.py` synthesises every effect (port of `sfx.gd`) into `Content/ImportSource/Audio/Sfx`.
2. `powershell unreal/tools/convert_audio.ps1` (needs ffmpeg) converts the music and voice files to `.wav`.
3. In the editor import those folders to `/Game/Audio/Sfx`, `/Game/Audio/Music` and `/Game/Audio/Vox`, keeping the file names.

## Still different from the Godot build

- **Art:** the Godot game builds all models in code (`models.gd`, `vox.gd`). Here every character, prop and effect is made of engine primitives (`ADSVisual`), with simple procedural poses (lean, swing, fall). Replace `ADSGame::BuildFigure` / `BuildPlayerFigure` with skeletal meshes and animations when you have art.
- **Finishers** are the same sequence of events (grab, blows, named fatality, head flying off, slow-mo) but without the gore props, anatomical heart or bespoke camera paths of `execution.gd`.
- **Comic panels** are flat colour scenes with silhouettes, not the rendered 3D panels of `comic_art.gd`; the captions, speech bubbles and page flow are the same.
- **Translucency:** the shield dome, gaze cone and ground zones are opaque primitives because the engine's `BasicShapeMaterial` is opaque. Swap in a translucent material in `ADSVisual::AddPart` for the Godot look.
- The Terrain3D hole mask (height 0 = not walkable) is not exported; slopes steeper than 0.85 are still refused as in Godot.
- The settings screen of the Godot build (graphics quality levels) is reduced to music/effects volume in the pause menu.

## Mobile notes

`Config/DefaultEngine.ini` targets Android (arm64, Vulkan, min SDK 29) and iOS 15, landscape only, forward shading, mobile HDR off. Set the package name, signing and icons under *Project Settings > Platforms* before shipping.

## Models and music (copied from the Godot game)

`Content/ImportSource/Models` holds the real art as `.glb`: `Characters/` (hero, hound, every enemy and boss body, princess, villagers, imp, wolf, heart), `Props/` (polyhaven props, tent, rocks, heavy greatsword) and `Forest/` (pine trees with LOD levels). `Content/ImportSource/Audio/Music` and `Audio/Vox` hold the music and the voice lines.

Import them all once with `unreal/tools/import_assets.py` (see the header of that file). They land in `/Game/Models/...` and `/Game/Audio/...`. The game now dresses the hero, the hound and every humanoid enemy in their imported model through `ADSVisual::AttachModel` (called from `BuildPlayerFigure` / `BuildFigure`): it searches `/Game/Models/Characters` for an asset named after the character (`hero`, `zombie`, ...), scales it to the figure's height and hides the primitive body / head. If a model has not been imported the figure stays as primitives, so nothing breaks. Skinned bodies stand in their rest pose; the actor still leans, swings and falls procedurally. Not yet compiled or run (no Unreal install was available); if a model faces sideways change the `YawOffsetDeg` argument of `AttachModel`.

The same lookup now dresses the camp tents (`medieval_tent`), camp rocks and boss standing stones (`RockA/B/C`), the bonfire (`stone_fire_pit`), the labyrinth chests (`treasure_chest`) and the forest (instanced `pine_1` / `pine_2` from `/Game/Models/Forest`). Music, voices and sound effects were already loaded from `/Game/Audio/Music`, `/Vox` and `/Sfx`, which the import script fills. Every one of them falls back to the old primitive when its asset is missing. Chest lids no longer swing when an imported chest model is used (the lid animation drives the hidden primitive).

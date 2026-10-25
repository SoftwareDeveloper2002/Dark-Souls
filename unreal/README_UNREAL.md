# Dark Souls mobile - Unreal Engine 5.5 port

A C++ port of the Godot 4 game in this repo. The project is `unreal/DarkSouls/DarkSouls.uproject`.

**Status: written but not compiled.** Unreal Engine is not installed on the machine this was written on, so nothing here has been built or run. Expect a few compile errors on first build (fix them from the compiler output).

## Getting it running

1. Install Unreal Engine 5.5 with the *Game development with C++* workload (Visual Studio 2022) and the Android/iOS target platforms if you want mobile builds.
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

## What is not ported yet

- **Art:** the Godot game builds all models in code (`models.gd`, `vox.gd`). Here every character, projectile and prop is made of engine primitives (`ADSVisual`). Replace `ADSGame::BuildFigure` / `BuildPlayerFigure` with skeletal meshes and animations when you have art.
- **Labyrinth (quest 27):** torch, civilians and the maze treasure (`structures.gd`, `torch.gd`, `civilians.gd`). Quest 27 plays as a survival fight and awards the revolver on completion.
- **Bridge/Titan set-piece geometry (quest 30)**, execution finishers (`execution.gd`), the comic epilogue, emblem hunt, map view, boss speech bubbles (`boss_talk.gd`), the title/cinematic scenes.
- **Rain, lightning ambience, procedural SFX and music** (`fx.gd`, `sfx.gd`, `music.gd`, `vox.gd`). The `.wav` files that Unreal can import directly are in `Content/ImportSource/Audio`; the `.ogg`/`.mp3` voice and ambience files in `assets/audio/vox` need converting to `.wav` first.
- **Translucent telegraphs:** the shield dome, gaze cone and ground zones are opaque primitives because the engine's `BasicShapeMaterial` is opaque. Swap in a translucent material in `ADSVisual::AddPart` if you want the Godot look.
- The Terrain3D hole mask (height 0 = not walkable) is not exported; slopes steeper than 0.85 are still refused as in Godot.

## Mobile notes

`Config/DefaultEngine.ini` targets Android (arm64, Vulkan, min SDK 29) and iOS 15, landscape only, forward shading, mobile HDR off. Set the package name, signing and icons under *Project Settings > Platforms* before shipping.

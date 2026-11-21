# Architecture

The game is a blank Godot project so far. Update this file as structure appears: a row per
area, and the dependency rules between them.

## Layout

| Path | What it is |
| --- | --- |
| `Godot/` | The Godot project. Everything the game loads lives here. |
| `Godot/main.tscn` | The main scene (`run/main_scene`). |
| `Godot/export_presets.cfg` | Export presets for Web, Windows, macOS and Linux. CI uses them by name. |
| `.github/workflows/` | CI: export on push, itch.io deploy, Discord notifications. |
| `docs/` | Documentation for people and agents; start at [index.md](index.md). |

## Where state lives

Nothing yet.

## Load-bearing decisions

* *The Godot project is in `Godot/`, not the repo root.* Docs, CI and art sources stay out of
  Godot's import scan. CI's `working-directory` and artifact paths assume it.
* *GL Compatibility renderer.* The Web export requires it. Switching to Forward+ breaks the
  Web build.
* *`textures/vram_compression/import_etc2_astc=true`.* The macOS export is universal (arm64),
  which needs ETC2/ASTC textures; without it the macOS export fails.

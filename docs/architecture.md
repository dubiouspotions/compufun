# Architecture

The design and the target structure are in the wiki: [wiki/Architecture.md](../wiki/Architecture.md)
(`bash tools/sync-wiki.sh` fetches it). This file holds only the repo facts that the wiki doesn't:
the repo layout and the load-bearing build settings. Don't copy the wiki here. When the two
disagree, the wiki wins.

## Layout

| Path | What it is |
| --- | --- |
| `Godot/` | The Godot project. Everything the game loads lives here. |
| `Godot/main.tscn` | The main scene (`run/main_scene`). |
| `Godot/export_presets.cfg` | Export presets for Web, Windows, macOS and Linux. CI uses them by name. |
| `.github/workflows/` | CI: export on push, itch.io deploy, Discord notifications. |
| `docs/` | Documentation for people and agents; start at [index.md](index.md). |
| `tools/` | Scripts for people and agents. `sync-wiki.sh` clones or pulls the wiki. |
| `wiki/` | The GitHub wiki, a separate git repo. Ignored by this repo. |

## Where state lives

See "The game state and the loop" in [wiki/Architecture.md](../wiki/Architecture.md).

## Load-bearing decisions

* *The Godot project is in `Godot/`, not the repo root.* Docs, CI and art sources stay out of
  Godot's import scan. CI's `working-directory` and artifact paths assume it.
* *GL Compatibility renderer.* The Web export requires it. Switching to Forward+ breaks the
  Web build.
* *`textures/vram_compression/import_etc2_astc=true`.* The macOS export is universal (arm64),
  which needs ETC2/ASTC textures; without it the macOS export fails.

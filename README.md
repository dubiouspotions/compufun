# HumanError

Dubious Potions' entry for [GAME JAM 95](https://itch.io/jam/game-jam-95).

## Building

1. Install [Git LFS](https://git-lfs.com) and run `git lfs install` before cloning.
2. Open `Godot/project.godot` in Godot 4.7.2.
3. To export locally, run `./export.sh all` (or `web`, `mac`, `windows`, `linux`) from `Godot/`. It needs the 4.7.2 export templates.

Pushing to `main` exports Web, Windows, macOS and Linux builds with GitHub Actions. Pushing to `deploy`, or a manual run, also uploads them to itch.io.

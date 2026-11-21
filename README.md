# HumanError

Dubious Potions' entry for [GAME JAM 95](https://itch.io/jam/game-jam-95).

## The game

Our entry for [GAME JAM 95](https://itch.io/jam/game-jam-95), theme "NOT A BUG". Submissions close 2026-12-04 18:00 (the jam page gives no timezone).

Concept:

- Player owns a computer store in 1996. People come in with computer problems, and hand off their boxes.
- Papers Please style, stuck at the desk. You can turn left and right. Front is the working desk, left is storage, right is your own computer where you connect with modem to the BBS where the troubleshooting guides are, and mIRC for talking to your boss who is on vacation.
- Some of the computers are haunted by demons.
- Game is 3D, maybe PS1 graphics. You can only turn left, right, and zoom into the CRT VGA monitor.
- Customers don't come in in 3D, but rather as 2D cutouts and chat boxes, "visual novel" style.

## Building

1. Install [Git LFS](https://git-lfs.com) and run `git lfs install` before cloning.
2. Open `Godot/project.godot` in Godot 4.7.2.
3. To export locally, run `./export.sh all` (or `web`, `mac`, `windows`, `linux`) from `Godot/`. It needs the 4.7.2 export templates.

Pushing to `main` exports Web, Windows, macOS and Linux builds with GitHub Actions. Pushing to `deploy`, or a manual run, also uploads them to itch.io.

## Documentation

Start at [docs/index.md](docs/index.md). Coding agents read [AGENTS.md](AGENTS.md).

## Credits

- `.claude/skills/godot-master/`: the godot-master agent skill from [Game-Dev-Agentic-Skills](https://github.com/thedivergentai/Game-Dev-Agentic-Skills), LGPL-3.0. Not part of the game.

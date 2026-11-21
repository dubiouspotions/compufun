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

[See more concept details in the wiki](https://github.com/dubiouspotions/humanerror/wiki/Game-Concept-&-Loop).

## Building

1. Install [Git LFS](https://git-lfs.com) and run `git lfs install` before cloning.
2. Open `Godot/project.godot` in Godot 4.7.2.
3. To play the latest `main` without the editor, double-click `Play HumanError.app` (macOS) or `Play HumanError.bat` (Windows). It pulls, imports and starts the game. Git with LFS comes from [GitHub Desktop](https://desktop.github.com) if there is no other; Windows can also install Git with winget. Without Godot 4.7.2 or newer (the .NET build works too), it offers to download 4.7.2.
4. To export locally, run `./export.sh all` (or `web`, `mac`, `windows`, `linux`) from `Godot/`. It needs the 4.7.2 export templates.

Pushing to `main` exports Web, Windows, macOS and Linux builds with GitHub Actions. Pushing to `deploy`, or a manual run, also uploads them to itch.io.

## Documentation

- **Architecture:** [wiki/Architecture.md](wiki/Architecture.md), the local copy of the wiki page. Run `bash tools/sync-wiki.sh` to fetch or update it. It holds the design; it is also [online](https://github.com/dubiouspotions/humanerror/wiki/Architecture). The code layout (folders, the main scene tree, the load-bearing settings) is in [docs/architecture.md](docs/architecture.md).
- **Rules and how-tos:** start at [docs/index.md](docs/index.md). Set up a new machine with [docs/working-together.md](docs/working-together.md).
- Coding agents read [AGENTS.md](AGENTS.md).

## Credits

- `Godot/win95/sounds/boot_power_on.ogg`: cut from "PC startup" by bratij on Freesound (https://freesound.org/people/bratij/sounds/841351/), CC0.
- `Godot/win95/sounds/boot_post_beep.ogg`: cut from "PC speaker error beep" by CZghost on Freesound (https://freesound.org/people/CZghost/sounds/264823/), CC0.
- `Godot/win95/sounds/boot_drive.ogg`: cut from "Electronic, Computer, Hard Drive - 1990s Compaq Hard Drive, Spooling Up, Turning Off - Close Perspective Memory Access Noise" by jaegrover on Freesound (https://freesound.org/people/jaegrover/sounds/262872/), CC0.
- `Godot/win95/sounds/boot_startup.ogg`: cut from "1990s Operating System Start Sound - Optimistic" by Johnmode on Freesound (https://freesound.org/people/Johnmode/sounds/818343/), CC0.
- `Godot/sounds/city_ambience.ogg`: cut and muffled from "Westfield.wav" by Islabonita on Freesound (https://freesound.org/people/Islabonita/sounds/178532/), CC0. `tools/make_city_ambience.sh` makes it.
- `Godot/win95/theme/fonts/`: W95FA Pixel, a pixel-grid version of [W95FA](https://fontsarena.com/w95fa-by-alina-sava/) by Alina Sava (FontsArena), SIL OFL 1.1 (`ofl.txt`).
- `Godot/voices/`: the customers' voices, rendered with [Chimera](https://github.com/jamesondh/chimera-vocal-synth) by Jameson Hodge, MIT. The game ships only the rendered WAV files.
- `.claude/skills/godot-master/`: the godot-master agent skill from [Game-Dev-Agentic-Skills](https://github.com/thedivergentai/Game-Dev-Agentic-Skills), LGPL-3.0. Not part of the game.

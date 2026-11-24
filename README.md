# CompuFun

Dubious Potions' entry for [GAME JAM 95](https://itch.io/jam/game-jam-95). The repo and the code use its working title, HumanError.

## The game

Our entry for [GAME JAM 95](https://itch.io/jam/game-jam-95), theme "NOT A BUG". Submissions close 2026-12-04 18:00 (the jam page gives no timezone).

Concept:

- Player owns a computer store in 1996. People come in with computer problems, and hand off their boxes.
- Papers Please style, stuck at the desk. You can turn left and right. Front is the working desk, left is storage, right is your own computer where you connect with modem to the BBS where the troubleshooting guides are, and mIRC for talking to your boss who is on vacation.
- Some of the computers are haunted by demons.
- Game is 3D, maybe PS1 graphics. You can only turn left, right, and zoom into the CRT VGA monitor.
- Customers don't come in in 3D, but rather as 2D cutouts and chat boxes, "visual novel" style.

[See more concept details in the wiki](https://github.com/dubiouspotions/compufun/wiki/Game-Concept-&-Loop).

## Building

1. Install [Git LFS](https://git-lfs.com) and run `git lfs install` before cloning.
2. Open `Godot/project.godot` in Godot 4.7.2.
3. To play the latest `main` without the editor, double-click `Play HumanError.app` (macOS) or `Play HumanError.bat` (Windows). It stashes any local changes (`git stash pop` brings them back), pulls, imports and starts the game. Git with LFS comes from [GitHub Desktop](https://desktop.github.com) if there is no other; Windows can also install Git with winget. Without Godot 4.7.2 or newer (the .NET build works too), it offers to download 4.7.2. It also downloads the live voice, so the Story Lab and the Voice Lab speak lines that have no rendered WAV yet.
4. To export locally, run `./export.sh all` (or `web`, `mac`, `windows`, `linux`) from `Godot/`. It needs the 4.7.2 export templates.

Pushing to `main` exports Web, Windows, macOS and Linux builds with GitHub Actions. A release, started by hand, bumps the version, tags `main` and uploads the builds to itch.io ([Releasing](docs/building-and-testing.md#releasing)):

```sh
gh workflow run godot.yml -R dubiouspotions/compufun -f bump=patch   # or minor, major
```

## Documentation

- **Architecture:** [wiki/Architecture.md](wiki/Architecture.md), the local copy of the wiki page. Run `bash tools/sync-wiki.sh` to fetch or update it. It holds the design; it is also [online](https://github.com/dubiouspotions/compufun/wiki/Architecture). The code layout (folders, the main scene tree, the load-bearing settings) is in [docs/architecture.md](docs/architecture.md).
- **Rules and how-tos:** start at [docs/index.md](docs/index.md). Set up a new machine with [docs/working-together.md](docs/working-together.md).
- Coding agents read [AGENTS.md](AGENTS.md).

## Credits

- `Godot/sounds/footstep_tile_1.ogg` to `footstep_tile_4.ogg`: four steps cut from "Footsteps_Boots_Tile_Mono" by Nox_Sound on Freesound (https://freesound.org/people/Nox_Sound/sounds/530588/), CC0. `footstep_asphalt_*.ogg` and `footstep_sidewalk_*.ogg` are filtered from them by `tools/make_outdoor_steps.sh`.
- `Godot/sounds/computer_set_down.ogg`: cut from "Book dropped on table" by Valerie-Vivegnis on Freesound (https://freesound.org/people/Valerie-Vivegnis/sounds/836521/), CC0.
- `Godot/sounds/computer_pick_up_1.ogg` and `computer_pick_up_2.ogg`: two lifts cut from "Foley_Object_Toolbox_Metal_PickUp_Mono" by Nox_Sound on Freesound (https://freesound.org/people/Nox_Sound/sounds/556647/), CC0.
- `Godot/sounds/heartbeat.wav`: one beat cut from "Human Heartbeat (60 BPM)" by FenrirFangs on Freesound (https://freesound.org/people/FenrirFangs/sounds/213181/), CC0. `tools/cut_organ_sounds.sh` cuts it, the wheeze and the squelches.
- `Godot/sounds/wheeze.wav`: one breath cut from "asthmatic_breathing.wav" by harleto on Freesound (https://freesound.org/people/harleto/sounds/204469/), CC0.
- `Godot/sounds/squelch_1.wav` and `squelch_2.wav`: "Meat Slap 2" and "Gushing Flesh" by magnuswaker on Freesound (https://freesound.org/people/magnuswaker/sounds/540076/, https://freesound.org/people/magnuswaker/sounds/563315/), CC0.
- `Godot/sounds/squelch_3.wav` to `squelch_5.wav`: three grabs cut from "Slimy flesh" by iampagan on Freesound (https://freesound.org/people/iampagan/sounds/177017/), CC0.
- `Godot/sounds/part_take.ogg`: trimmed from "Picking Something Up From A Table" by RutgerMuller on Freesound (https://freesound.org/people/RutgerMuller/sounds/51160/), CC0.
- `Godot/sounds/part_put.ogg`: trimmed from "Clip In" by slappy13 on Freesound (https://freesound.org/people/slappy13/sounds/151778/), CC0.
- `Godot/sounds/part_rattle.ogg`: cut from "boxofscrews.wav" by j1987 on Freesound (https://freesound.org/people/j1987/sounds/79382/), CC0. `tools/make_part_sounds.sh` makes it.
- `Godot/sounds/part_clunk_1.ogg` to `part_clunk_3.ogg`: three drops cut from "R29-08-Small Metal Objects on Metal Tray.wav" by craigsmith on Freesound (https://freesound.org/people/craigsmith/sounds/481935/), CC0. `tools/make_part_sounds.sh` makes them.
- `Godot/sounds/cable_plug_in.ogg`: trimmed from "Power Cord Plug 1_2" by Joao_Janz on Freesound (https://freesound.org/people/Joao_Janz/sounds/477621/), CC0.
- `Godot/sounds/cable_plug_out.ogg`: trimmed from "Power Cord Plug 1_1" by Joao_Janz on Freesound (https://freesound.org/people/Joao_Janz/sounds/477628/), CC0.
- `Godot/sounds/floppy_insert.ogg`: cut from "Inserting 3.5 inch floppy-disk into floppy disk drive" by micropolis on Freesound (https://freesound.org/people/micropolis/sounds/637057/), CC0.
- `Godot/sounds/floppy_eject.ogg`: cut from "Taking 3.5-inch floppy-disk from floppy disk drive" by micropolis on Freesound (https://freesound.org/people/micropolis/sounds/637058/), CC0.
- `Godot/sounds/keystroke_1.wav` to `keystroke_6.wav` and `keystroke_space.wav`: key presses cut from "Mechanical-Keyboard: Typing" by M4taiori on Freesound (https://freesound.org/people/m4taiori/sounds/331428/), CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/); the cuts are listed in `Godot/sounds/KEYSTROKES-LICENSE.txt`.
- `Godot/win95/theme/boot_logo.png`: the Windows 95 startup screen, (C) Microsoft, not licensed to us. Taken from the Windows Wallpaper Wiki (https://windowswallpaper.miraheze.org/wiki/Windows_95).
- `Godot/win95/wallpapers/` (all but `win95-default.png`): the wallpapers that shipped with Windows 95, (C) Microsoft, not licensed to us. Taken from the Windows Wallpaper Wiki (https://windowswallpaper.miraheze.org/wiki/Windows_95).
- `Godot/sounds/end_groan_1.wav`, `end_groan_2.wav`: groans recorded for the game by the team.
- `Godot/sounds/cd_button.wav`, `cd_tray_open.wav` and `cd_tray_close.wav`: a CD-ROM drive recorded for the game by Nevyn Bengtsson; `tools/make_cd_sounds.py` cuts them.
- `Godot/win95/sounds/chord.wav`: CHORD.WAV, the Critical Stop sound of Windows 95, (C) Microsoft, not licensed to us. Taken from "Windows 95 audio media" on the Internet Archive (https://archive.org/details/Win95-audio-media).
- `Godot/win95/theme/icons_extracted/`: the icons that shipped with Windows 95, (C) Microsoft, not licensed to us. Extracted from a Windows 95 install with `tools/extract_win95_icons.py`.
- `Godot/corruption/win_phone/modem_phone.png`: the colours and the lights of the Windows 95 Modems icon, (C) Microsoft, not licensed to us, drawn into the 3D phone of the sign win_phone by `tools/make_win_phone.gd`.
- `Godot/win95/applets/*.png`: pictures from Windows 95's Control Panel (the monitors, the mouse, the jack-in-the-box, the pointers, the time zone map, the Device Manager tree, the Windows Setup components), (C) Microsoft, not licensed to us. Cropped from screenshots of Windows 95 in a VM.
- `Godot/win95/solitaire/` (`cards.png`, `recycle.png`, `back.png`): Solitaire's cards by Susan Kare and its 1990 card back, (C) Microsoft, not licensed to us. The faces are from the extracted Windows XP `cards.dll` bitmaps at catonmat.net (https://catonmat.net/cards-dll); the back is from the Windows 3.1 card sheet in 0xe1f/solitaire (https://github.com/0xe1f/solitaire).
- `Godot/win95/sounds/boot_power_on.ogg`: the sound of "Old 90s PC boot sequence (4K)" by Burcica on YouTube (https://www.youtube.com/watch?v=692Z_adAsMQ), not licensed to us; cut to mono with a crossfade so its hum loops.
- `Godot/sounds/hdd_seek_1.wav` to `hdd_seek_8.wav`: cut from "hard disk drive IBM (1999)" by viertelnachvier on Freesound (https://freesound.org/people/viertelnachvier/sounds/321502/), CC0. `tools/make_hdd_seek.sh` cuts them.
- `Godot/win95/sounds/boot_startup.ogg`: the Windows 95 startup sound ("The Microsoft Sound", Brian Eno), (C) Microsoft, not licensed to us. Converted from `C:\WINDOWS\MEDIA\The Microsoft Sound.wav` of a Windows 95 install.
- `Godot/win95/sounds/chord.ogg`, `ding.ogg` and `tada.ogg`: the Windows 95 sample sounds, (C) Microsoft, not licensed to us. Converted from CHORD.WAV, DING.WAV and TADA.WAV in the CABs of the Windows 95 OSR2 CD.
- `Godot/win95/sounds/boot_power_on.ogg`: cut from "PC startup" by bratij on Freesound (https://freesound.org/people/bratij/sounds/841351/), CC0.
- `Godot/win95/sounds/boot_post_beep.ogg`: cut from "PC speaker error beep" by CZghost on Freesound (https://freesound.org/people/CZghost/sounds/264823/), CC0.
- `Godot/win95/sounds/boot_startup.ogg`: the Windows 95 startup sound ("The Microsoft Sound", Brian Eno), (C) Microsoft, not licensed to us. Taken from "The Microsoft Sound.wav" by goldenzoomi1 on Freesound (https://freesound.org/people/goldenzoomi1/sounds/644997/), which lists it as CC BY-NC 4.0.
- `Godot/win95/sounds/hang_buzz.wav`: a slice of `boot_startup.ogg` above, which `tools/make_hang_buzz.sh` cuts; the same terms.
- `Godot/win95/midi/passport.mp3`: PASSPORT.MID from Windows 95, (C) Microsoft, not licensed to us, played on an ESS AudioDrive ES1868F and recorded by blackstorm88, CC BY-NC-ND 4.0, unedited. From the Internet Archive (https://archive.org/details/passport-mid-played-on-a-es-1868-f).
- `Godot/win95/netscape/`: Netscape Navigator 2.0's logo, toolbar icons and splash, drawn for the game by `tools/make_netscape_art.py` after screenshots of the real one; the logo and the look are Netscape's, not licensed to us.
- `Godot/finale/apple_logo.svg`: the Apple logo from [Simple Icons](https://simpleicons.org) 13.21.0, CC0; `Godot/finale/host_boot.gd` draws the Windows logo as four squares. Both are for the finale's fake restart, and both are their owners' trademarks (Apple, Microsoft), not licensed to us.
- `Godot/people/*/back.png`: drawn by an image model (OpenAI's, through the codex CLI) from our own neutral portraits, with `tools/make_portrait_backs.py`. AI-generated.
- `Godot/dev/trailer/sandroperrotta_sigla_2.mp3`: "Sigla 2" by sandroperrotta (https://pixabay.com/users/sandroperrotta-2717508/), under the Pixabay Content License (https://pixabay.com/service/license-summary/): the music of the trailer.
- `Godot/sounds/compufun_jingle.ogg`: the CompuFun jingle, made for the game by Piérre Reimertz; `tools/make_compufun_jingle.sh` makes it from his recording.
- `Godot/sounds/city_ambience.ogg`: cut and muffled from "Westfield.wav" by Islabonita on Freesound (https://freesound.org/people/Islabonita/sounds/178532/), CC0. `tools/make_city_ambience.sh` makes it.
- `Godot/compufun_db/fonts/Px437_IBM_VGA_8x16.ttf`: from [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/) by VileR, CC BY-SA 4.0 (`LICENSE.txt`).
- `Godot/win95/theme/fonts/`: W95FA Pixel, a pixel-grid version of [W95FA](https://fontsarena.com/w95fa-by-alina-sava/) by Alina Sava (FontsArena), SIL OFL 1.1 (`ofl.txt`).
- `Godot/win95/theme/fonts/liberation_sans_bold.ttf`: Liberation Sans Bold 2.1.5 from [liberation-fonts](https://github.com/liberationfonts/liberation-fonts) by Red Hat, with Google's Arimo data, SIL OFL 1.1 (`LIBERATION-LICENSE.txt`); the Scrolling Marquee screensaver's stand-in for Arial Bold.
- `Godot/win95/theme/fonts/px437_ibm_vga_8x16.ttf`: Px437 IBM VGA 8x16 from [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/) by VileR, CC BY-SA 4.0 (`oldschool_pc_fonts_license.txt`).
- `Godot/voices/live/cmudict.txt.gz`: the CMU Pronouncing Dictionary, (C) Carnegie Mellon University, BSD-style licence (`CMUDICT-LICENSE.txt`).
- `native/chimera_voice/`: speaks the voices live with [Chimera](https://github.com/jamesondh/chimera-vocal-synth) (MIT) and [godot-rust](https://github.com/godot-rust/gdext) (MPL-2.0).
- `Godot/voices/`: the customers' voices, rendered with [Chimera](https://github.com/jamesondh/chimera-vocal-synth) by Jameson Hodge, MIT. The game ships only the rendered WAV files.
- `.claude/skills/godot-master/`: the godot-master agent skill from [Game-Dev-Agentic-Skills](https://github.com/thedivergentai/Game-Dev-Agentic-Skills), LGPL-3.0. Not part of the game.

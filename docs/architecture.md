# Code layout

Where the code is: the folders, the main scene tree and the settings that must not change. It changes
in the same commit as the code. The design, what the parts are and why, is on the wiki page
[Architecture](https://github.com/dubiouspotions/humanerror/wiki/Architecture) (local copy:
`wiki/Architecture.md`).

## Folders

```
Godot/               the Godot project: everything the game loads
  main.tscn          the game: the world viewport, the UI layer, the F9 layer (run/main_scene)
  export_presets.cfg Web, Windows Desktop, MacOS, Linux; CI exports them by name
  default_bus_layout.tres  the audio buses: Master, Voice for the customers' voices, and Win95, which follows the volume and mute of the desktop on screen
  game.gd            the Game autoload
  shaders/           psx_world.gdshader, psx_post.gdshader, psx_post_world.tres (the world's post material)
  shaders/crt_looks/ the CRT looks: the Screen View's (crt.gdshader) and the 3D bench screen's (crt_world.gdshader)
  props/             one scene per placeholder model: crt_monitor, pc_tower, counter, shelf, part_box, ...
  props/parts/       the model of each part: motherboard, cpu, fan, gpu, hard_drive
  parts/             part.gd and piece.gd, and one Part per part: <id>.tres
  materials/         one shared material per surface; textures/ holds the PNGs
  rooms/             hotspot.tscn and view_marker.gd, shared by all rooms
  rooms/shop/        shop.tscn, storage.tscn (the storage room), outside.tscn (the back alley, the sky, day and night, rain, the city ambience), job_slots.tscn (the work mat and its slots), job_computer.tscn (one job's computer), open_case.tscn (a computer lying open in the Workview), bench.tscn (the bench screen, keyboard and VGA cable), pipedream.tscn (the Win95 Pipes that grow with the warp), hand.tscn (the part in the hand, held in front of the camera), their meshes and textures
  people/<name>/     person.tres, portrait_<pose>.png, face.png
  customers/         one .tres per customer, customer_body.tscn, job.gd (one computer on the counter)
  customers/<name>/  the pictures in that customer's files, such as pierre/castle_01.png
  voices/            one .wav per customer line, rendered by Chimera; voices.gd names and renders them
  voices/moods/      the mood of each pose (VoiceMood): the speed, pitch and pitch swing of the voice
  voices/types/      voice types (VoiceType), made in the Voice Lab: a base voice, an alternate, and a curve
  voices/live/       the live voice: live_voice.js (web), the dictionary; tools/build-voice.sh adds the wasm, the libraries and the .gdextension
  sounds/            sound effects: the audio files, and one SoundSet .tres per effect (its takes,
                     volume and pitch range), exported where the effect happens
  problems/          one .tres per problem
  days/              day_1.tres to day_7.tres
  ui/                loading screen, dialogue overlay, post-it, post-it label (the Workview post-it's text), end of day (the close-the-shop question, the night between two days), screen view, bench screen, CRT screen and tube, debug menu, F9 screen, theme.tres
  ui/logos/          the CompuFun logos (the loading screen, the boot splash, the sign in the shop)
  win95/             the Win95 interface (the Win95 developer's folder)
  win95/midi/        recordings that .mid files play in Media Player (Godot plays no MIDI)
  win95/solitaire/   Solitaire: the rules (klondike.gd), the window, the table and the card pictures
  compufun_db/       CompuFunDB, the DOS database on the work computer, and its VGA font
  addons/dialogue_editor/  the Dialogue tab in the editor
  tests/             headless tests of the Game API: test.gd (the base), test_*.gd, run.gd (runs them all)
native/chimera_voice/  the live voice in Rust: wasm for the web, the ChimeraVoice extension for desktop
feedback/            the F9 reports (outside Godot, so Godot does not import them)
tools/               scripts; build-voice.sh builds the live voice; run.sh plays the game without the editor; sync-wiki.sh clones or pulls the wiki into wiki/; make_castle_renders.py renders Pierre's castle pictures; make_crt_sounds.py synthesizes the bench screen's sounds; chimera-moods.patch
wiki/                the GitHub wiki, cloned by tools/sync-wiki.sh (ignored by the repo)
docs/                the rules for people and agents: this code layout, code standard, build, gotchas, glossary
.github/workflows/   CI: tests and export on push, itch.io deploy, Discord notifications
```

Play starts `ui/loading_screen.tscn`, which loads the main scene in the background:

```
Main (Node)                              the main buffer: the window
├─ World (SubViewportContainer, psx_post material, scaled to the window)
│  └─ SubViewport (480 × 270)            the world buffer
│     └─ the room (shop.tscn); its monitor shows the screen buffer
├─ UI (CanvasLayer)
│  ├─ the UI screens
│  ├─ ScreenView (screen_view.tscn: follows the bench screen, fades in for the Screen View)
│  │  ├─ ScreenBuffer (SubViewport, 640 × 480)  the screen buffer: updates always, embeds sub-windows
│  │  │  └─ BenchScreen (ui/bench_screen.tscn)
│  │  │     ├─ NoSignal (win95/no_signal.tscn), while the VGA cable hangs free
│  │  │     └─ win95/win95.tscn         the connected job's desktop; each job has one, the others wait out of the tree
│  │  ├─ Screen (crt_screen.gd)          shows the buffer at 2× through the CRT look, passes it the bent mouse
│  │  └─ Tube (crt_tube.gd)              this monitor's power, signal lock, degauss and sounds
│  └─ CompuFunDBView (screen_view.tscn again: follows the work monitor, fades in for CompuFunDB)
│     └─ ScreenBuffer (SubViewport, 640 × 480), Screen, Tube
│        └─ CompuFunDB (compufun_db/compufun_db.tscn)
├─ DebugMenu (CanvasLayer, F2)
└─ Feedback (CanvasLayer, on top of everything)
```

## Load-bearing settings

Do not change these without the team:

- **The Godot project is in `Godot/`, not the repo root.** Docs, CI and art sources stay out of Godot's import scan. CI's `working-directory` and artifact paths assume it.
- **GL Compatibility renderer.** The web export needs it. Forward+ breaks the web build.
- **`textures/vram_compression/import_etc2_astc=true`.** The macOS export is universal (arm64) and needs ETC2/ASTC textures. Without it, the macOS export fails.
- **The names of the export presets** (`Web`, `Windows Desktop`, `MacOS`, `Linux`). CI exports them by name.

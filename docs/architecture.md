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
  game.gd            the Game autoload
  shaders/           psx_world.gdshader, psx_post.gdshader, psx_post_world.tres (the world's post material)
  props/             one scene per placeholder model: crt_monitor, pc_tower, counter, shelf, ...
  materials/         one shared material per surface; textures/ holds the PNGs
  rooms/             hotspot.tscn and view_marker.gd, shared by all rooms
  rooms/shop/        shop.tscn, storage.tscn (the storage room), outside.tscn (the back alley, the sky, day and night, rain, the city ambience), job_slots.tscn (the work mat and its slots), job_computer.tscn (one job's computer), their meshes and textures
  people/<name>/     person.tres, portrait_<pose>.png, face.png
  customers/         one .tres per customer, customer_body.tscn, job.gd (one computer on the counter)
  voices/            one .wav per customer line, rendered by Chimera; voices.gd names and renders them
  voices/moods/      the mood of each pose (VoiceMood): the speed, pitch and pitch swing of the voice
  sounds/            sound effects, such as footstep.wav
  problems/          one .tres per problem
  days/              day_1.tres to day_7.tres
  ui/                loading screen, dialogue overlay, post-it, CompufunDB, screen view, debug menu, F9 screen, theme.tres
  ui/logos/          the CompuFun logos (the loading screen, the boot splash, the sign in the shop)
  win95/             the Win95 interface (the Win95 developer's folder)
  addons/dialogue_editor/  the Dialogue tab in the editor
feedback/            the F9 reports (outside Godot, so Godot does not import them)
tools/               scripts; run.sh plays the game without the editor; sync-wiki.sh clones or pulls the wiki into wiki/; chimera-moods.patch
wiki/                the GitHub wiki, cloned by tools/sync-wiki.sh (ignored by the repo)
docs/                the rules for people and agents: this code layout, code standard, build, gotchas, glossary
.github/workflows/   CI: export on push, itch.io deploy, Discord notifications
```

Play starts `ui/loading_screen.tscn`, which loads the main scene in the background:

```
Main (Node)                              the main buffer: the window
├─ World (SubViewportContainer, psx_post material, scaled to the window)
│  └─ SubViewport (480 × 270)            the world buffer
│     └─ the room (shop.tscn); its monitor shows the screen buffer
├─ UI (CanvasLayer)
│  ├─ the UI screens
│  └─ ScreenView (screen_view.tscn: follows the 3D screen, fades in for the Screen View)
│     └─ SubViewportContainer
│        └─ SubViewport (640 × 480)      the screen buffer, shown at 2×: updates always, embeds sub-windows
│           └─ win95/desktop.tscn
├─ DebugMenu (CanvasLayer, F2)
└─ Feedback (CanvasLayer, on top of everything)
```

## Load-bearing settings

Do not change these without the team:

- **The Godot project is in `Godot/`, not the repo root.** Docs, CI and art sources stay out of Godot's import scan. CI's `working-directory` and artifact paths assume it.
- **GL Compatibility renderer.** The web export needs it. Forward+ breaks the web build.
- **`textures/vram_compression/import_etc2_astc=true`.** The macOS export is universal (arm64) and needs ETC2/ASTC textures. Without it, the macOS export fails.
- **The names of the export presets** (`Web`, `Windows Desktop`, `MacOS`, `Linux`). CI exports them by name.

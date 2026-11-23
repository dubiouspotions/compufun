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
  default_bus_layout.tres  the audio buses: Master; Shop, everything heard from the shop (it pans right while the player is in the storage room), fed by Voice for the customers' voices, Win95, Street (muffled until the door opens) and Room (the shop's reverb); Storage, the storage room's reverb
  game.gd            the Game autoload
  shaders/           psx_world.gdshader (its body in psx_world.gdshaderinc; psx_world_layered.gdshader draws it in the transparent pass, in sorting_offset order), psx_post.gdshader, psx_post_world.tres (the world's post material); pulse_ring.gdshader (the beating ring around a panel screw that can turn)
  shaders/crt_looks/ the CRT looks: the Screen View's (crt.gdshader) and the 3D bench screen's (crt_world.gdshader)
  props/             one scene per placeholder model: crt_monitor, pc_tower, counter, shelf, part_box, ...
  props/parts/       the model of each part: motherboard, cpu, fan, ram, gpu, hard_drive
  props/case_fronts/ the fronts of the computer cases (Computer.case_front): drive bays, floppy drives, badges
  parts/             part.gd and piece.gd, and one Part per part or place: <id>.tres (ram_1 and ram_2 are the RAM slots)
  materials/         one shared material per surface; textures/ holds the PNGs
  rooms/             hotspot.tscn, view_marker.gd and ground.gd (a floor and its footsteps), shared by all rooms
  rooms/shop/        shop.tscn, storage.tscn (the storage room), outside.tscn (the back alley, the sky, day and night, rain and its sound, the city ambience), job_slots.tscn (the work mat and its slots), job_computer.tscn (one job's computer), open_case.tscn (a computer lying on its side), bench.tscn (the bench screen, keyboard and VGA cable), work_cables.tscn (the cables from the work computer to its screen, the printer and the modem), pipedream.tscn (the Win95 Pipes that grow with the warp), ceiling_mouse.tscn (the easter egg in the ceiling), hand.tscn (the part in the hand, held in front of the camera), the_end.tscn (the body with the pipe through the chest, at the end), their meshes and textures, sound_zones.tscn (where a 3D sound plays: in the shop with the Room reverb, in the storage room with the Storage reverb, or on the Street bus)
  people/<name>/     person.tres, portrait_<mood>.png, face.png
  customers/         one .tres per customer, customer_body.tscn, photo_relief.gd (the upper body from the portrait), job.gd (one computer on the counter)
  customers/<name>/  the pictures in that customer's files, such as pierre/castle_01.png
  voices/            one .wav per customer line, rendered by Chimera; voices.gd names and renders them
  voices/persons/    voice persons (VoicePerson), one per people/<name>/: who speaks, a body with its build and timbre; the bottom layer
  voices/moods/      the voice of each mood (VoiceMood): speed, pitch, pitch swing and more; the middle layer
  voices/effects/    voice effects (VoiceEffect): a base, an alternate and a curve; the top layer
  voices/live/       the live voice: live_voice.js (web), the dictionary; tools/build-voice.sh adds the wasm, the libraries and the .gdextension
  sounds/            sound effects: the audio files, and one SoundSet .tres per effect (its takes,
                     volume and pitch range), exported where the effect happens; hum.gd, a quiet loop
                     that plays while a thing runs (the storage bulb, a PC's fans, a CRT)
  problems/          one .tres per problem: its mechanics (its text is in story/problems/)
  corruption/        one scene per corruption sign (<id>.tscn); corruption_sign.gd is their base, corruption_signs.gd loads them all into the shop
  story/             the story files (docs/dialogue.md): days/, errands/, problems/ and bible/; day.gd and errand.gd, the Day and Errand they load into; story_format.gd reads and writes them, story_files.gd loads the week with a writer's drafts over it, story_check.gd finds its missing links
  endings/           one Ending per way the week can end (ending.gd): finale.tres (the default), pipes.tres (off)
  finale/            the finale, the default ending (and from the F2 World tab): finale.tscn (the corruption, the bluescreen, the credits), host_boot.gd (the player's own computer, faked: its restart and its error), apple_logo.svg, finale_text.tres (all its text)
  ui/                loading screen, dialogue overlay, phone call (whom to call for a pickup), post-it label (the Workview post-it's text), carried printout (the printout that the player carries: low on the left, or raised on the right side of the view and beside the CompuFunDB screen), end of day (the close-the-shop question, in the game's panel or, from day 4's warp, a Win95 message box; the night between two days, "DAY N" drawn at 480 × 270 through psx_post like the world), window_bluescreen.tscn (the bluescreen over the window, in the finale), screen view, bench screen, CRT screen and tube, debug menu, F9 screen, theme.tres
  ui/logos/          the CompuFun logos (the game icon, the loading screen, the boot splash, the sign in the shop)
  win95/             the Win95 interface (the Win95 developer's folder)
  win95/applets/     the Control Panel's applets: applet.gd, one Applet .tres per icon, and each one's property sheet
  win95/savers/      the screensavers: saver.gd, their base, and one Saver each; SAVERS in applets/display_screensaver.gd names them
  win95/theme/schemes/  Win95's 27 colour schemes, one Win95Palette each, read from the VM's registry
  win95/theme/icons_extracted/  every icon in a Windows 95 install, named, with manifest.json (docs/win95-icons.md)
  win95/midi/        recordings that .mid files play in Media Player (Godot plays no MIDI)
  win95/solitaire/   Solitaire: the rules (klondike.gd), the window, the table and the card pictures
  compufun_db/       CompuFunDB, the DOS database on the work computer, its VGA font, and the work computer's boot (a 386)
  dev/               the Dev menu, the Voice Lab, story.gd (prints the story check) and story_week_page.gd (the wiki's "The Week"); no export contains it
  dev/story_lab/     the Story Lab (F4): story_lab.tscn, the week board, the problems (problem_panel.gd), the corruption signs and where the week starts them (sign_panel.gd), the drafts (story_drafts.gd), the issue that Send makes
  tests/             headless tests of the Game API: test.gd (the base), test_*.gd, run.gd (runs them all)
native/chimera_voice/  the live voice in Rust: wasm for the web, the ChimeraVoice extension for desktop
feedback/            the F9 reports (outside Godot, so Godot does not import them)
tools/               scripts; build-voice.sh builds the live voice; write-build-info.sh writes the version and commit that a build shows; run.sh plays the game without the editor; sync-wiki.sh clones or pulls the wiki into wiki/; make_castle_renders.py renders Pierre's castle pictures; make_crt_sounds.py synthesizes the bench screen's sounds; make_organs.gd builds the organs that replace the parts in Skater Bro's computer (problem organ_failure), the blood in its case and their wet materials; cut_organ_sounds.sh cuts the heartbeat, the wheeze and the squelches of the organs from Freesound recordings; make_case_stab.py synthesizes the stab as the organ computer's case opens; make_cd_sounds.py cuts the CD-ROM drive's button and tray sounds from recordings of a real drive; make_antivirus_label.sh draws the label of the CompuFun AntiVirus floppy; make_floppy_label.py draws the plain floppy label, the Windows flag; make_pc_speaker.py synthesizes the PC speaker's tone; make_part_sounds.sh cuts the rattle and the clunks of misplaced parts; make_hang_buzz.sh cuts the buzz of a hung Win95; extract_win95_icons.py extracts the Win95 icons; make_mouse_squeak.py synthesizes the ceiling mouse's squeak; make_end_sounds.sh makes the sounds of the end; make_trees.gd builds the tree meshes of the Outside; make_wall_shelf.gd draws and builds the shop's wall shelving of goods for sale; make_printer.gd draws and builds the dot-matrix printer under the work desk; make_phone.gd draws and builds the push-button desk phone on the counter and in the phone call; make_flag_sticker.py draws the Korean flag sticker; make_activist_stickers.py draws the stickers on the activist's computer; make_asset_tag.py draws the asset tag on the office girl's computer; make_note_arrow.py draws the arrow on the taped note; make_hamster_art.py draws the hamster sticker on the nice lady's computer and her Win95 wallpaper; make_outdoor_steps.sh makes the asphalt and sidewalk footsteps; make_compufun_jingle.sh makes the loading screen's jingle; chimera-moods.patch; make_portrait_backs.py asks an image model for each person seen from behind
wiki/                the GitHub wiki, cloned by tools/sync-wiki.sh (ignored by the repo)
docs/                the rules for people and agents: this code layout, code standard, build, gotchas, glossary
.github/workflows/   CI: tests and export on push, releases (version tag, signing, itch.io deploy), the wiki's "The Week", Discord notifications
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
│  │  │     └─ win95/win95.tscn         the connected job's desktop; each job has one, the others run in a viewport that draws nothing, their Win95 sounds silent
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

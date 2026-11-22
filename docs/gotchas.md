# Gotchas

Hard-won non-obvious facts, grouped by area. This is the default landing place for memory that
doesn't fit an existing doc — when a section here grows past a handful of entries, promote it to
its own doc and give it a row in [index.md](index.md).

The bar: **would a competent person rediscover this by reading the code?** If yes, leave it out.
If it took an afternoon, a debugger, or a wrong assumption to find, it belongs here.

Format — symptom first, because that's what a future reader is searching for:

> **The symptom, as you'd experience it.** What's actually happening underneath. What to do
> instead. Date it if it's version-dependent, so a future reader knows when to re-check.

## Godot 4.7.2

**The first turn to a view stalls for 100 to 200 ms.** The GL Compatibility renderer compiles a
shader the first time something that uses it is on screen, and each view has things no other view
shows. Measured 2026-11-21: the first turn right 100 to 193 ms, the second 5 ms. `Shop.warm_up()`
shows every view for one frame behind the loading screen; with it, the first turn takes 5 ms. A new
view, or a thing that first appears later (a ghost, an outline), can stall again: warm it up too.

**The editor saves scenes and resources with data missing, or one scene's content under another
scene's path.** We saw this after other Godot processes (headless `--import` runs and test runs)
used the same `Godot/.godot/` caches as the open editor; its UID cache then held two UIDs for
one file. The cause is not confirmed. Run one Godot per checkout at a time: close the editor
before headless runs, or play with `tools/run.sh`, which refuses while the editor is open. To
recover, quit Godot, move `Godot/.godot/` out of the repo, and reopen. Diff every editor save
before you commit it. — 2026-11

**A scene shows as modified right after you open the project.** The editor adds a `uid=` to the
`[gd_scene]` header and a `unique_id=` to each node on first save. Commit that change on its own.
— 2026-11

**A data file saved from a headless script loses its `uid=` references.** `ResourceSaver.save`
drops them. Write them back from each referenced file's header or `.import`, so the file
matches what the editor writes. — 2026-10

**A tool script fails to compile under `godot -s script.gd`.** Scripts that reference an
autoload don't compile there. Run such a tool as a scene instead. — 2026-10

**A `godot -s` script with a parse error exits 0.** Godot prints the parse error and quits as if
the script had passed. `tests/run.gd` therefore also requires the line that a passing test
prints, not only exit code 0. — 2026-11

**A run logs "ObjectDB instances were leaked" and "resources still in use at exit", naming a
sound.** That sound was playing when the game quit: the city ambience and the hums always are, a
customer voice sometimes. It happens only at exit and only on some runs, and it needs no fix. In a headless
test, every playback that a player stopped during the run is listed too (`AudioStreamPlayback...`),
with a bare `AudioStreamPlayer` as well. Any other object in the `--verbose` list of leaks is a real
leak. — 2026-11

**An `AudioStreamPlayer3D` ignores the audio bus and the reverb of the `Area3D` that it is in.** Its
`area_mask` is 0 by default in Godot 4.7, so it finds no area at all. Set it to the sound zones'
layer (`SoundSet.SOUND_ZONES`, 1) on every 3D player that should sound like its room; a player
that `SoundSet.play_at` makes gets it. — 2026-11-22

**A 3D sound in a reverb zone plays only as reverb, with no direct sound.** Godot 4.7.2 sends a
player inside an `Area3D` either to the area's bus override or, with no override, to nothing but
the reverb bus (`AudioStreamPlayer3D::_update_panning`). Turn on `audio_bus_override` on every
reverb zone, as `sound_zones.tscn` does. — 2026-11-22

**A quiet 3D sound in a reverb zone is as loud in the reverb as a loud one.** With
`reverb_bus_uniformity` above 0, part of the send is scaled by the distance from the listener to
the zone, clamped at the player's `max_db`; inside the zone that is +3 dB for every sound, whatever
its `volume_db` and distance. Measured 2026-11-22: a click at -30 dB sent only 18 dB less than at
0 dB. Keep the uniformity at 0: then the send is the direct sound times `reverb_bus_amount`.
— 2026-11-22

**An `AudioEffectReverb` sounds brighter with more `damping`, and won't decay much faster than
0.5 s.** Godot's damping sets a low-pass in the reverb's feedback from 2.5 kHz (0) to 10 kHz (1),
so 0 damps the highs most. Its eight comb filters have fixed lengths (25 to 37 ms); `room_size`
only sets their feedback, so a "small" room is a short-lived big one. `hipass` 1 is a 6 kHz
high-pass on the input (0.2 is 1.2 kHz). Measured 2026-11-22, `room_size` 0: T60 about 0.45 s.
— 2026-11-22

**Every `--import` logs "resources still in use at exit", naming data scripts such as
`customer.gd` and `win95_setup.gd`.** A script with a `static var` that other scripts reach was
loaded: GDScript keeps the static's script and everything it depends on alive past the exit. The
WordPad and the Calculator had one each for a corruption sign. Keep such shared state off
statics: the signs now set metadata on the scene tree's root, which dies with the tree. To find
the file, import copies of the project with one change removed each. — 2026-11-21

**A paused `AudioStreamPlayer` reads `playing == false` and ignores `seek()`.** Check
`stream_paused` to tell paused from stopped, and seek a paused player with `play(from)` and then
`stream_paused = true`, as `win95/media_player.gd` does. — 2026-11

**A custom cursor set in Project Settings logs "Failed loading resource" in a fresh checkout,
and CI exports from one.** `display/mouse_cursor/custom_image` is read before the image is
imported. Set the cursor in code with `Input.set_custom_mouse_cursor` once the game runs (see
`ui/screen_view.gd`); the loading screen keeps the system arrow. — 2026-11

**A changed copy of an input event, pushed from `_input`, reaches the controls together with
the original.** `Viewport.push_input` clears the "handled" flag that the original shares (with
`handle_input_locally` off, the root window's), so marking the original handled before the push
has no effect. Call `set_input_as_handled()` after the push, as `win95/mouse_input.gd` does.
— 2026-11

**A Node export (`@export var doorway: Node3D`) is null at run time, though the scene sets it.** In a
scene file, a Node export needs its name in the node's header, `node_paths=PackedStringArray("doorway")`;
without it, Godot reads the `NodePath` value and drops it. The editor writes the header; a scene
written by hand or by a script must too. — 2026-11-22

**A hand-written scene logs an engine error on load.** It references a resource by a UID that
the cache doesn't know. Use path-only `ext_resource` lines in scenes you write by hand.
— 2026-10

**"Can't change orientation of VBoxContainer", or a container keeps a stale layout after
switching orientation.** HBox/VBoxContainer and HFlow/VFlowContainer reject any set of
`vertical`, even to the value they have; use a BoxContainer or FlowContainer to switch at run
time. Setting `vertical` sorts at once, with the children's old sizes. If a child's size changes
later in the same frame and ends where it began the frame, no `minimum_size_changed` fires and
nothing sorts again: call `queue_sort()` after the change (`IconView`, `FileIcon`). — 2026-11

## Web export

**Sound stutters or the first play of a track hangs for a second.** The web build has no
threads, so audio plays as WebAudio samples: the first play decodes the whole stream (about
1 s per music file), and every play copies the decoded buffer. Play every sound once behind a
loading screen, and loop music instead of restarting it. — 2026-10

**A bus effect (a low-pass, a reverb) works in the editor and does nothing in the web build.** The
web build plays sounds as samples, and samples skip `AudioEffect`s (Godot 4.7.2 class reference,
`AudioServer.PLAYBACK_TYPE_SAMPLE`). Bake the effect into the file instead, as
`tools/make_city_ambience.sh` does. — 2026-11

## PSX look

**A big surface's texture swims or bends as the camera turns.** `psx_world` maps textures affinely,
so a texture bends across each triangle, and the bend grows with the triangle's size on screen.
Subdivide boxes and planes into quads of about 0.5 m (`subdivide_width`, `_height`, `_depth`), as
the shop's walls, floor and counter are. — 2026-11

**A thin layer on a surface tears as the camera turns, and the surface shows through.** The vertex
snap moves every vertex by up to half a pixel of the world buffer; on a counter top seen at a
grazing angle that is about 1 cm of depth. Make a layer at least 1 cm thick, as the work mat is.
— 2026-11

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
sound.** That sound was playing when the game quit: the city ambience always is, a customer voice
sometimes. It happens only at exit and only on some runs, and it needs no fix. Any other object
in the `--verbose` list of leaks is a real leak. — 2026-11

**A custom cursor set in Project Settings logs "Failed loading resource" in a fresh checkout,
and CI exports from one.** `display/mouse_cursor/custom_image` is read before the image is
imported. Set the cursor in code with `Input.set_custom_mouse_cursor` once the game runs (see
`ui/screen_view.gd`); the loading screen keeps the system arrow. — 2026-11

**A hand-written scene logs an engine error on load.** It references a resource by a UID that
the cache doesn't know. Use path-only `ext_resource` lines in scenes you write by hand.
— 2026-10

## Web export

**Sound stutters or the first play of a track hangs for a second.** The web build has no
threads, so audio plays as WebAudio samples: the first play decodes the whole stream (about
1 s per music file), and every play copies the decoded buffer. Play every sound once behind a
loading screen, and loop music instead of restarting it. — 2026-10

**A bus effect (a low-pass, a reverb) works in the editor and does nothing in the web build.** The
web build plays sounds as samples, and samples skip `AudioEffect`s (Godot 4.7.2 class reference,
`AudioServer.PLAYBACK_TYPE_SAMPLE`). Bake the effect into the file instead, as
`tools/make_city_ambience.sh` does. — 2026-11

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

**A scene shows as modified right after you open the project.** The editor adds a `uid=` to the
`[gd_scene]` header and a `unique_id=` to each node on first save. Commit that change on its own.
— 2026-11

**A data file saved from a headless script loses its `uid=` references.** `ResourceSaver.save`
drops them. Write them back from each referenced file's header or `.import`, so the file
matches what the editor writes. — 2026-10

**A tool script fails to compile under `godot -s script.gd`.** Scripts that reference an
autoload don't compile there. Run such a tool as a scene instead. — 2026-10

**A hand-written scene logs an engine error on load.** It references a resource by a UID that
the cache doesn't know. Use path-only `ext_resource` lines in scenes you write by hand.
— 2026-10

## Web export

**Sound stutters or the first play of a track hangs for a second.** The web build has no
threads, so audio plays as WebAudio samples: the first play decodes the whole stream (about
1 s per music file), and every play copies the decoded buffer. Play every sound once behind a
loading screen, and loop music instead of restarting it. — 2026-10

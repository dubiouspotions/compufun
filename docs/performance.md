# Performance

What a frame costs, how to measure it, and what keeps it cheap.

## Measure

`dev/perf_probe.gd` runs `main.tscn` in a real window, with four running computers on the counter, and
prints the cost of each case: the Main View, the Screen View, CompuFunDB, the Story Lab idle and while
typing in it.

```sh
"$GODOT" --path . --resolution 1920x1080 -s res://dev/perf_probe.gd -- 2                  # day 2, all cases
"$GODOT" --path . --resolution 1920x1080 -s res://dev/perf_probe.gd -- 2 main +noshadows   # one case, one part off
```

It runs uncapped (no V-Sync, no FPS cap), so the ms per frame is what a frame costs. A `+knob` turns one
part off first (the list is in `_turn()`); the difference to a run without it is what that part costs.
With `capped` it keeps the project's settings: measure the CPU load from outside then, with
`ps -o %cpu= -p <pid>`. `drawn` counts the frames that the window really drew; an idle screen in low
processor mode draws 0.

The Compatibility renderer measures no GPU time. `Performance.TIME_PROCESS` does not give a usable
per-frame script time either; turn parts off instead.

## Where the cost goes

On an M5 Max with a Retina screen at 120 Hz, day 2, before and after the frame cap and the Story Lab fix
(CPU is a share of one core):

| Case | CPU before (120 Hz) | CPU after | Frames drawn after |
| --- | --- | --- | --- |
| Main View | 32 % | 17 % | 60/s |
| Screen View | 26 % | 13 % | 60/s |
| CompuFunDB | 19 % | 10 % | 60/s |
| Story Lab, idle | 24 % | 2 % | 7/s |
| Story Lab, typing | 33 % | 4 % | 13/s |

- **The frame rate.** V-Sync alone draws as many frames as the screen shows: 120 or more on a
  ProMotion Mac or a gaming laptop. `application/run/max_fps=60` halves the work there. The web build
  honours it too.
- **The storage bulb's shadow.** An omni light with a shadow renders its shadow cube (six passes over
  every caster in its range) in every frame, even when nothing moves: the Compatibility renderer keeps
  no shadow cache. The storage room's hanging bulb was 400 of the Main View's 672 draw calls, about a
  quarter of its frame. It now casts its shadow only while the camera sees the storage room
  (`shadow_bounds`) or in the views that list it (`shadow_views`, the End): the Main View draws 272
  calls, and its CPU falls from 17 % to 13.5 %. Without the shadow, 60 pixels at the end of the Main
  View's left shelf change by up to 19 of 255; every other view changes by 3 at most. The shop's three
  ceiling lights have no casters in range and cost nothing. Give a new light with a shadow the same
  bounds.
- **The 3D world** is about half of the Main View's frame (the 480 x 270 world buffer, its lights and
  shadows). The post shader, the two screen buffers and the Pipedream (on day 2) cost little.

## What keeps the window drawing

Low processor mode draws a frame only when something changed. Two things count as a change in every
frame:

- a SubViewport that updates always;
- a visible canvas item whose shader reads `TIME`, such as the CRT look of the Screen View.

So the Story Lab, which covers the paused game, sets the game's always-updating viewports to
`UPDATE_DISABLED` (they keep their last picture), hides what draws below it from the renderer
(`RenderingServer.canvas_item_set_visible`, so the game's nodes stay visible to the game), and turns low
processor mode on. All three come back when it hides.

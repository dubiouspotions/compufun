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
per-frame script time either; turn parts off instead. On macOS, `ioreg -r -d 1 -c IOAccelerator` gives
the GPU's "Device Utilization %", and `sample <pid> 5` shows where each thread spends its time; Godot's
own frames have no symbols, but the GL driver's do.

For GPU time on a Mac, record a Metal System Trace of the running game and sum its GPU intervals:

```sh
"$GODOT" --path . --resolution 1920x1080 -s res://dev/perf_probe.gd -- 2 capped screen &
sleep 10   # past the warm-up
xcrun xctrace record --template 'Metal System Trace' --attach $! --time-limit 4s --output game.trace
xcrun xctrace export --input game.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' > gpu.xml
python3 ../tools/metal_gpu_time.py gpu.xml
```

Measure on a weak Mac: miquon, an M1 Mac mini, stands in for the team's M1 and M2 laptops. A fast Mac
hides costs that a laptop pays: on an M5 Max the Main View takes 1.9 ms a frame, on the M1 5.5 ms.

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

## On an M1

At 60 fps, day 2, on a 1080p screen (CPU is a share of one core):

| Case | CPU | GPU |
| --- | --- | --- |
| Main View | 45 % | 16 % |
| Screen View | 43 % | 24 % |
| CompuFunDB | 32 % | 24 % |
| Story Lab, idle | 10 % | 1 % |

- **The GL driver.** The main thread spends most of its time in Apple's OpenGL, which translates every
  draw call and render pass to Metal. The cost grows with draw calls, viewports and passes, not with
  pixels. Godot also writes GPU timer queries for every viewport in every frame, and each makes this
  driver submit its work early; a viewport that doesn't render costs none.
- **The screen buffers** update only while something draws them (`UPDATE_WHEN_VISIBLE`): the 3D monitor
  or the Screen View. A monitor out of sight costs nothing, and its first frame back in view can show
  its last picture for one frame.
- **The GPU** is busy 1.2 ms per frame in the Main View, and 2.6 ms in the Screen View and 2.4 ms in
  CompuFunDB (Metal System Trace). The CRT look took 2.4 ms of the Screen View's 3.8 before its
  sharp samples read once and its glow moved to its own pass (docs/crt.md); it now takes about
  1.2 ms. It is per-pixel work, so a Retina screen with about three times the pixels pays it about
  three times.
- **The post shader** skips its search for the nearest Windows colour while `windows_shades` is 0, which
  it is until the warp drifts the colours; it is the only per-pixel pass over the whole window, so a
  Retina screen pays it 2.7 times over.
- **Not worth it:** the ANGLE driver (`--rendering-driver opengl3_angle`) costs more CPU and GPU than
  Apple's OpenGL. Audio, bus effects included, is 2 to 3 points.

## What keeps the window drawing

Low processor mode draws a frame only when something changed. Two things count as a change in every
frame:

- a SubViewport that updates always;
- a visible canvas item whose shader reads `TIME`, such as the CRT look of the Screen View.

So the Story Lab, which covers the paused game, sets the game's always-updating viewports to
`UPDATE_DISABLED` (they keep their last picture), hides what draws below it from the renderer
(`RenderingServer.canvas_item_set_visible`, so the game's nodes stay visible to the game), and turns low
processor mode on, with one display frame of sleep between the loop's turns instead of 6.9 ms. All of
it comes back when the Lab hides.

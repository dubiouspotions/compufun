# The CRT look

The shop's monitors look like mid-90s office VGA monitors, in their close-ups and in the 3D room: the
bench screen (the Screen View) and the work computer (CompuFunDB).

| Part | What it does |
| --- | --- |
| `shaders/crt.gdshader` | The CRT look of a close-up: curve, scanlines, mask, glow, convergence, focus, ghosting, noise, glass reflection, colour. |
| `shaders/crt_glow.gdshader` | The close-up's glow, once per buffer pixel, into a viewport that `CrtScreen` makes beside the buffer. |
| `shaders/crt_world.gdshader` | A 3D monitor's screen: the same curve and light, without the mask and scanlines. |
| `shaders/psx.gdshaderinc` | The PSX dither and colour cut, shared by `psx_post` and the close-up's glass border. |
| `shaders/crt.gdshaderinc` | What both share: the curve (`crt_bend`), the tube's face, the tube's state and the software cursor. |
| `shaders/crt_looks/` | The looks, as ShaderMaterials. `subtle_vga` is the Screen View's; `world_monitor` is the 3D screen's. |
| `ui/crt_screen.gd` | A close-up's screen: shows the buffer through the look, bends the mouse, sets the cursor. |
| `ui/crt_tube.gd` | One monitor's tube: power, signal lock, degauss, magnetised mask, and their sounds. |

To tune a look, open its `.tres` and drag the sliders. To try another, drop it on the Screen View's
`Screen` Material. The Screen View starts its zoom with the 3D screen's curve (`far_look`) and
blends to its own as the camera arrives, so the screen bends more from a distance.

## The tube's state

Each monitor has its own `CrtTube`, a child of its `ScreenView`. It animates the `crt_*` uniforms of
`crt.gdshaderinc` (`crt_power`, `crt_warmup`, `crt_degauss`, `crt_blank`, `crt_sync`, `crt_picture`,
`crt_magnetization`, `crt_cursor`) on that monitor's two looks: the close-up's (`CrtScreen` adds it) and the 3D screen's
(`main.gd` adds it with `ScreenView.add_look()`). So the close-up and the 3D screen show one tube,
and the bench's power cuts and lost signals leave the work computer alone. They are not global
uniforms for that reason. `ScreenView` calls `reconcile()` on every `Game.changed`: the tube is on
while its monitor is switched on (`ScreenView.switched_on`: on at the start; only
`ScreenView.toggle_power()` flips it, as the monitors have no power button), and has a signal while its content's `has_picture()` says so (the bench: a
running computer is connected; CompuFunDB: always):

- **The game starts:** the tube is already on and warm, silently.
- **Switched on:** a switch clunk, static, a degauss, and a dim, oversized picture that
  warms up over 3 seconds.
- **Switched off:** the picture collapses to a white-hot line, then a dot that fades.
- **A running computer connects:** a relay click, black while the monitor finds the signal, then
  the picture rolls and locks.
- **The signal goes** (cable off, computer off): the picture tears and rolls away, a relay click,
  then the monitor's NO SIGNAL box.
- **The room light:** each 3D monitor's `Glow` (a SpotLight3D in `props/crt_monitor.tscn`, 9300 K
  white, no shadow) lights the desk in front of it. `CrtMonitor` sets its energy every frame from
  the 3D screen's uniforms: it warms up with the picture, goes with the collapse and the lost signal,
  and is brighter with a computer's picture (`crt_picture`) than with the NO SIGNAL box. It goes
  dark with the degauss's black (`crt_blank`).
- **The bezel's light:** `ScreenLight`, a small shadowless OmniLight3D just in front of the screen,
  lights the monitor's own bezel and recess, which `Glow` points away from. It follows the tube like
  `Glow`, and takes the picture's average colour and brightness: `CrtMonitor` renders the screen
  buffer's average into a 1 x 1 viewport (`shaders/screen_average.gdshader`) and reads it back
  every `average_seconds`, because each read waits for the GPU.
- **Magnetised mask:** while the screen shows a computer, blotches of wrong colour build up at
  `magnetize_per_second` times the day's warp, up to the warp, so Cambion magnetises the screen as
  the week goes on. The Degauss button on the bench screen's right bezel (`Bench.degauss_pressed`)
  clears them; it can be pressed from the Screen View too (`main.gd` `_click_outside_screen`).
- **Degauss:** the picture twists, bulges, shakes and its colours swim; at `degauss_blank_at` it
  blanks to black (`crt_blank`) while the mask clears, fades back in, and the mangling dies down
  over `degauss_settle_seconds`. The timings are exports on `CrtTube`.

`tools/make_crt_sounds.py` synthesizes the sounds into `sounds/crt_*.wav`.

## What a VGA monitor looked like, and why

- **Faint scanlines.** 640 x 480 at 60 Hz scans 480 lines at 31.5 kHz; only 320 x 200 is
  double-scanned. On a 14-15" tube the lines are about 0.43 mm apart, and the beam spot is about
  as wide, so the gap between lines barely shows. Bright pixels widen the beam and close it
  (`beam_bloom`). Heavy scanlines are a TV or arcade look (15 kHz, 240 lines).
- **A fine mask.** A 0.28 mm shadow mask puts about 1.4 phosphor triads under each pixel, finer
  than our 2 x 2 screen pixels per VGA pixel can draw. The mask is fixed to the screen's pixels:
  magenta/green pairs up to 2.75x, red/green/blue triads above. A 14-15" Trinitron has
  stripes instead and one faint horizontal damper wire two thirds of the way down.
- **9300 K white.** Monitors shipped with a bluish white (`white_point`).
- **Gentle curvature** with rounded tube corners; a Trinitron curves only from left to right.
- **Convergence** error grows toward the corners (0.3-0.4 mm in period specs).
- **A soft beam.** The video bandwidth smears each pixel sideways (`softness`), so text loses
  its digital edge; the lines stay sharp top to bottom.
- **Short persistence.** P22 phosphors decay well within a frame at 60 Hz, so there is no
  ghosting effect.
- **Focus softens toward the corners.** One focus voltage can't keep the spot small across a
  flat-ish face, so the edges blur a little (`edge_focus`); the centre stays pixel-sharp.
- **Ghosting.** A long or cheap VGA cable reflects the signal, so a faint copy of each edge lands a
  few pixels to its right (`ghosting`, `ghost_offset`). `noise` is faint analog snow.
- **Glass reflection.** The room's light sits on the glass as a soft sheen high on the left
  (`reflection`); it shows on black and with the tube off.
- **Degauss.** A coil around the tube demagnetises the mask at power-on and at the press of the
  button, with a loud hum; the picture jumps and its colours swim, and the game exaggerates it
  with a moment of black.

## Rules the shaders keep

- **The mask lives on the screen's pixels,** so it never moires, at any scale. It fades out below
  2x, during the zoom.
- **The scanlines follow the scale.** At a whole 2x they sit on the glass: curved lines sampled
  at 2 screen pixels per line beat into moire bands. From 2.5x (a Retina laptop shows about 3.5x)
  they follow the picture's rows with a smooth profile (`picture_lines`). In between they fade out.
- **Sharp bilinear sampling.** At `softness` 0 and 2x the picture is pixel-exact; where the curve
  stretches it, only the pixel edges blend. The texture unit does the blend in one read, so the
  `Screen` node's `texture_filter` must stay Linear: the Compatibility renderer takes a sampler's
  filter from the node, not from the uniform's hint. Under the cursor the shader blends the four
  texels itself, because it draws the cursor into each texel.
- **The glass around the picture is drawn like the world.** Outside the lit picture, the close-up
  draws the glass at the centre of each world-buffer pixel (`world_pixel`), with `psx_post`'s
  dither and colour cut (`psx.gdshaderinc`), so its rounded corners step like the 3D bezel beside
  them. Past the tube's face it is transparent. The 3D screen cuts its corners out there too, so
  the monitor's recess shows, as through a bezel's rounded opening; the two looks keep the same
  `corner_radius` so their faces meet.
- **The mouse follows the curve.** `CrtScreen.bend()` is the GDScript twin of `crt_bend()`; change
  both together. Both read the same uniforms, so a look can't make them disagree.
- **The buffer is not in a SubViewportContainer.** Godot works out the hover inside a container's
  SubViewport from the container's straight transform, so hover and clicks would disagree under
  the curve. `CrtScreen` pushes the bent events into a free-standing SubViewport, which takes its
  hover from them.
- **Every pointer goes through `CrtScreen.push_mouse()`.** It takes events in buffer pixels and
  moves the drawn cursor with them. The bent mouse uses it, and so does the touch trackpad
  (`ui/touch/trackpad.gd`), which moves the cursor relatively; while the trackpad shows,
  `takes_touch` is false and the glass ignores fingers.
- **The shader draws the cursor.** The system cursor hides over the screen; `crt_texel()` draws the
  desktop's cursor into the picture, so it bends, glows, and stays on the screen where the player
  left it. A cursor node in the buffer would sit under Win95's popup menus, which Godot draws on
  a canvas layer above every CanvasLayer.
- **The shader keeps the node's modulate.** The Screen View fades by `modulate`; a shader that
  writes its own alpha would pop the overlay off at the end of the zoom.
- **Functions don't take `TEXTURE`.** A headless compile, as in CI's export, rejects it; the
  shaders read the buffer through their `screen_texture` uniform.
- **The glow is rendered once per buffer pixel.** `crt_glow.gdshader` averages 12 texels of a disc
  around each of the buffer's 640 x 480 pixels into a viewport that `CrtScreen` makes; the look
  reads it with one filtered read. A glow worked out for every window pixel cost four times as many
  reads in 1080p and twelve times on a Retina screen. The glow viewport renders after the buffer in
  the same frame, because it enters the tree after it at the same depth, so the cursor's glow
  never trails. It takes `glow_radius` from the look when the screen starts.
- **Cost:** one pass at the Screen View's size, one texel read per sample (three with
  convergence), one for the glow and one for the ghost; plus the glow's pass, 12 reads per buffer
  pixel. On an M1 in 1080p, the look takes about 1.2 ms of GPU per frame (docs/performance.md).

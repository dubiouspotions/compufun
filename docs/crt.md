# The CRT look

The shop's monitors look like mid-90s office VGA monitors, in their close-ups and in the 3D room: the
bench screen (the Screen View) and the work computer (CompuFunDB).

| Part | What it does |
| --- | --- |
| `shaders/crt.gdshader` | The CRT look of a close-up: curve, scanlines, mask, glow, convergence, colour. |
| `shaders/crt_world.gdshader` | A 3D monitor's screen: the same curve and light, without the mask and scanlines. |
| `shaders/crt.gdshaderinc` | What both share: the curve (`crt_bend`), the tube's face, the tube's state and the software cursor. |
| `shaders/crt_looks/` | The looks, as ShaderMaterials. `subtle_vga` is the Screen View's; `world_monitor` is the 3D screen's. |
| `ui/crt_screen.gd` | A close-up's screen: shows the buffer through the look, bends the mouse, sets the cursor. |
| `ui/crt_tube.gd` | One monitor's tube: power, signal lock, degauss, magnetised mask, and their sounds. |

To tune a look, open its `.tres` and drag the sliders. To try another, drop it on the Screen View's
`Screen` Material. The Screen View starts its zoom with the 3D screen's curve (`far_look`) and
blends to its own as the camera arrives, so the screen bends more from a distance.

## The tube's state

Each monitor has its own `CrtTube`, a child of its `ScreenView`. It animates the `crt_*` uniforms of
`crt.gdshaderinc` (`crt_power`, `crt_warmup`, `crt_degauss`, `crt_sync`, `crt_magnetization`,
`crt_cursor`) on that monitor's two looks: the close-up's (`CrtScreen` adds it) and the 3D screen's
(`main.gd` adds it with `ScreenView.add_look()`). So the close-up and the 3D screen show one tube,
and the bench's power cuts and lost signals leave the work computer alone. They are not global
uniforms for that reason. `ScreenView` calls `reconcile()` on every `Game.changed`: the tube is on
while its monitor is switched on (`ScreenView.switched_on`: on at the start, flipped by the bench
monitor's power button), and has a signal while its content's `has_picture()` says so (the bench: a
running computer is connected; CompuFunDB: always):

- **The game starts:** the tube is already on and warm, silently.
- **Power button, on:** a switch clunk, static, a degauss, and a dim, oversized picture that
  warms up over 3 seconds.
- **Power button, off:** the picture collapses to a white-hot line, then a dot that fades.
- **A running computer connects:** a relay click, black while the monitor finds the signal, then
  the picture rolls and locks.
- **The signal goes** (cable off, computer off): the picture tears and rolls away, a relay click,
  then the monitor's NO SIGNAL box.
- **Magnetised mask:** while the screen shows a computer, blotches of wrong colour build up at
  `magnetize_per_second` times the day's warp, so Cambion magnetises the screen as the week goes
  on. The Degauss button under the bench screen (`Bench.degauss_pressed`) clears them.

`tools/make_crt_sounds.py` synthesizes the sounds into `sounds/crt_*.wav`.

## What a VGA monitor looked like, and why

- **Faint scanlines.** 640 x 480 at 60 Hz scans 480 lines at 31.5 kHz; only 320 x 200 is
  double-scanned. On a 14-15" tube the lines are about 0.43 mm apart, and the beam spot is about
  as wide, so the gap between lines barely shows. Bright pixels widen the beam and close it
  (`beam_bloom`). Heavy scanlines are a TV or arcade look (15 kHz, 240 lines).
- **A fine mask.** A 0.28 mm shadow mask puts about 1.4 phosphor triads under each pixel, finer
  than our 2 x 2 screen pixels per VGA pixel can draw. The mask is a magenta/green pattern one
  VGA pixel wide, which lines up with the screen pixels at 2x and 4x. A 14-15" Trinitron has
  stripes instead and one faint horizontal damper wire two thirds of the way down.
- **9300 K white.** Monitors shipped with a bluish white (`white_point`).
- **Gentle curvature** with rounded tube corners; a Trinitron curves only from left to right.
- **Convergence** error grows toward the corners (0.3-0.4 mm in period specs).
- **Short persistence.** P22 phosphors decay well within a frame at 60 Hz, so there is no
  ghosting effect.
- **Degauss.** A coil around the tube demagnetises the mask at power-on and at the press of the
  button, with a loud hum; the picture shakes and its colours swim for a moment.

## Rules the shaders keep

- **Patterns live on the glass, the picture bends.** The mask and the scanlines follow the screen
  pixels, not the curved picture: curved lines sampled at 2 screen pixels per line beat into
  moire bands.
- **Patterns only at whole scales from 2x.** Elsewhere (during the zoom, in a smaller window)
  they fade out; `fine` in the shader decides.
- **Sharp bilinear sampling.** At 2x the picture is pixel-exact; where the curve stretches it,
  only the pixel edges blend, so text stays crisp.
- **The mouse follows the curve.** `CrtScreen.bend()` is the GDScript twin of `crt_bend()`; change
  both together. Both read the same uniforms, so a look can't make them disagree.
- **The buffer is not in a SubViewportContainer.** Godot works out the hover inside a container's
  SubViewport from the container's straight transform, so hover and clicks would disagree under
  the curve. `CrtScreen` pushes the bent events into a free-standing SubViewport, which takes its
  hover from them.
- **The shader draws the cursor.** The system cursor hides over the screen; `crt_texel()` draws the
  desktop's cursor into the picture, so it bends, glows, and stays on the screen where the player
  left it. A cursor node in the buffer would sit under Win95's popup menus, which Godot draws on
  a canvas layer above every CanvasLayer.
- **The shader keeps the node's modulate.** The Screen View fades by `modulate`; a shader that
  writes its own alpha would pop the overlay off at the end of the zoom.
- **Functions don't take `TEXTURE`.** A headless compile, as in CI's export, rejects it; the
  shaders read the buffer through their `screen_texture` uniform.
- **Cost:** one pass at the Screen View's size, 4 texel fetches per sample (12 with convergence)
  plus 12 for the glow.

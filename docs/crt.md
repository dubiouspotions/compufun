# The CRT look

The Screen View shows the screen buffer through `shaders/crt.gdshader`, the look of a mid-90s
office VGA monitor. `ui/crt_screen.gd` (the Screen View's `ScreenContainer`) applies it and maps
the mouse through the same curve. The looks are ShaderMaterials in `shaders/crt_looks/`; to tune
one, open its `.tres` and drag the sliders. To try another, drop it on `ScreenContainer`'s
Material.

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
- **Power.** Auto-degauss wobbles the picture and swims its colours for about a second at
  power-on; the tube warms up over a few seconds. At power-off, the picture collapses to a line
  and a dot. `CrtScreen.power_on()`, `power_off()` and `degauss()` play these.

## Rules the shader keeps

- **Patterns live on the glass, the picture bends.** The mask and the scanlines follow the screen
  pixels, not the curved picture: curved lines sampled at 2 screen pixels per line beat into
  moire bands.
- **Patterns only at whole scales from 2x.** Elsewhere (during the zoom, in a smaller window)
  they fade out; `fine` in the shader decides.
- **Sharp bilinear sampling.** At 2x the picture is pixel-exact; where the curve stretches it,
  only the pixel edges blend, so text stays crisp.
- **The mouse follows the curve.** `CrtScreen.warp()` is the GDScript twin of `warp()` in the
  shader; change both together. Both read the same uniforms, so a look can't make them disagree.
- **Cost:** one pass at the Screen View's size, 4 texel fetches per sample (12 with convergence)
  plus 12 for the glow.

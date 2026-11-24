# Trailers

The trailers are three cuts of one TV commercial for CompuFun, as if from 1996. The game plays each
cut in the real shop, and Godot's Movie Maker records it. The cuts are in `Godot/dev/trailer/`, which
no export contains.

| Cut | Length | What it is |
| --- | --- | --- |
| `trailer` | 38 s | Cheerful: loud title cards, the latest parts, a repair montage with loud sound effects, the fix on Windows 95, customers before and after, a "Now hiring" card, the CompuFun intro with one glitch. Music: "Sigla 2". |
| `trailer_win95` | 39 s | The cheerful cut with more Windows 95: the desktop crashes first, and the job offer is a Win95 question on the bench screen. |
| `trailer_bleak` | 70 s | Deadpan and slow, in the game's own look: dusk in the rain, a tired narrator, plain subtitles, no music. It ends on the job offer, taped to the counter, and the CompuFun intro, slowed down. |

## Make a video

```sh
tools/make_trailer.sh trailer_bleak ~/Movies/compufun_bleak.mp4
```

The script records the cut through `tools/run.sh`, then adds tape noise, colour bleed and the sound of
a small TV speaker. A cut records in about its own length, and the MP4 takes 20 s more.

- **Close the Godot editor first.** `tools/run.sh` refuses while the editor has the project open.
- **Set `GODOT` when the newest Godot is not last by name** in `/Applications`: `tools/run.sh` takes
  the last `Godot*.app`. For example: `GODOT=/Applications/Godot-4.7.2.app/Contents/MacOS/Godot`.
- **Keep the game window uncovered** until it closes. macOS draws no frames for a covered window, and
  Movie Maker then records none.
- **Build the live voice first** (`tools/build-voice.sh`). Without it, the narrator is silent and the
  trailer reports an error for each line.
- ffmpeg must be installed (`brew install ffmpeg`).

Keep the MP4s out of git: each is 45 to 85 MB.

## Change a cut

- **Shots:** each cut lists its shots in `_shots()`. `trailer.gd` holds the cheerful cut and the
  shared parts: the TV look, the narrator, the cards and the shop moves. The other cuts extend it and
  set their narrator, colour and music speed in `_init()`.
- **The shop:** a shot sets the shop with `Game.restore()` and plays the game's own moves, such as
  `Game.turn_screw()`. A restore is a jump, so it plays no change sounds; a move plays them.
- **The music** plays slower than recorded (`music_speed`), so that it ends with the star wipe. When
  the shots change length, the recording warns with the right speed for that cut.
- **The narrator** says "Compu fun", not "CompuFun": the voice's dictionary has "compu" and guesses
  at words that it lacks.
- **Windows 95's own sounds stay silent:** they are Microsoft's. The desktop still shows.
- **A boot skip** can't cut the monitor's warm-up, so the trailer gives the bench computer a short
  warm-up of its own.

The README credits the music ("Sigla 2" by sandroperrotta, Pixabay Content License).

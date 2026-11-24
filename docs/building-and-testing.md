# Building and testing

Run everything from `Godot/`. `$GODOT` below is the Godot 4.7.2 editor binary on your machine,
for example `"/Applications/Godot 4.7.app/Contents/MacOS/Godot"` on a Mac.

## Setup

Install [Git LFS](https://git-lfs.com) and run `git lfs install` before cloning. Without it,
binary assets check out as small text pointer files and Godot fails to import them.

Set up a new machine with [working-together.md](working-together.md).

## Check a change

```sh
"$GODOT" --headless --import
```

Imports new assets. Any `ERROR` or `SCRIPT ERROR` line that your change introduced must be gone
before you commit. It does **not** report every parse error: a script with a `match` inside a
lambda, or a signal that shadows a built-in one, imported clean and only failed when a scene loaded
it. Parse-check the scripts you changed:

```sh
"$GODOT" --headless --check-only --script res://path/to/changed.gd
```

A script that uses an autoload, such as `Game`, always fails this check with "Identifier not
found: Game": the check does not load autoloads. That line is not your error; run the scene.

To run the game straight into a state, give it a JSON file in the format of `Game.snapshot()` (an
F2 preset, or what F2's Copy state copies); a debug run restores it once the main scene is up.
Start `main.tscn` itself, past the loading screen, so you land in the state at once:

```sh
echo '{"day": 1, "phase": "OPEN", "db_day": 1, "view": "CompuFunDB"}' > /tmp/db.json
"$GODOT" --path Godot res://main.tscn -- --restore /tmp/db.json   # CompuFunDB, started up for the day
```

`tools/run.sh` passes its arguments on to Godot, so the same works without the editor, and the
Story Lab can open at start too, on its own or on one errand (the file whose name starts so):

```sh
tools/run.sh res://main.tscn                          # past the logo and the loading screen
tools/run.sh res://main.tscn -- --story-lab           # with the Story Lab open
tools/run.sh res://main.tscn -- --errand 0101         # with errand 0101 open in story mode
```

After a pull, a class that a teammate added (`class_name`) can be missing from the class cache, so
every script that uses it fails with "Identifier ... not declared", and `--import` does not fix
it. An editor scan does: open the project in the editor, or run
`"$GODOT" --headless --editor --quit`.

Then run the scene you changed, in the editor or without it: `tools/run.sh [res://scene.tscn]`
imports and plays the main scene, or the scene you name. It refuses while the editor has the
project open (see the gotcha about two Godot processes).

A headless `--script` that extends `SceneTree` can drive a scene for a quick test. Add the scene in
`_initialize()` and `await process_frame` before you touch it: until then its `_ready()` has not run.

To show a visual change, film it. Such a script, run with Movie Maker, sets up the moment (for
example `Game.restore({"day": 5, "arrivals": 0, "phase": "OPEN"})`, with no more arrivals than the
day has errands, then `close_shop()`), waits on `create_timer` and quits. It needs a real window, so park it off-screen:

```sh
"$GODOT" --path . --position 10000,10000 --resolution 1920x1080 \
  --write-movie /tmp/clip.avi --fixed-fps 30 -s res://tests/_film.gd
ffmpeg -i /tmp/clip.avi -vf scale=1280:-2 -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac clip.mp4
```

Movie Maker renders every frame at the fixed rate, however slowly, so the clip never stutters.
Delete the script afterwards: `run.gd` runs only `test_*.gd`, but it should not be committed.

**The trailers** are recorded the same way, by one command per cut: see [trailers.md](trailers.md).

## Tests

`Godot/tests/` holds headless tests that play the game through the `Game` API and check its state.
After an import, run the tests that cover your change: those whose file name or source mentions one
of the words, such as the scripts or scenes you changed. CI runs them all on every push to `main`
and every pull request (see CI below).

```sh
"$GODOT" --headless -s res://tests/run.gd -- crt_tube bench   # the tests that mention either
"$GODOT" --headless -s res://tests/run.gd                     # all of them, about 10 s
"$GODOT" --headless --fixed-fps 60 -s res://tests/test_day.gd # one
```

`run.gd` runs each `tests/test_*.gd` in its own Godot process, so that each test starts from a fresh
`Game`, as many at a time as the machine has cores. It prints each failed check with its file, line,
expected and actual value, and exits 1 when a test fails.

**Tests never depend on the wall clock.** A test runs at `--fixed-fps 60`, so every frame moves time
by exactly 1/60 s however busy the machine is, and a test without it fails at once. Wait with
`await create_timer(seconds).timeout` or frames, and measure time with `now()`; never with
`Time.get_ticks_msec()`, and no checks of how long something took. To test something that waits, in
game code, inject the wait (a callable or a `tick`) rather than sleeping in the test.

To add one, create `tests/test_<name>.gd`:

```gdscript
extends "res://tests/test.gd"


func run() -> void:
	game.start_day(game.day_of(1))
	check("the first customer walks in", game.arrivals, 1)
```

`game` is the `Game` autoload; reach it through that variable, because a script that names `Game`
doesn't compile under `-s`. Its `_process` is off: `tick(seconds)` moves time. A test fails when a
`check` fails, when no check ran, or on a script error. Expected `ERROR` lines from `push_error` don't
fail it. `run()` may `await`, for example `await process_frame` after adding a scene to `root`.

Every Godot process of the project shares one user folder (`user://`), across all checkouts and
every test that runs at the same time. A test that writes files writes them in `user_dir()`, a
folder of its own process that `test.gd` removes when the test ends; a fixed folder in `user://`
lets two runs read and wipe each other's files.

## Export

```sh
./export.sh --godotapp "/Applications/Godot 4.7.app" all   # or: web mac windows linux
```

Builds land in `Godot/build/<platform>/` (ignored by git). Exporting needs the 4.7.2 export
templates (Editor > Manage Export Templates).

### Web export on a dev Mac

1. Install the templates once, without the editor: download
   `Godot_v4.7.2-stable_export_templates.tpz` and `SHA512-SUMS.txt` from the godotengine/godot
   release `4.7.2-stable`, check the sum, unzip, and move the zip's `templates/` folder to
   `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (the name is the content
   of `templates/version.txt`).

   ```sh
   gh release download 4.7.2-stable -R godotengine/godot -p 'Godot_v4.7.2-stable_export_templates.tpz' -p SHA512-SUMS.txt
   grep 'v4.7.2-stable_export_templates.tpz' SHA512-SUMS.txt | shasum -a 512 -c
   unzip -q Godot_v4.7.2-stable_export_templates.tpz
   mv templates "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
   ```

2. Without the live voice's wasm the web build plays the WAVs. To test the live voice without
   Rust, take the wasm that CI built: `gh run download <godot-ci run id> -n voice-ubuntu-latest`,
   then copy its `chimera_voice.wasm` to `Godot/voices/live/`.
3. Export from `Godot/`, into a folder outside the repo, as CI does:

   ```sh
   bash ../tools/write-build-info.sh
   "$GODOT" --headless --export-release "Web" /path/to/web/index.html
   ```

   Check the log for `ERROR` and that `index.wasm` and `index.pck` are there.
4. Serve the folder with `python3 -m http.server 8060 --directory /path/to/web` and open
   `http://127.0.0.1:8060/index.html`. The Web preset is single-threaded, so it needs no
   cross-origin isolation headers. Read the browser's console for errors from `live_voice.js`.

## The story

`dev/story.gd` runs the story check (`story/story_check.gd`) on the week from the story files and
prints the missing links: flags that nothing sets or checks, choices without lines, errands without
a drop-off, errand codes that can come with nobody, days without an errand in each daypart or with
one out of order, moods without a portrait or a voice, problems
without repair mechanics, problem files that no errand names. Fix a missing link in the story files, then run it again until it lists
none. `outline` prints errand files in their written layout.

```sh
"$GODOT" --headless -s res://dev/story.gd                          # missing links
"$GODOT" --headless -s res://dev/story.gd -- outline [code]        # the errand files, such as 0102
```

The story check reads the files; the **week bot** (`tests/test_week_bot.gd`) plays them. It runs
`main.tscn` from day 1 to the ending's credits in real game time, with a player's clicks and keys
where the game has them: it clicks the open sign, reads each customer's lines and clicks their
choices (at random, from a seed), opens CompuFunDB, searches for a symptom, marks the rest, prints the FIX page with F and
takes it from the printer, repairs the computer (hardware with Game's part calls, software through
the computer's own `ComputerState`: the volume, the eject button, Disk Defragmenter until the next afternoon, a
property sheet, a rename, Display Properties, End Task and a delete), waits for the real boot to test it, clicks the phone
and closes the shop at the sign. Each morning it checks that `Game.restore(Game.snapshot())` keeps
the state.

It fails on an error, when nothing changes for two minutes of game time (a softlock: a customer who
never comes, a test that never passes, a night that never ends, a click that lands nowhere), and when
the week doesn't reach its credits. It names the day, the errand code, its step and the snapshot. The
missing links that the story check lists, and what they cause, it only reports, so CI stays green
while the writers fill them: run it alone to read what became of every errand, such as "0601: never
came: Young entrepreneur's computer from 0401 is still in the shop". CI runs seed 1; other seeds take
other branches, about 25 s each.

**When you add to the game, teach the bot.** It fails when Game gets a public method, an enum value
(phase, visit, visitor state, daypart, `Errand.Brings`, `Conversation.Trigger`, `Problem.Location`)
or a `SoftwareCheck` type that it doesn't list in its `KNOWN_*` constants. Make it do what a player
does with the new thing, or decide that a week doesn't need it, then add the name.

```sh
"$GODOT" --headless --fixed-fps 60 -s res://tests/test_week_bot.gd -- 1 2 3   # the seeds
```

## Voices

**Layers.** A line's voice is three layers, each over the one below (`Voices.layer`): the
`VoicePerson` of the customer's person (`voices/persons/`, one per person), the `VoiceMood` of the line's voice mood (`voices/moods/`)
and a `VoiceEffect` (`voices/effects/`) of the line or its conversation. Make all three in the
Voice Lab (Dev menu, F3 or Cmd+3); a story file gives an effect to a conversation or a line. A
`VoicePlayer` can put one more effect's base settings on top of every line it says (`through`): the
phone call's player says each line through `voices/effects/telephone.tres`, a 500 to 2600 Hz
band-pass with saturation, so a glitch on the phone plays first and then goes down the line. The
telephone leaves `bits` and `hold` alone, so that a glitch keeps its own crush. Under the voices the
line hisses (`sounds/line_hiss.ogg`, `tools/make_line_hiss.sh`), on every path, WAVs included. An effect has a
base, an alternate and a curve over the line that says how much of the alternate plays at each
moment. The live voice blends the two as it speaks, with the same Rust code on desktop and in the browser
(`native/chimera_voice/src/voice_type.rs` and `fx.rs`): speed, pitch, melody, body, intonation and
tune (how far the pitch snaps to notes) take the curve's average once per line; the voice source and the effects follow the curve. A
pre-rendered WAV has only the person's body and the mood's speed, pitch and swing, so the rest of
the layers plays only where the live voice is built.

**Live.** `VoicePlayer` speaks each line as it plays, the parts of a line whose mood changes
partway one after another without a pause, each in its own mood: in the web build Chimera runs as wasm in a
Web Worker (`voices/live/live_voice.js`), on desktop as the `ChimeraVoice` extension
(`native/chimera_voice/`). Without them, as on a machine that has not built them, it plays the
line's WAV, rendered as below. The Voice Lab, in the Dev menu (F3 or Cmd+3), puts every Chimera
setting on a slider, with glitch effects, to try voices out. Dev tools live in `Godot/dev/`, which
every export preset leaves out: a shipped game has none. Build them once with Rust installed (CI builds them for every
platform on each push):

```sh
tools/build-voice.sh
```

On Windows the script builds with Rust's GNU toolchain, which brings its own MinGW: no Visual
Studio needed. The launchers don't build: `Play HumanError.bat` and `Play HumanError.app` download
the Windows or macOS library from the
[`live-voice` release](https://github.com/dubiouspotions/compufun/releases/tag/live-voice)
(`live-voice-windows.zip`, `live-voice-macos.zip`), and again whenever `native/chimera_voice` has
changed since that was built: each zip's `voice-source.txt` holds the tree hash it was built from
(`git rev-parse HEAD:native/chimera_voice`). CI's **Live Voice Release** job replaces both zips
after a push to `main` that changes `native/chimera_voice` or `tools/build-voice.sh`, or when the
release holds another hash than `main`.

**Rendered.** Each customer line plays a WAV in `Godot/voices/`, which [Chimera](https://github.com/jamesondh/chimera-vocal-synth)
renders from the text, in the body of the customer's `voice` person and the line's voice mood
(`Godot/voices/moods/<mood>.tres`: speed, pitch and pitch swing). A line whose mood changes
partway has one WAV per line part (`DialogueLine.parts()`), named by the same hash of its words, so
an edit of one part renders only that part again; the player plays them one after another. A line
without its file is silent, and a debug run warns about it. Conversations that every customer shares, such as the thanks at a pickup, live in
`Godot/customers/conversations/`; they and everyone's call-outs (`story/callouts/everyone.callouts`)
are rendered in each body that a customer's person has.

1. Once: install [Rust](https://rustup.rs), then clone Chimera outside this repo, at the commit
   that the patch fits, and build its CLI with our mood patch. The binary finds Chimera's data
   through the checkout, so keep the checkout where it is.

   ```sh
   git clone https://github.com/jamesondh/chimera-vocal-synth.git && cd chimera-vocal-synth
   git checkout caf270a && git apply /path/to/humanerror/tools/chimera-moods.patch
   cargo build --release -p chimera-cli
   ```

   If the build fails with "error loading known_hosts", your git sends GitHub through SSH. Run
   the build with `CARGO_NET_GIT_FETCH_WITH_CLI=true` in front.
2. In the editor: set Editor Settings > Humanerror > Voices > Chimera Path to
   `chimera-vocal-synth/target/release/chimera` (`chimera.exe` on Windows). In the Story Lab,
   press Play on a line to hear it.
3. Or render every missing file at once, then import:

   ```sh
   CHIMERA=/path/to/chimera "$GODOT" --headless --script res://voices/render_voices.gd
   "$GODOT" --headless --import
   ```

4. Commit the new `.wav` and `.wav.import` files. `render_voices.gd` lists the files that no
   line uses any more; remove those with `git rm`.

## CI

`.github/workflows/godot.yml` runs on every push to `main`, and as a release when started by hand
(see [Releasing](#releasing)):

- **Version** reads the version from the `vX.Y.Z` tags. A release bumps it and tags the commit.

- **Live Voice** builds `native/chimera_voice` with `tools/build-voice.sh`: macOS on a Mac runner, the wasm, Linux and Windows on Ubuntu. Build downloads them before its import.
- **Live Voice Release** (on `main` only) zips the Windows and macOS libraries for the launchers and uploads them to the `live-voice` release with the workflow's token, when the push changed the live voice or the release is stale ("Voices" above).
- **Build** stamps the version into the game, imports, exports all four presets as
  `CompuFun-<version>.zip` and uploads them as run artifacts. A failed build posts to Discord, and so
  do `ERROR` lines in the export log.
- **Sign and Notarize macOS** runs in every release, on a Mac runner. It re-signs the macOS
  export with Nevyn's Developer ID (team `M4Q2TE45WT`): the libraries in `Contents/Frameworks`
  first, then the app with the entitlements of Godot's own signature. Apple then notarizes it, and
  the ticket is stapled. It needs the secrets `MACOS_CERT_P12_BASE64` and `MACOS_CERT_PASSWORD` (the
  certificate as a base64 .p12) and `MACOS_NOTARY_KEY_P8_BASE64`, `MACOS_NOTARY_KEY_ID` and
  `MACOS_NOTARY_ISSUER_ID` (an App Store Connect API key). Without it, macOS refuses the
  downloaded game.
- **Deploy** uploads the builds to itch.io with butler, with the notarized macOS build, and
  `--userversion` so that the page shows the version under each download. It needs the
  `ITCHIO_*` secrets.
- **GitHub Release** creates the tag's release on GitHub, with the commit subjects since the
  previous tag as its notes.

A newer push cancels a running export. The tests run in their own workflow,
`.github/workflows/tests.yml`, on every push to `main` and every pull request: it imports, runs
`tests/run.gd`, and passes only on its "N of N tests passed" line. Newer pushes don't cancel it, so
every commit gets a test verdict.

`.github/workflows/week-page.yml` rebuilds the wiki page "The Week" on every push to `main` that
touches the story files, the problems or the customers: it imports, runs
`dev/story.gd -- week-page`, and pushes the page to the wiki with the workflow's own token. A week
whose story files don't load fails the job and leaves the page as it was.

Every push to `main` also posts its commits to Discord (`.discord-main.yml`), and issue changes
post there too (`.discord-issues.yml`). Both post into the thread whose ID is in the repository
variable `DISCORD_THREAD_ID`, so they don't flood the channel; with the variable empty they post
in the channel. Build failures always post in the channel.

## Releasing

The version lives only in the `vX.Y.Z` git tags; no file in the repo holds it. A build between two
releases is called after the last one and the commits since, like `0.8.1-5-gcd55d5b`. The game shows
it in its window title (`Godot/build_info.gd`), and CI also writes its `X.Y.Z` into the macOS and
Windows file metadata. `tools/write-build-info.sh` writes both.

To release, run Actions > godot-ci export > Run workflow on `main` and pick the part to bump, or:

```sh
gh workflow run godot.yml -R dubiouspotions/compufun -f bump=patch   # or minor, major
```

The run tags `main` with the next version, then builds, signs, deploys and writes the GitHub
release. If it fails, use "Re-run failed jobs": a re-run keeps the version. A release that reached
itch.io is never redone: fix it in the next patch release. Running a release on a commit that
already has a tag deploys that version again without a bump.

## Ways the build lies

* *`export.sh` exits 0 when an export fails.* It doesn't check Godot's exit code. Read its
  output for `ERROR`, or check that the build file exists.
* *Every CI export logs `Unable to load fontconfig`.* The CI image has no system fonts. The
  Discord error report filters this line out; ignore it in the log.

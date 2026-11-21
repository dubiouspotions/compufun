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

Then run the scene you changed, in the editor or without it: `tools/run.sh [res://scene.tscn]`
imports and plays the main scene, or the scene you name. It refuses while the editor has the
project open (see the gotcha about two Godot processes).

A headless `--script` that extends `SceneTree` can drive a scene for a quick test. Add the scene in
`_initialize()` and `await process_frame` before you touch it: until then its `_ready()` has not run.

There is no test framework yet.

## Export

```sh
./export.sh --godotapp "/Applications/Godot 4.7.app" all   # or: web mac windows linux
```

Builds land in `Godot/build/<platform>/` (ignored by git). Exporting needs the 4.7.2 export
templates (Editor > Manage Export Templates).

## Voices

Each customer line plays a WAV in `Godot/voices/`, which [Chimera](https://github.com/jamesondh/chimera-vocal-synth)
renders from the text, in the customer's `voice` and the mood of the line's pose
(`Godot/voices/moods/<pose>.tres`: speed, pitch and pitch swing). A line without its file is
silent, and a debug run warns about it.

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
   `chimera-vocal-synth/target/release/chimera` (`chimera.exe` on Windows). In the Dialogue tab,
   pick each customer's voice, and press Play on a line to hear it. Play renders a missing file.
3. Or render every missing file at once, then import:

   ```sh
   CHIMERA=/path/to/chimera "$GODOT" --headless --script res://voices/render_voices.gd
   "$GODOT" --headless --import
   ```

4. Commit the new `.wav` and `.wav.import` files. `render_voices.gd` lists the files that no
   line uses any more; remove those with `git rm`.

## CI

`.github/workflows/godot.yml` runs on every push to `main` and `deploy`:

- **Build** exports all four presets and uploads them as run artifacts. A failed build posts to
  Discord, and so do `ERROR` lines in the export log.
- **Deploy** uploads the builds to itch.io with butler. It runs on the `deploy` branch, or when
  started by hand (Actions > godot-ci export > Run workflow). It needs the `ITCHIO_*` secrets.

Every push to `main` also posts its commits to Discord (`.discord-main.yml`), and issue changes
post there too (`.discord-issues.yml`). Both post into the thread whose ID is in the repository
variable `DISCORD_THREAD_ID`, so they don't flood the channel; with the variable empty they post
in the channel. Build failures always post in the channel.

## Ways the build lies

* *`export.sh` exits 0 when an export fails.* It doesn't check Godot's exit code. Read its
  output for `ERROR`, or check that the build file exists.
* *Every CI export logs `Unable to load fontconfig`.* The CI image has no system fonts. The
  Discord error report filters this line out; ignore it in the log.

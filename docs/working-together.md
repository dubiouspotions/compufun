# Working together

Five people work in this repo, some on Windows and some on macOS. These rules keep the files the
same on every machine and keep merges small.

## Set up a machine

1. Install Godot **4.7.2 stable, the standard build** (not .NET). Everyone uses this exact
   version. Another version rewrites `project.godot` and every scene that it saves.
2. Install Git and [Git LFS](https://git-lfs.com). Git for Windows includes LFS. Run
   `git lfs install` once.
3. In your clone, run once:

   ```sh
   git config pull.rebase true
   git config rebase.autoStash true
   git config core.longpaths true   # Windows only: paths longer than 260 characters
   ```

4. On Windows, run `export.sh` from Git Bash, or export from the editor (Project > Export).
5. For F9 reports and the Story Lab's Send to make issues, put the team's issues token in
   `issues-token.txt` in the repo root (one line; git ignores it), or in the environment variable
   `HUMANERROR_ISSUES_TOKEN`. Ask a teammate for it. Without it, reports stay in `feedback/`.

   The token is a fine-grained one owned by `dubiouspotions`, for this repository only, with
   **Contents: read and write** (the screenshots go to the branch `feedback`) and **Issues: read
   and write**. The board adds new issues itself. Contents write can push to any branch, so the
   token never goes into an export. On a phone or tablet, paste it into the debug menu's GitHub
   tab (F2), which keeps it on that device (docs/ios.md).

## Line endings

`.gitattributes` stores text as LF and checks it out as LF on every OS, whatever
`core.autocrlf` says. `.editorconfig` makes editors write LF. Don't change either per machine.

## File names

Inside `Godot/`, name files and folders in lowercase `snake_case`, with ASCII letters, digits and
`_` only: no spaces, no capitals, no å, ä or ö.

- Windows and macOS ignore case; CI (Linux) and the exported game don't.
  `load("res://Counter.png")` finds `counter.png` on your machine and fails in the build.
- macOS and Windows store `å` as different bytes, so git can see two different files.
- Rename a file in Godot's FileSystem dock, so Godot updates the scenes that use it.
  `git status` must then show a rename, not a delete and an add.

## Binary files

- Binary files go through LFS. A new binary type gets its line in `.gitattributes` before its
  first commit; a file committed before the rule stays in plain git history for good.
- Phone photos are HEIC. Godot can't import HEIC: export a PNG or JPG before you put a photo in
  `Godot/`. Keep the originals (HEIC, PSD) outside the repo.

## Keep merges simple

- **One thing, one file.** A customer is one `.tres`, a room is one `.tscn`, a program on the
  Windows 95 desktop is one `.tscn`. Two people who add two customers never touch the same file.
- **Big scenes are made of small scenes.** Put your part in its own scene and instance it.
- **Push a scene soon.** Pull before you edit a scene; commit and push when the change works.
  A scene edit that waits a day on one machine is where the conflict comes from.
- **Hot files:** `project.godot` (input map, autoloads, settings) and `Godot/main.tscn`. Pull just
  before you change them and push just after.
- **Commit what you meant to change.** The editor re-saves open scenes and adds `uid=` and
  `unique_id=` lines. Read `git diff` before you commit, and commit that editor churn on its own.
- **Commit the `.uid` file with each script and shader, and the `.import` file with each asset.**
  Without them, each machine makes its own UID and the references break.
- **A conflict in a `.tscn` or `.tres`:** fix it by hand only when it is a few lines that you
  understand. Otherwise keep one version whole (the one with the larger change), and make the
  other change again in the editor. In a rebase, `git checkout --ours <file>` takes `main` and
  `--theirs` takes your commit.

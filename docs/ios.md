# iOS

The game runs on iOS from the `iOS` export preset: the iPhone, the iPhone Duo (folded and unfolded)
and the iPad simulators show the shop, the customers, the dialogue and the Screen View. Nobody has
run it on a device yet, so its speed there is unknown. This page holds the build steps and what a
real port still needs.

## Build for the simulator

Godot's 4.7.2 iOS template ships an x86_64-only simulator library, although its folder says
`ios-arm64_x86_64-simulator`. An Apple Silicon Mac without Rosetta can't run it, so build the
arm64 simulator template from the matching Godot source (90 s on an M5 Max) and swap it in:

```sh
git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git
scons -C godot platform=ios target=template_debug ios_simulator=yes arch=arm64 -j16

cd Godot && ../tools/write-build-info.sh
godot --headless --export-debug iOS build/ios/CompuFun.ipa   # export_project_only: writes the Xcode project
cp <godot>/bin/libgodot.ios.template_debug.arm64.simulator.a \
   build/ios/CompuFun.xcframework/ios-arm64_x86_64-simulator/libgodot.a
xcodebuild -project build/ios/CompuFun.xcodeproj -scheme CompuFun -sdk iphonesimulator \
   -destination 'generic/platform=iOS Simulator' ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
```

Export into an empty folder: an export over an old one logs errors about the asset catalog.

- **The simulator can't judge speed.** Godot builds simulator templates without Metal or Vulkan
  (`platform/ios/detect.py`), and the simulator runs OpenGL ES in software on the CPU
  (`libGLProgrammability`). The game draws 1 to 5 frames a second there, and the first launch
  spends about 3 minutes compiling shaders. Measure on a device.
- **Godot's log goes to os_log**, not stdout: `xcrun simctl spawn <udid> log show --info --predicate
  'subsystem == "com.dubiouspotions.compufun"'`. Launch arguments work: `simctl launch <udid>
  com.dubiouspotions.compufun --print-fps`.
- **Taps and keys:** `axe` (Homebrew `cameroncooke/axe/axe`) taps, types, presses F2 and opens the
  Duo's hinge (`axe hinge set open`). Hold a tap for 0.5 s; at 1 frame a second a quick tap can
  fall between frames.

## What works

- The GL Compatibility renderer, the PSX world buffer, the CRT look, the photo reliefs and the
  dialogue render as on desktop. The log shows only warnings: RGBAFloat textures fall back to
  RGBAHalf, custom cursors are unsupported, and one `DisplayServer.mouse_get_position()` fails.
- **The voices:** without the `ChimeraVoice` extension, `voice_player.gd` plays the rendered WAVs.
  The preset leaves out `voices/live/`.
- **The layout:** the game letterboxes 16:9 on every screen. On the iPhone the side bars hide the
  Dynamic Island. Unfolding the Duo moves the game to the inner screen mid-conversation, with
  nothing lost.
- **Touch:** Godot turns a tap into a left click, so buttons, hotspots, the nav arrows, dragging
  parts and cables, and the Win95 drag and drop work. A hardware keyboard reaches F2.

## What a real port needs

| Gap | Size |
| --- | --- |
| Device run: speed, heat, first-launch shader compile; signing with team `M4Q2TE45WT` | 0.5 day |
| Right-click as a long press (`win95/mouse_input.gd`): context menus, Close Program. The Email Virus fix needs Close Program | 0.5 day |
| Hover: hotspot outlines show only under the mouse, which is how the player finds things. Pulse them on a tap that hits nothing, or always | 0.5 to 1 day |
| CompuFunDB scrolls only with the wheel or the keys: drag to scroll, or tappable arrows | 0.5 day |
| Small fixes: the double-click radius of 2 px (`mouse_input.gd`), the printout trash's `is_hovered()` (`carried_printout.gd:99`), Ctrl+Alt+Del on screen | 0.5 day |
| Typing in the Win95 desktop (renaming files for Noimages): check that the iOS keyboard shows for a LineEdit inside the screen buffer | 0.5 day, unverified |
| Phone Screen View: the Win95 desktop is too small to read or tap on a phone (below) | 2 to 4 days, design |
| CI job: export, archive, TestFlight upload | 1 day |

How big the Win95 desktop shows (the screen buffer at 2x in the 16:9 frame; Apple asks for 44 pt
touch targets and about 11 pt text):

| Device | Win95 12 px text | 32 px icon | Close button | Game text (28 px) |
| --- | --- | --- | --- | --- |
| iPhone 18 Pro | 9 pt | 24 pt | 12 pt | 10 pt |
| iPhone Duo, folded | 8.5 pt | 23 pt | 11 pt | 10 pt |
| iPhone Duo, unfolded | 12 pt | 32 pt | 16 pt | 14 pt |
| iPad Air 11" | 15 pt | 39 pt | 20 pt | 17 pt |

The iPad plays as designed; phones need a Screen View that zooms the desktop and pans, or the
desktop at 3x.

## The App Store

The game ships Microsoft's wallpapers, icons and sounds, the Windows 95 boot screen and the Apple
logo, none licensed to us (README credits). App Review rejects that. TestFlight's internal testing
(up to 100 people on the team, no review) works; external TestFlight and the App Store need those
assets replaced.

## The Story Lab and F9 on a device

- `dev/` is excluded from every export, and `main.gd` adds the Dev menu only to a debug build. An
  iOS debug export that includes `dev/` would carry it; F4 needs a hardware keyboard or a touch
  entry point.
- Drafts live in `user://`, which works. Git doesn't: `story_drafts.gd` and `github_issues.gd` run
  `git` through `OS.execute`, and iOS can't start processes. The start commit has to come from
  `build_info.txt`, and "changed on `main`" from the GitHub API.
- The Story Lab is a 1080p mouse tool: an iPad with a keyboard and a trackpad can use it, a phone
  can't.
- **Never put the issues token in an iOS build.** It can write to every branch of the repo, and
  anyone can unzip an IPA and read the `.pck`. With it they could push to `main`, which CI builds
  with the signing and itch.io secrets. Instead, either a small relay (a serverless function)
  holds the token and only makes `story`/`feedback` issues and writes to the `feedback` branch,
  for a per-writer passphrase (about 1 day); or each writer signs in with GitHub's device flow to
  a GitHub App that has only this repo's Issues and Contents, and the token stays in the Keychain
  (1 to 2 days).

# iOS

The game runs on iOS from the `iOS` export preset: the iPhone, the iPhone Duo (folded and unfolded)
and the iPad simulators show the shop, the customers, the dialogue and the Screen View, and an
iPhone Duo (A20 Pro) holds 60 frames a second. This page holds the build steps and what a real port
still needs.

## Build for a device

Export as below, then build with `-sdk iphoneos DEVELOPMENT_TEAM=M4Q2TE45WT` and install with
`xcrun devicectl device install app --device <udid> <app>`. The export has no entitlements, so the
team's wildcard development profile signs it. `codesign` needs the login keychain: an agent session
in launchd's Background session gets `errSecInternalComponent` and has to build from the GUI session.

On the A20 Pro the game draws 60 frames a second (16.7 ms) on OpenGL ES over Metal, with a few
seconds of dips while it loads and compiles its shaders. `--print-fps --log-file user://perf.log`
writes the frame rate to `Documents/perf.log`, which `devicectl device copy from --domain-type
appDataContainer` fetches.

## Xcode Cloud

`ios/` holds the Xcode project's text, so that Xcode Cloud finds the project and its scheme; the
export fills in the rest (`ios/.gitignore`). Before each build, `ios/ci_scripts/ci_post_clone.sh`
pulls the LFS files, downloads Godot and its iOS template, writes the build info, takes the version
from the tag and exports. The tag picks the build:

- **`v0.9.3`: the team's TestFlight.** A debug export of the `iOS` preset, version 0.9.3, with the
  debug strip, F2, F9 and `dev/` (the Dev menu, the Voice Lab, the Story Lab).
- **`appstore-v1.0.0`: the App Store.** A release export of the `iOS Release` preset, version 1.0.0.
  The preset leaves out `dev/`, `tests/` and the story bible, and a release build has no debug
  strip, F2, F9 or Skip (`OS.is_debug_build()`).

The two presets differ only in those files; `tests/test_ios_presets.gd` fails when they drift, so
change both together. Xcode Cloud sets the build number and signs. Re-export into `ios/` when the
preset changes, and commit what changed.

To set up the workflows (only Xcode's GUI can create them): open `ios/CompuFun.xcodeproj`,
Product > Xcode Cloud > Create Workflow, connect the dubiouspotions GitHub organisation, start on
tag changes matching `v*`, action Archive (iOS) with TestFlight (Internal Testing Only), and
post-action TestFlight Internal Testing to the group Dubious Potions. The App Store workflow is the
same, but starts on tags beginning with `appstore-v` and archives for TestFlight and App Store.

To cut an App Store build, tag the commit and push the tag:

```sh
git tag appstore-v1.0.0 && git push origin appstore-v1.0.0
```

The build lands in App Store Connect under version 1.0, next to any team build of the same version.
Submit the one from the App Store workflow: a team build carries the debug tools.

## Build for the simulator

Godot's 4.7.2 iOS template ships an x86_64-only simulator library, although its folder says
`ios-arm64_x86_64-simulator`. An Apple Silicon Mac without Rosetta can't run it, so build the
arm64 simulator template from the matching Godot source (90 s on an M5 Max) and swap it in:

```sh
git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git
scons -C godot platform=ios target=template_debug ios_simulator=yes arch=arm64 -j16

cd Godot && ../tools/write-build-info.sh
godot --headless --export-debug iOS ../ios/CompuFun.ipa   # export_project_only: fills in ios/
cp <godot>/bin/libgodot.ios.template_debug.arm64.simulator.a \
   ../ios/CompuFun.xcframework/ios-arm64_x86_64-simulator/libgodot.a
xcodebuild -project ../ios/CompuFun.xcodeproj -scheme CompuFun -sdk iphonesimulator \
   -destination 'generic/platform=iOS Simulator' ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
```

Export outside `Godot/`: Godot imports whatever lies inside the project, Xcode's output included.

For the App Store build, build the template with `target=template_release`, export with
`--export-release "iOS Release"` and copy `libgodot.ios.template_release.arm64.simulator.a`.

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
- **The layout:** the game fills the screen (see "Filling the screen" below). Unfolding the Duo
  moves the game to the inner screen mid-conversation, with nothing lost.
- **Touch:** Godot turns a tap into a left click, so buttons, hotspots, the nav arrows, dragging
  parts and cables, and the Win95 drag and drop work. A hardware keyboard or the debug strip
  reaches F2.
- **Swipes:** a finger's swipe across the world turns the view like a panorama (a finger that moves
  left turns right, as the right arrow key does), and a swipe down leaves a close-up. A mouse never
  swipes. `Shop` sees the swipe in the world buffer, after the UI took its drags and before physics
  picking; the thresholds are its `swipe_*` exports. A finger clicks a hotspot or the back strip
  when it lifts, within `tap_slop` of its touch (`ui/touch/tap_gate.gd`), so a swipe clicks nothing.
  The VGA plug still acts on the touch, so that a finger drags it; the part in the hand tells a tap
  from a drag itself. A swipe never starts while either is dragged.
- **Trackpad and keyboard** (`ui/touch/`): while the last input was a finger, an open Screen View
  or CompuFunDB shows a trackpad instead of taking fingers on the glass. One finger moves the
  cursor, a tap clicks (two taps double-click), a long press drags, two fingers tap a right click or
  drag to scroll. Its KEYS button shows a PC keyboard with sticky Ctrl, Alt and Shift
  (Ctrl+Alt+Del: Ctrl, Alt, Del), which sends real key events. Both panels move by their grip
  bars and keep their places in `user://touch_controls.cfg`.
- **The OS keyboard:** text fields inside the screen buffers never raise it (the touch keyboard types
  there). Elsewhere (F9's note, the Story Lab), `TouchControls` lifts the focused field's CanvasLayer
  above it, by the caret line in a TextEdit, and puts it back when the keyboard goes.

## Filling the screen

On iOS and Android the game fills the whole screen; desktop and web keep 16:9 with black bars.
`display/window/stretch/aspect.mobile="expand"` does it: the canvas never shrinks below the
1920 x 1080 design frame and grows in the screen's extra direction, to about 1920 x 1320 on the
folded Duo, 2345 x 1080 on a 2.17:1 iPhone and 1920 x 1333 on an iPad Air 11". Every view shows at
least its 16:9 picture:

- **The world buffer** grows with the canvas at the same 4 design pixels per world pixel, rounded
  up to whole world pixels (`main.gd`, `world_buffer_size`): 480 x 330, 587 x 270, 480 x 334. Main
  re-derives it whenever the window changes, so a fold or unfold resizes it. The CRT look's
  `world_pixel` stays 4.
- **The camera** (`rooms/view_camera.gd`) reads each view marker's fov as the vertical field of
  view of the 16:9 frame. A buffer narrower than 16:9 uses `KEEP_WIDTH` with the frame's
  horizontal fov, so it shows more above and below; a wider one uses `KEEP_HEIGHT` and shows more at
  the sides. Code that needs the picture's extent asks `ViewCamera.tangents()`, not `fov`.
- **The part in the hand** keeps its size in the 16:9 frame and stays at the picture's edge.
- **UI** anchored to the edges follows them. A touch panel's default place keeps its share of the
  free room (`MovablePanel.default_position`), so the trackpad stays at the bottom left and the
  keyboard centred.
- **Orientation:** `display/window/handheld/orientation` is sensor landscape, so the game turns
  with the device in both landscape directions. The committed `ios/CompuFun/CompuFun-Info.plist`
  changes to both orientations at the next export.

To try a shape on desktop, set `root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND` from a
throwaway `-s` script (or an uncommitted `Godot/override.cfg` with `window/stretch/aspect="expand"`)
and run with `--resolution 2034x1398`, `2622x1206` or `2360x1640`.

## What a real port needs

| Gap | Size |
| --- | --- |
| Device: heat over a whole week's play, the frame rate in the Screen View and the storage room, older iPhones | 0.5 day |
| The trackpad and keyboard on a device: gesture feel, panel sizes on a phone | 0.5 day |
| Hover: hotspot outlines show only under the mouse, which is how the player finds things. Pulse them on a tap that hits nothing, or always | 0.5 to 1 day |
| Small fixes: the printout trash's `is_hovered()` (`carried_printout.gd:99`) | 0.5 day |
| Phone Screen View: the Win95 desktop is too small to read or tap on a phone (below) | 2 to 4 days, design |

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

- **The debug strip:** in a debug build on touch, buttons in the top-left corner send F2, F3, F4,
  F9 and Cmd+N (`ui/touch/debug_strip.gd`). F3 and F4 show only where `dev/` is in the build.
- **The iOS preset carries `dev/`**, so its builds have the Dev menu, the Voice Lab and the Story
  Lab. Keep its builds within the team; the App Store gets the `iOS Release` preset ("Xcode Cloud").
- **The token goes in by hand.** The F2 GitHub tab saves the issues token and the reporter name in
  `user://github.cfg` on the device, and shows only the token's last 4 characters. Paste copies the
  token from the clipboard. Check reads the repo with it and shows the HTTP status and GitHub's
  message when that fails. Without a token, F9 saves its report in `user://feedback/`, and Send
  keeps the drafts.
- **No git on a device:** iOS can't start processes, and an export has no checkout.
  `GitHubIssues` runs git only where `.git` is next to the project; elsewhere the commit comes from
  `build_info.txt`, the repo is `dubiouspotions/compufun` and the name is the tab's. A draft
  started on this build starts from the build's own file; "changed on `main`" doesn't show.
- The Story Lab is a 1080p mouse tool: an iPad with a keyboard and a trackpad can use it, a phone
  can't.
- **Never build the issues token into an iOS build.** It can write to every branch of the repo, and
  anyone can unzip an IPA and read the `.pck`. With it they could push to `main`, which CI builds
  with the signing and itch.io secrets. A token typed into one team phone stays in that phone's
  app container. For testers outside the team, either a small relay (a serverless function) holds
  the token and only makes `story`/`feedback` issues and writes to the `feedback` branch, for a
  per-writer passphrase (about 1 day); or each writer signs in with GitHub's device flow to a
  GitHub App that has only this repo's Issues and Contents, and the token stays in the Keychain
  (1 to 2 days).

# Corruption signs

Ideas for in world Cambion corruption changes:

EARLY (Hard to notice) EVENTS, Day 1-3:

- Fonts in some text change to windows logo font
- Book/literature change to Win95 manual
- Clippy disappears in all computers, only empty frame where he usually was is left.
- In world items/actions make windows noises
- In one of the computers with Cambion Build (not all) all results in the calculator is always 666
- The entry bell plays a windows sound once

MID (Weird but "justifiable" changes),Day 3-5:

- Windows trashcan blinks in and out replacing office trash
- Colours in CompuFun logo changes from Red to windows blue
- A folder window pops up in real world - closes with "x" or after a short time.
- Pipedream pipes start showing in corner (continues with late effects
- Jumpscare lights go out in storage and blinks for a millisecond showing lifesize Clippy and then blinking away.
- Pallette changes towards more Windows shades over the week.
- Windows Mouse pointer can suddenly leave outside of the screen when working in windows

Late (Clearly affected, no questions), Day 5-7:
- A [x] shows up hovering over top right corner over (regular, non-narrative-connected) cutomer. If you click it - customer dissapears - never comes back
- Pipedreams from MID-effects spread noticeably in from corner
- A poster on the wall falls off with the "winning effect" from Solitaire 95.
- In world computer mouse is replaced by mouse-setting icon. THIS LOOKED BAD - DON'T DO THIS
- Shop windows are turned into windows-logo windows
- CompuFun logo starts reading "CambIon"
- The curser becomes a windows cursor in real life
- Some of the houses along the street get's replaced with folders
- The phone is replaced by a 3D model of the phone on modem icon from Windows settings:
<img width="101" height="82" alt="image" src="https://github.com/user-attachments/assets/192c33ba-f153-4d20-a8cf-613f056866d8" />


## The week

When each sign comes is in the story files: a day's notes and flags, and the errands' briefs and conversations.

## In the game

Every idea above is a corruption sign in the game: one scene, `Godot/corruption/<id>.tscn` (the wiki page Architecture, "Corruption signs"). The trigger layer sets its flag `sign_<id>`. For now only a day's `close_signs` start a sign by themselves (day 5 starts `posters_bounce`); the F2 Signs tab starts the rest. Each sign has an `enabled` box in its inspector, and the F2 Signs tab switches it on and off while the game runs.

| Idea | Sign | Stages | In the game |
| --- | --- | --- | --- |
| Fonts change to the Windows font | `win_font` | 1 | The post-its, the week calendar and the STORAGE sign switch to the bold W95FA pixel font. |
| Book becomes the Win95 manual | `win95_manual` | 1 | The PC manual on the work desk gets a Windows 95 manual cover. Easy to miss. |
| Clippy disappears | `no_clippy` | 1 | Every computer's WordPad shows the assistant's frame empty. |
| Things make Windows noises | `windows_noises` | 1 | A hotspot click, a part taken or put, and the cable sometimes also play ding, chord or tada. |
| 666 in the calculator | `calc_666` | 1 | In a computer that runs Cambion (`Computer.cambion`, for now the young entrepreneur's), every result is 666. |
| The bell plays a Windows sound once | `bell_sound` | 2 | The next ring plays the Win95 tada; then the sign is done (2) and the bell is a bell again. |
| Trash can blinks into the Recycle Bin | `win_trash` | 1 | Now and then the trash can blinks into the Recycle Bin for a moment; it still works. |
| Logo turns Windows blue | `logo_blue` | 1 | Both CompuFun logo signs turn from red to Windows blue. |
| A folder window pops up | `folder_popup` | 2 | A Win95 folder window floats in the Main View; its [X], or a while, closes it for good (2). |
| Pipedream, and its spread | `pipedream` | 2 | 1: the Pipes grow in the corner with the warp. 2: they spread to all of them. |
| Clippy in the dark storage | `clippy_jumpscare` | 2 | On the next visit to the Storage View the lights go out and a life-size Clippy flashes up; then done (2). |
| Palette drifts to Windows shades | `win_palette` | 3 | The world's colours move towards the 16 Windows 95 colours, further at each stage. |
| The pointer leaves the screen | `pointer_escape` | 1 | On the bench screen, the Windows pointer now and then slides off an edge and comes back. |
| [x] over a regular customer | `customer_x` | 1 | A customer with `Customer.regular` gets a Win95 [x]; a click sends them and their computer away for good. No customer is regular yet. |
| A poster falls with the Solitaire win | `poster_falls` | 2 | The poster falls and bounces with a trail of copies, then leans on the floor (2). It waits until the player sees it. |
| The logos and a poster leave the walls with the Solitaire win | `posters_bounce` | 2 | When the player closes the shop on day 5, the logo on the left wall, the poster on the right wall and last the logo over the door, 2.5 s apart, each shake on the wall, turn to face the counter and bounce across the shop between the counter and the door, leaving a trail of copies lit like the room. The night waits for them. Then they stay on the floor (2); the next day they hang on the walls again. |
| Computer mouse becomes the mouse icon | `mouse_icon` | 1 | The mouse on the bench becomes the Win95 Mouse icon, standing like a cut-out. |
| Shop windows become Windows-logo windows | `shop_windows` | 1 | Four coloured panes, with the alley still visible behind them. |
| Logo reads "CambIon" | `logo_cambion` | 1 | Both logo signs read CambIon in the logo's style; with `logo_blue` on too, in blue. |
| The cursor becomes a Windows cursor | `win_cursor` | 1 | The arrow and the hotspot hand over the shop become the Win95 arrow and a Windows hand. |
| Houses become folders | `alley_folders` | 1 | Three of the four houses behind the alley become giant yellow Win95 folders. |

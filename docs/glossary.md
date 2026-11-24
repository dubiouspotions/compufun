# Glossary

One canonical term per concept. Use the term everywhere: code, docs, prose and commits. When
they disagree with this file, this file wins; if the decision looks wrong, change the file
rather than the usage. New domain terms land here in the change that introduces them.

Format: one paragraph per term, `**Term**: definition.`, then the discouraged synonyms on the
next line as `*Avoid:* a, b.` Group terms under `##` headings when the list grows. No tables,
bullets or other separators, so that tools can parse every glossary the same way.

## Project

**Export preset**: One named entry in `Godot/export_presets.cfg` (`Web`, `Windows Desktop`, `MacOS`, `Linux`) that CI and `export.sh` export by name.
*Avoid:* target, platform build.

**Release**: One version of the game that CI tagged `vX.Y.Z`, built, signed and deployed, started by hand with a bump of the major, minor or patch number.
*Avoid:* publish, ship.

**Deploy**: Uploading the exported builds to itch.io, which CI does as part of a release.
*Avoid:* publish.

## Game

**View**: A fixed point of view in a room, such as Main, Left, Right, or a close-up (Workview, Screen, CompuFunDB). In the scene it is a `ViewMarker` node with the view's name.
*Avoid:* camera, room view, screen.

**Hotspot**: A thing in a room that the player clicks (`rooms/hotspot.tscn`).
*Avoid:* button, clickable, interactable.

**Ground**: A floor that customers walk on, such as the shop floor, the alley or the porch, with the footsteps that it sounds of (`rooms/ground.gd` on the floor's mesh). Where grounds overlap, the one with the highest top is under the customer.
*Avoid:* floor type, surface.

**Back strip**: The strip along the bottom of the Workview, Storage and Up views that goes back like the Back button when the player clicks it where nothing else is clickable (`Shop.back_strip_height`). It darkens under the mouse.
*Avoid:* back zone, back band, back area.

**Post-it**: The repair ticket on a computer on the counter: the perceived issue, and a green check once the computer is fixed and tested. Each computer wears one (`props/post_it_3d.tscn`). It sits on the front of the case, below the power button, standing or lying. In the Workview, `ui/post_it_label.tscn` writes its text in sharp UI text over the paper.
*Avoid:* ticket, note.

**Tested**: A fixed computer whose Windows desktop the player has seen stay up, for the problem's `hangs_after` seconds (`Job.tested`). Breaking the computer again clears it. Only a fixed and tested computer is done: its post-it shows the check, and the player can call its customer. CompuFunDB ends every repair but a software-only one with the step "Test the computer": a software fix lands on a running Windows, which tests it at once.
*Avoid:* checked, verified.

**CompuFunDB**: The database on the work computer. The player searches it for a symptom, ticks the checks that are true on the computer, which rules causes out, and prints the fix of the cause they pick. It reads every `Problem` file; `Game` holds the search (`DbSearch`).
*Avoid:* Company Database, BBS, database.

**Printout**: The page that the dot-matrix printer under the work desk (`Printer`) printed last: the checklist of a CompuFunDB search (its checks and the causes still possible), or the fix of one cause. It stays sticking out of the printer until the next print replaces it or the player takes it. The player carries one printout at a time, apart from the hand (`Game.printout`), and can't take another or put it down: only a click on the trash can or the end of the day takes it; its top peeks in at the bottom left of every view, clear of the part in the hand on the right, and a click raises it on the right side of the view, where the player ticks its check boxes as their own notes while they keep playing; a click outside the page lowers it (`ui/carried_printout.tscn`). In the CompuFunDB view it is always raised, right of the screen.
*Avoid:* print, checklist sheet.

**Design frame**: The 1920 x 1080 (16:9) canvas that the game is laid out for. Desktop and web show exactly it; a mobile screen of another shape shows all of it and more (docs/ios.md).
*Avoid:* design size, safe frame.

**Screen buffer**: The 640 x 480 viewport that runs the Win95 desktop. The 3D monitor shows it, and the Screen View shows it at 2x.
*Avoid:* desktop viewport, screen texture.

**Win95 setup**: The `Win95Setup` resource of one customer's computer: what the Win95 desktop looks like and holds when it boots. Game copies it into the running copy.
*Avoid:* computer config, Windows config, desktop data.

**Running copy**: The `Win95Setup` that a computer runs, copied from its Win95 setup at the first boot and kept by `Game` for the whole game. The player's changes and the problems' breaks land here.
*Avoid:* live setup, save state.

**Folder view**: How a Win95 folder window lays out its icons: Large Icons, Small Icons, List or Details, as its View menu names them (`IconView.folder_view`). Each window has its own; a folder opens in the folder view of the window that opened it.
*Avoid:* view (a point of view in a room), view mode, display mode.

**Report**: One F9 feedback report: a folder in `feedback/` with `shot.png` and `report.json`.
*Avoid:* ticket, bug report, feedback file.

**Prop**: A placeholder model scene in `Godot/props/`, such as `crt_monitor.tscn`. A room places props; it does not copy their parts.
*Avoid:* asset, model, object.

**Outside**: The world outside the shop windows (`rooms/shop/outside.tscn`): the back alley, the sky, the sun and moon, the lamps, the fog and the rain. It shows the daypart, and rain on a day with `Day.rain`.
*Avoid:* street, environment, weather system.

**Alley end**: One of the two ends of the back alley, left or right as the player sees them from the counter (`Game.AlleyEnd`). Each visitor walks in from one at random and mostly walks out toward the same one (`Game.visitor_from`, `Game.visitor_to`); the room mirrors the customer path for the left end.
*Avoid:* side, direction, street end.

**Open sign**: The sign that hangs in the shop window (`props/open_sign.tscn`). The player, inside, reads OPEN while the shop is open, and CLOSED while it is closed. When the shop opens or closes, it turns over on its strings. Each day starts with the shop closed: the player clicks the sign to open the shop, and no customer comes in until then. A customer whose errand comes before opening (day 1's middle manager) is already at the counter as the day starts; the sign takes clicks once they are out the door, and shakes then. Later the player clicks it again to close the shop for the night, which takes clicks only once every customer of the day has come in and the last visitor has walked out. While the sign takes clicks, a yellow outline pulses around it.
*Avoid:* closed sign, shop sign.

**Tutorial**: Day 1's first visit: the middle manager, already at the counter before the shop opens, explains the job (errand `0101`). The game holds his first line until the start-of-game logo has zoomed part way, and a Skip tutorial button jumps past his talk to the closed shop, ready to open.

**Poster**: A paper picture on a shop wall (`props/poster.tscn`); each one sets its picture and size in the inspector. The shop has the "It's not a bug" poster on the front wall and the commercial poster on the right wall (`Room/CommercialPoster`).
*Avoid:* ad, advert, sign.

**Hat**: The scene that a 3D customer wears on the head (`Customer.hat`), matching the hat in the portrait and clear of the face. `CustomerBody` puts it on the `HatMount` at the brow line. Pierre wears the cap (`props/cap.tscn`) backwards; the retired accountant wears the fedora (`props/fedora.tscn`).
*Avoid:* headwear, accessory, attachment.

**Neckwear**: The scene that a 3D customer wears around the neck (`Customer.neckwear`), matching the portrait and below the chin. `CustomerBody` puts it on the `NeckMount` in the middle of the neck. The activist wears the scarf (`props/scarf.tscn`). Like the hat, it shows on the modelled body only; the photo relief shows the portrait's own.
*Avoid:* scarf slot, collar, accessory.

**Sticker**: A small picture on the front or a side of a customer's computer case (a `Sticker` in `Computer.stickers`), shown with the poster prop. A computer has any number of stickers, or none. The case material (`Computer.case_material`), the case front and the stickers tell the computers on the counter apart.
*Avoid:* decal, label, badge.

**Case front**: The drive bays, floppy drives, buttons and badges on the front of a customer's computer case (`Computer.case_front`, a scene in `props/case_fronts/`); a computer without one has the classic front. The power button, the power light and the post-it are the same on every case.
*Avoid:* bezel, faceplate, front panel.

**Week calendar**: The paper wall calendar on the pin board in the Right view (`props/week_calendar.tscn`): the month and year, then one column per day of the game with its weekday and date, Saturday and Sunday in red. Each day that has passed is crossed out; a day has passed when the shop closes for its night.
*Avoid:* calendar prop, day counter.

**Wall clock**: The round clock on the shop wall (`props/wall_clock.tscn`), above the right shop window. Its hour and minute hands show the hour of the Outside, so they follow the daypart and the debug menu's time slider, and run forward to a later hour. Its red second hand ticks on real time, a little slower than real seconds. Move the instance to hang it on another wall.
*Avoid:* timer, watch.

**Job**: One customer's computer on the counter, with its slot, its repair state and its post-it (`Job`, in `Game.jobs`). It stays from the drop-off to the pickup, overnight too.
*Avoid:* order, ticket, repair.

**Part**: One kind of computer part: motherboard, CPU, fan, graphics card or hard drive (`Part`, `parts/<id>.tres`). Every computer has one of each, and a part can sit on another (the fan on the CPU).
*Avoid:* component, hardware item.

**Piece**: One real part: which part it is and whether it is broken (`Piece`). A piece sits in a computer's place, lies misplaced on another place, lies on the mat, is in the hand, or lies in the trash.
*Avoid:* item, instance.

**Unused piece**: A piece that the player took from a box in the Storage View and hasn't put in a computer yet (`Piece.unused`). Only an unused piece goes back into its box; a piece that was in a computer goes in the trash.
*Avoid:* new piece, spare.

**Place**: Where a part sits inside a computer. A job holds one piece per place, or none when the player took it out (`Job.places`).
*Avoid:* slot (that is a job's place on the counter).

**Side panel**: The panel that the player lifts off a computer to reach its parts, held by two screws (`Job.case_open`, `Job.panel_screws`). In the Workview the computer stands until the player clicks its top; then it lies on its side, the side panel up (`Job.lying`), in every view until the player stands it up with the panel on. Taken off, the panel leans against the back of the case until a click puts it back on.
*Avoid:* lid, cover, shell.

**Mat**: The strip in front of an open computer where the player lays the pieces that they took out, in two piles either side of the screwdriver's outline (`Job.mat`).
*Avoid:* tray, bench.

**Stand-in**: A part that no place takes but that sits in the places of another part and works like it, such as Skater Bro's heart in place of the motherboard (`Part.poses_as`, `Problem.stand_ins`).
*Avoid:* organ part, fake part.

**Misplaced piece**: A piece that the customer put on a place of another kind; it keeps that place empty until the player lifts it off (`Problem.misplaced`, `Job.misplaced`).
*Avoid:* loose part, wrong part.

**Missing part**: A part that the customer took out: one place that takes it starts empty, and the player takes a new one from the storage (`Problem.missing_part`).

**Empty case**: A haunted computer with every place empty that runs anyway, as the hat guy's does on day 6 (`Problem.empty_case`, problem `no_parts`). Taking the side panel off and putting it back on fixes its hardware; the case stays empty.
*Avoid:* haunted case, hollow case.

**Hand**: The one piece that the player holds (`Game.hand`). Its model shows low in the view, held in front of the camera, with its name (`rooms/shop/hand.tscn`). The player puts it somewhere by clicking there or by dragging it there.
*Avoid:* inventory, cursor item.

**Storage View**: The close-up of the parts desk in the storage room, with one plastic tray of new parts per part, and one of CompuFun AntiVirus floppy disks, each labelled with its name. The storage door in the Left View leads there, and so do Up and W in the Left View; Back, Right and D lead back to the Left View.
*Avoid:* shelf view, parts screen.

**Computer mouse**: The part that the ceiling mouse drops (`parts/mouse.tres`). No computer has a place for it. Always say *computer mouse* for the part, so it never means the animal.
*Avoid:* mouse (alone), peripheral.

**Floppy disk**: A 3.5" disk that goes into a computer's drive A: and comes out of it into the hand (`FloppyDisk`, a part that no place takes): its label (`FloppyDisk.label`) and the files on it. The generic one (`parts/floppy.tres`) is the bootfloppy problem's; the CompuFun AntiVirus disk (`parts/antivirus_floppy.tres`) comes from its box in the Storage View.
*Avoid:* diskette, floppy (alone in code).

**Ceiling mouse**: The easter egg, off for now (`CeilingMouse.enabled`): the animal in the hole above the player that squeaks and drops the computer mouse, once in the whole game (`CeilingMouse`, the flag `ceiling_mouse`).
*Avoid:* rat, the mouse (alone).

**Up View**: The view straight up at the ceiling, from the Main View with Up or W while the counter is empty. With computers on the counter, Up or W opens the Workview on the one nearest the middle of the Main View.
*Avoid:* ceiling view, look-up view.

**Bench screen**: The CRT at the left end of the counter, with its keyboard (`rooms/shop/bench.tscn`). It shows the screen buffer: the desktop of the computer that the VGA cable is connected to, or NO SIGNAL.
*Avoid:* bench monitor, bench computer.

**CRT look**: The look of a mid-90s VGA monitor on the bench screen, in the Screen View and in the 3D room: curve, faint scanlines, mask, glow ([crt.md](crt.md)).
*Avoid:* CRT filter, CRT effect, scanline shader.

**Tube**: The bench screen's picture tube as the game animates it (`CrtTube`): its power, its lock on the signal, the degauss and the magnetised screen.
*Avoid:* CRT state, monitor state.

**Degauss**: Demagnetising the bench screen's mask: the picture twists and its colours swim, it blinks to black, and it comes back with the magnetised screen cleared. It happens at power-on and when the player presses the Degauss button on the bench screen's right bezel.
*Avoid:* demagnetise, reset the screen.

**Magnetised screen**: Blotches of wrong colour on the bench screen, which Cambion builds up faster as the day's warp rises. A degauss clears them.
*Avoid:* colour corruption, purity error.

**VGA cable**: The cable from the bench screen to one computer on the counter (`Game.connected`). The player drags its plug onto a computer to connect it, or off a computer to disconnect it; or clicks the plug to take it, and clicks again to put it there.
*Avoid:* keyboard cable, screen cable.

**Slot**: One of the `Game.MAX_JOBS` places on the work mat where a job's computer stands (`Job.slot`). The computers fill the slots from the left, oldest first: when one leaves, the computers right of it slide left. In the scene it is a `Slot<n>` marker in `rooms/shop/job_slots.tscn`.
*Avoid:* place, spot, position.

**Errand**: One visit on a day: a customer, what is wrong with their computer this time (or nothing), what the visit is for and what is said (`Errand`, a story file in `story/errands/`). A customer who comes back on another day brings the same computer with a new errand. Not *visit*, which is why the visitor is in (`Game.Visit`: drop-off, pickup or event).

**Errand code**: The four digits that start an errand's file name: the day and the errand's place in it, so `0503_nice_guy.errand` is day 5, the third errand. Two errands with one code are alternatives; the first whose condition matches comes.
*Avoid:* slot (a place on the work mat), timeslot, id.

**Story file**: A plain-text file in `Godot/story/` that writers edit in the Story Lab: a day (`days/day_<n>.day`), an errand (`errands/<code>_<customer>.errand`), a problem file (`problems/<id>.problem`), a customer's call-outs (`callouts/<customer>.callouts`) or a bible page (`bible/*.md`). The format is in `docs/dialogue.md`.
*Avoid:* script, timeline, data file.

**Problem file**: The story file of one computer problem, `story/problems/<id>.problem`: the post-it, the symptoms and how each shows, the repair steps and notes. The mechanics stay in `problems/<id>.tres`; the game fills the text into it as the week loads.
*Avoid:* problem text, problem resource (that is the `.tres`).

**Brief**: What an errand or a conversation is for, in plain words, written before its lines. People read it; the game doesn't.
*Avoid:* intent, synopsis, story.

**Bible**: The prose of the story that the game doesn't read: the lore, the cast and the end (`story/bible/`).
*Avoid:* lore doc, storyline page.

**Mood**: How a customer says a line: it picks the person's portrait, and the voice mood unless the line has its own. A person has the moods that it has portraits for.
*Avoid:* pose, emotion, expression.

**Line part**: The run of a customer line in one mood. A `(mood)` inside a line starts a new line part (`DialogueLine.parts()`): the dialogue box shows its face once its audio starts, and the voice says it in its own mood, from its own voice file, right after the part before. A line in one mood is one line part.
*Avoid:* part (alone: a part is a computer part), segment, beat, sub-line.

**Voice mood**: How a line sounds, apart from its picture: a `VoiceMood` in `voices/moods/<mood>.tres` (speed, pitch and more). A line speaks in its mood's voice mood, or in its own (`DialogueLine.voice_mood`, `[voice mood]` in a story file) when a portrait is used outside its own mood.
*Avoid:* voice pose, tone.

**Story Lab**: The panel in the running game (Dev menu, F4) that edits the story files: the week, the errands and their conversations, as a graph or as text, the problems, the corruption signs, the call-outs and the bible, and plays a conversation in place.
*Avoid:* Dialogue tab, Week tab, story editor, dialogue editor.

**Week board**: The Story Lab's week (`dev/story_lab/week_board.gd`): a column per day, split into bands, Before opening, Morning, Midday, Afternoon and At closing. Each errand card sits under the band of its daypart; a card dropped on a band's heading goes to the band's end, one dropped on a card goes next to it, and both take the band's daypart. At closing lists the day's closing facts. A chip shows where each corruption sign starts. Cards drag between places and bands; customers and signs drag onto it from the strips above it, a customer to make an errand and a sign to start there.
*Avoid:* timeline, calendar, week view.

**Draft**: A writer's edit of a story file, kept in the player's user folder until `main` has it (`user://story_drafts/`). The game plays drafts over the files from `main`; Send turns them into a GitHub issue.
*Avoid:* local change, patch, overlay.

**Unfinished text**: A writer's text of a story file that doesn't parse yet, kept beside the drafts (`user://story_drafts/unfinished/`, `StoryDrafts.unfinished`) so that a quit doesn't lose it. The game doesn't play it and Send doesn't send it; the Story Lab's text view opens it with its errors, and once it parses it becomes the draft.
*Avoid:* broken draft, pending text, scratch.

**Play in editor**: The Story Lab plays a conversation in the game's own dialogue box over the Lab, as the game plays it, choices and all, on the flags of the morning of the errand's day, and the paused game stays as it was (`StoryPlayInEditor`). The Play in editor button plays it from its start; Shift+Enter or the sidebar's Play in the text view, and a line's Play in the graph, play it from that line. Esc closes it.
*Avoid:* line preview, preview, mock dialogue.

**Play in game**: The Story Lab jumps the game to the errand and plays the conversation there (`Game.play_errand`); Esc or F4 goes back to the Lab.
*Avoid:* Play here.

**Event**: A visit that a customer doesn't walk in for: while their errand's computer is on the counter and not yet done, they pop up from behind the counter and talk (`== event` in the errand's story file, `Game.Visit.EVENT`). It holds the next customer back until it came, and isn't an arrival.
*Avoid:* jumpscare, special visit, interruption.

**Visitor**: The customer who is in the shop now, to drop off, show or pick up a computer, or with none (`Game.visitor`, in for `Game.errand`). Only one at a time. One who shows a computer waits beside it on the counter until the player clicks them; then they pick it up.
*Avoid:* current customer.

**Daypart**: The time of day in the game: morning, midday, afternoon or evening (`Game.daypart`). The day starts in the morning; the day's first errand of daypart midday or afternoon (`Errand.daypart`, `daypart:` in its story file) turns it to that daypart as its customer comes in, and closing the shop makes it evening; time does not pass on its own. The Outside shows it. `Game.moment` counts the days and dayparts as one number, for what takes game time, such as a Disk Defragmenter run (`Game.defrag_progress`).
*Avoid:* hour, time, clock.

**Debug menu**: The F2 panel in debug builds, with the tabs World (the time of day, the day cycle, the rain), Game (the `Game` state), Presets, Signs and GitHub (the issues token and the reporter name on a device).
*Avoid:* dev menu, cheat menu.

**Touch controls**: What a touch screen gets while the player's last pointer input was a finger (`ui/touch/`): swipes in the world, the trackpad, the touch keyboard and, in debug builds, the debug strip.

**Swipe**: A finger's quick drag across the world: sideways it turns the view like a panorama, down it leaves a close-up. A mouse never swipes.

**Trackpad**: The touch panel that moves the desktop's cursor in an open Screen View or CompuFunDB, instead of fingers on the glass.
*Avoid:* touchpad, virtual mouse.

**Touch keyboard**: The on-screen PC keyboard that the trackpad's KEYS button shows; it sends real key events.
*Avoid:* virtual keyboard, soft keyboard.

**Debug strip**: The row of buttons in debug builds on touch screens that press the debug tools' keys (F2, F3, F4, F9, Skip).

**Preset**: A `Game` state that the debug menu sets with one click, in the format of `Game.snapshot()`. The presets are in `ui/debug_presets.gd`.
*Avoid:* quick button, shortcut, save state.

**Jump**: A change of the `Game` state that no step of play made: the start of a day, or a restore (`Game.jump` counts them). Scenes show the new state at once, without the sounds and animations of a change.
*Avoid:* cut, reset, reload.

**Ending**: One way the week can end, a file in `endings/` (`Ending`): when the game has ENDED, the enabled one whose condition holds, with the highest priority, plays. The finale is the default; the pipes through the chest are ready but off.

**Finale**: The end of the world, the default ending on day 7 and the close of the pipes ending, and from the F2 World tab (`finale/finale.tscn`): everything turns into a bluescreen, the player's own computer seems to restart and fail with a corrupted drive (or boots as Win95 Cambion), and the credits show.
*Avoid:* ending (that is the pipes on day 7), outro.

**Flag**: A fact of the story in `Game.flags`: a name and a number. 0 or missing means not set.
*Avoid:* variable, story state, switch.

**Trigger**: The moment a conversation can play: `ARRIVE` when a customer brings a computer, `PICKUP` when they come back for it, `PHONE` when they answer the player's call, or `EVENT` when they pop up behind the counter (an Event). Story files write them `drop-off`, `pick-up`, `phone` and `event`.
*Avoid:* event, hook.

**Condition**: The days and flags that an errand, a conversation, a choice or a reply needs to play (`Condition` resource).
*Avoid:* requirement, rule, filter.

**Conversation**: One exchange with a customer: the lines they say, one at a time, and the player's choices. It is a section of an errand's story file; `Game` plays the errand's first one whose trigger and condition match.
*Avoid:* dialog, dialogue tree, script.

**Call-out**: A line that a customer says outside the dialogue box, in the call-out box at the edge of the screen that points at them (`ui/customer_calling.tscn`): while they wait and the player looks elsewhere, as they leave (`[leaving]`), and while a look has turned the player away. What they call out while they wait is in `story/callouts/` (`Game.call_outs_of`).
*Avoid:* bark, shout, speech bubble.

**Look**: A turn of the player's view that a customer's line asks for before it is said: left to the Left View, right to the Right View or ahead to the Main View (`DialogueLine.look`, `[look left]` in a story file). While a look has turned the player away from the customer, the conversation's lines show in the call-out box.
*Avoid:* force turn, turn, camera move.

**Name**: A person's name, for use on that person's computer (`Person.name`). Dialogue does not show it.
*Avoid:* full name, legal name.

**Actor**: The real name of whoever was photographed for a person (`Person.actor`). The credits show it, with the person's nickname under it.
*Avoid:* real name, cast member.

**Nickname**: What the dialogue calls a person (`Person.nickname`). While it is empty, dialogue uses the customer's display name.
*Avoid:* alias, handle, screen name.

**Email**: A person's address, for use on that person's computer (`Person.email`). Dialogue does not show it.
*Avoid:* mail, address, account.

**Hum**: A quiet loop from a thing in the shop that runs, which plays while it runs (`sounds/hum.gd`): the storage bulb's mains buzz while it is lit, a PC's fans while it is on, a CRT's hum while its tube is on.
*Avoid:* ambience, drone, room tone.

## Win95

**Office frame**: The window that every Office 97 app on a customer's computer shares (`win95/office/office_window.tscn`): the title, Office's File menu, the Standard and Formatting toolbars, the status bar and the Office Assistant's layer. Word and Excel are scenes that inherit it.
*Avoid:* Office shell, Office window, chrome.

**Office Assistant**: The paper clip with eyes in the corner of an Office app (`win95/office/assistant/`), Office 97's Clippit, his frames cut from screenshots of Office 97: he welcomes, offers help with a letter, shows tips and answers Help. The story calls him Clippy; from day 3 Cambion has taken him (`corruption/no_clippy`): his window still comes and talks, but it is empty.
*Avoid:* Clippit (except in his own Gallery), helper, paperclip.

**Control Panel**: The Win95 folder that lists the applets of every `.CPL` file in `C:\WINDOWS\SYSTEM` of the running copy; Fonts and Printers are applets of MAIN.CPL too. It opens from My Computer and from Start > Settings.
*Avoid:* settings, control center.

**Applet**: One icon in the Control Panel, such as Display or Mouse (`Applet` resource): its name, description, icon and property sheet. A `.CPL` file holds one or more applets in `Win95File.applets`; renaming or moving the file hides them.
*Avoid:* control panel item, CPL (that is the file).

**Property sheet**: A Win95 dialog with tabs and OK, Cancel and Apply (`win95/property_sheet.tscn`). Its pages edit pending values; Apply and OK commit them to the running copy through `ComputerState`.
*Avoid:* properties dialog, settings window.

**Colour scheme**: One of Win95's Appearance schemes, such as Rose or Windows Standard: a `Win95Palette` in `win95/theme/schemes/`. The running copy's `palette` is the scheme that the computer shows.
*Avoid:* theme, palette (that is the resource type).

**Pointer trails**: The ghost pointers that follow the mouse on a computer whose Mouse settings turn them on (`Win95Setup.pointer_trails`, drawn by `win95/pointer_trails.gd`).
*Avoid:* mouse trails, cursor trail.

**Screensaver**: One of the savers that Display > Screen Saver lists, such as Flying Through Space: a `Saver` in `win95/savers/` that covers the Win95 screen, hides the pointer, and ends on a key, a click or a mouse move.
*Avoid:* screen saver (outside Win95's own labels).

**Background task**: A Win95 program that runs without a window (`BackgroundTask`), such as the email virus BIZOPP.EXE. It starts when its program file opens, also from the StartUp folder at each boot, and runs until End Task, a shutdown or a restart (`ComputerState.tasks()`).
*Avoid:* process, service, daemon.

**File in use**: The program file of a running background task, or a folder that holds one (`ComputerState.in_use`). Win95 refuses to delete, rename or move it with a sharing violation.
*Avoid:* locked file, open file.

**Close Program**: The Win95 dialog that Ctrl+Alt+Del opens (`win95/close_program.tscn`): the open windows and the background tasks, with End Task, Shut Down and Cancel. Ctrl+Alt+Del again restarts the computer. Ctrl+Alt+End and Ctrl+Alt+Backspace open it too.
*Avoid:* task manager, Ctrl+Alt+Del menu.

**Virus**: A background task that is a virus (`Virus`), such as BIZOPP.EXE, which scanners name `Bizopp.A` (`Virus.virus_name`). A program file whose scene is one is infected, whatever problem put it there (`Virus.infects`). A virus in the StartUp folder runs from power-on, before Windows starts, so its symptom shows as soon as the computer is on.
*Avoid:* malware, worm.

**CompuFun AntiVirus**: The antivirus on the floppy disk from its box in the Storage View. Its SETUP.EXE installs AV.EXE into C:\Program Files (`win95/av_setup.tscn`, `ComputerState.install`); AV.EXE's Scan Now lists the infected files on the desktop and drive C, and Clean removes them with their tasks and StartUp shortcuts (`win95/av_scan.tscn`, `ComputerState.remove_viruses`).
*Avoid:* virus scanner, AV (alone).

**Corruption sign**: One of Cambion's changes to the shop, such as the blue logo (`CorruptionSign`, `corruption/<id>.tscn`). It shows while its flag `sign_<id>` is set and its feature switch `enabled` is on.
*Avoid:* effect, glitch, event.

**Trigger layer**: Whatever sets a corruption sign's flag: for now only the F2 Signs tab; later the days, the conversations or a story script.
*Avoid:* scheduler, director.

**Photo relief**: The 3D customer's upper body made from one portrait (`PhotoRelief`): the photo on the front, the person seen from behind (`Person.back`) on the back. The portrait is the person's **relief pose** (`Person.relief_pose`), neutral by default, and the back is drawn from the same portrait.
*Avoid:* billboard, cut-out, sprite.

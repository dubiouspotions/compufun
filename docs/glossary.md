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

**Deploy**: Uploading the exported builds to itch.io, which CI does from the `deploy` branch or a manual run.
*Avoid:* release, publish.

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

**Tested**: A fixed computer whose Windows desktop the player has seen stay up, for the problem's `hangs_after` seconds (`Job.tested`). Breaking the computer again clears it. Only a fixed and tested computer is done: its post-it shows the check, and the player can call its customer. CompuFunDB ends every repair with the step "Test the computer".
*Avoid:* checked, verified.

**CompuFunDB**: The database on the work computer. The player adds a record per customer and types what they like into it, marks what is wrong among every symptom, and gets what to fix. It reads every `Problem` file; `Game` holds the records.
*Avoid:* Company Database, BBS, database.

**Printout**: The page that the dot-matrix printer under the work desk (`Printer`) printed last: the checklist of a CompuFunDB record, its CHECK and FIX columns as on screen, or its FIX steps alone. It stays sticking out of the printer until the next print replaces it or the player takes it. The player carries one printout at a time, apart from the hand (`Game.printout`), and can't take another or put it down: only a click on the trash can or the end of the day takes it; its top peeks in at the bottom left of every view, clear of the part in the hand on the right, and a click raises it on the right side of the view, where the player ticks its check boxes as their own notes while they keep playing; a click outside the page lowers it (`ui/carried_printout.tscn`). In the CompuFunDB view it is always raised, right of the screen.
*Avoid:* print, checklist sheet.

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

**Open sign**: The sign that hangs in the shop window (`props/open_sign.tscn`). The player, inside, reads OPEN while the shop is open, and CLOSED while it is closed. When the shop opens or closes, it turns over on its strings. Each day starts with the shop closed: the player clicks the sign to open the shop, and no customer comes in until then. Later the player clicks it again to close the shop for the night, which takes clicks only once every customer of the day has come in and the last visitor has walked out. While the sign takes clicks, a yellow outline pulses around it.
*Avoid:* closed sign, shop sign.

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

**Piece**: One real part: which part it is and whether it is broken (`Piece`). A piece sits in a computer's place, is in the hand, or lies in the trash.
*Avoid:* item, instance.

**Unused piece**: A piece that the player took from a box in the Storage View and hasn't put in a computer yet (`Piece.unused`). Only an unused piece goes back into its box; a piece that was in a computer goes in the trash.
*Avoid:* new piece, spare.

**Place**: Where a part sits inside a computer. A job holds one piece per place, or none when the player took it out (`Job.places`).
*Avoid:* slot (that is a job's place on the counter).

**Side panel**: The panel that the player lifts off a computer to reach its parts, held by two screws (`Job.case_open`, `Job.panel_screws`). In the Workview the computer stands until the player clicks its top; then it lies on its side, the side panel up (`Job.lying`), in every view until the player stands it up with the panel on. Taken off, the panel leans against the back of the case until a click puts it back on.
*Avoid:* lid, cover, shell.

**Hand**: The one piece that the player holds (`Game.hand`). Its model shows low in the view, held in front of the camera, with its name (`rooms/shop/hand.tscn`). The player puts it somewhere by clicking there or by dragging it there: into an empty place, into the trash, or, when it is unused, back into its box. While the hand is full, no piece comes out of a computer.
*Avoid:* inventory, cursor item.

**Storage View**: The close-up of the parts desk in the storage room, with one plastic tray of new parts per part, labelled with its name. The storage door in the Left View leads there, and so do Up and W in the Left View.
*Avoid:* shelf view, parts screen.

**Computer mouse**: The part that the ceiling mouse drops (`parts/mouse.tres`). No computer has a place for it. Always say *computer mouse* for the part, so it never means the animal.
*Avoid:* mouse (alone), peripheral.

**Ceiling mouse**: The easter egg, off for now (`CeilingMouse.enabled`): the animal in the hole above the player that squeaks and drops the computer mouse, once in the whole game (`CeilingMouse`, the flag `ceiling_mouse`).
*Avoid:* rat, the mouse (alone).

**Up View**: The view straight up at the ceiling, from the Main View with Up or W.
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

**Errand**: One visit on a day: a customer, what is wrong with their computer this time (or nothing), what the visit is for and what is said (`Errand`, a story file in `story/errands/`). A customer who comes back on another day brings the same computer with a new errand. Not *visit*, which is why the visitor is in (`Game.Visit`: drop-off or pickup).

**Errand code**: The four digits that start an errand's file name: the day and the errand's place in it, so `0503_nice_guy.errand` is day 5, the third errand. Two errands with one code are alternatives; the first whose condition matches comes.
*Avoid:* slot (a place on the work mat), timeslot, id.

**Story file**: A plain-text file in `Godot/story/` that writers edit in the Story Lab: a day (`days/day_<n>.day`), an errand (`errands/<code>_<customer>.errand`) or a bible page (`bible/*.md`). The format is in `docs/dialogue.md`.
*Avoid:* script, timeline, data file.

**Brief**: What an errand or a conversation is for, in plain words, written before its lines. People read it; the game doesn't.
*Avoid:* intent, synopsis, story.

**Bible**: The prose of the story that the game doesn't read: the lore, the cast and the end (`story/bible/`).
*Avoid:* lore doc, storyline page.

**Mood**: How a customer says a line: it picks the person's portrait and the voice mood (`voices/moods/<mood>.tres`). A person has the moods that it has portraits for.
*Avoid:* pose, emotion, expression.

**Story Lab**: The panel in the running game (Dev menu, F4) that edits the story files: the week, the errands and their conversations, as a graph or as text, and plays a conversation in place.
*Avoid:* Dialogue tab, Week tab, story editor, dialogue editor.

**Draft**: A writer's edit of a story file, kept in the player's user folder until `main` has it (`user://story_drafts/`). The game plays drafts over the files from `main`; Send turns them into a GitHub issue.
*Avoid:* local change, patch, overlay.

**Visitor**: The customer who is in the shop now, to drop off or to pick up a computer (`Game.visitor`). Only one at a time.
*Avoid:* current customer.

**Daypart**: The time of day in the game: morning, midday, afternoon or evening (`Game.daypart`). The day starts in the morning, the second and third customers who come in make it midday and afternoon, and closing the shop makes it evening; time does not pass on its own. The Outside shows it.
*Avoid:* hour, time, clock.

**Debug menu**: The F2 panel in debug builds, with three tabs: World (the time of day, the day cycle, the rain), Game (the `Game` state) and Presets.
*Avoid:* dev menu, cheat menu.

**Preset**: A `Game` state that the debug menu sets with one click, in the format of `Game.snapshot()`. The presets are in `ui/debug_presets.gd`.
*Avoid:* quick button, shortcut, save state.

**Jump**: A change of the `Game` state that no step of play made: the start of a day, or a restore (`Game.jump` counts them). Scenes show the new state at once, without the sounds and animations of a change.
*Avoid:* cut, reset, reload.

**Ending**: One way the week can end, a file in `endings/` (`Ending`): when the game has ENDED, the enabled one whose condition holds, with the highest priority, plays. The finale is the default; the pipes through the chest are ready but off.

**Finale**: The end of the world, the default ending on day 7 and the close of the pipes ending, and from the F2 World tab (`finale/finale.tscn`): everything turns into a bluescreen, the player's own computer seems to restart and fail with a corrupted drive (or boots as Win95 Cambion), and the credits show.
*Avoid:* ending (that is the pipes on day 7), outro.

**Flag**: A fact of the story in `Game.flags`: a name and a number. 0 or missing means not set.
*Avoid:* variable, story state, switch.

**Trigger**: The moment a conversation can play: `ARRIVE` when a customer brings a computer, `PICKUP` when they come back for it, or `PHONE` when they answer the player's call. Story files write them `drop-off`, `pick-up` and `phone`.
*Avoid:* event, hook.

**Condition**: The days and flags that an errand, a conversation, a choice or a reply needs to play (`Condition` resource).
*Avoid:* requirement, rule, filter.

**Conversation**: One exchange with a customer: the lines they say, one at a time, and the player's choices. It is a section of an errand's story file; `Game` plays the errand's first one whose trigger and condition match.
*Avoid:* dialog, dialogue tree, script.

**Name**: A person's name, for use on that person's computer (`Person.name`). Dialogue does not show it.
*Avoid:* full name, real name, legal name.

**Nickname**: What the dialogue calls a person (`Person.nickname`). While it is empty, dialogue uses the customer's display name.
*Avoid:* alias, handle, screen name.

**Email**: A person's address, for use on that person's computer (`Person.email`). Dialogue does not show it.
*Avoid:* mail, address, account.

**Hum**: A quiet loop from a thing in the shop that runs, which plays while it runs (`sounds/hum.gd`): the storage bulb's mains buzz while it is lit, a PC's fans while it is on, a CRT's hum while its tube is on.
*Avoid:* ambience, drone, room tone.

## Win95

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

**Corruption sign**: One of Cambion's changes to the shop, such as the blue logo (`CorruptionSign`, `corruption/<id>.tscn`). It shows while its flag `sign_<id>` is set and its feature switch `enabled` is on.
*Avoid:* effect, glitch, event.

**Trigger layer**: Whatever sets a corruption sign's flag: for now only the F2 Signs tab; later the days, the conversations or a story script.
*Avoid:* scheduler, director.

**Photo relief**: The 3D customer's upper body made from the neutral portrait (`PhotoRelief`): the photo on the front, the person seen from behind (`Person.back`) on the back.
*Avoid:* billboard, cut-out, sprite.

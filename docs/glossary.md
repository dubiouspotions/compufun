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

**Post-it**: The repair ticket on a computer on the counter: the perceived issue, and a green check once the computer is fixed. Each computer wears one (`props/post_it_3d.tscn`). It sits on the front of the case, below the power button, standing or lying. In the Workview, `ui/post_it_label.tscn` writes its text in sharp UI text over the paper.
*Avoid:* ticket, note.

**CompuFunDB**: The database on the work computer. For each computer on the counter it shows what the customer reported, every symptom to check for, and what to fix once the right ones are marked. It reads every `Problem` file.
*Avoid:* Company Database, BBS, database.

**Screen buffer**: The 640 x 480 viewport that runs the Win95 desktop. The 3D monitor shows it, and the Screen View shows it at 2x.
*Avoid:* desktop viewport, screen texture.

**Win95 setup**: The `Win95Setup` resource of one customer's computer: what the Win95 desktop looks like and holds when it boots. Game copies it into the running copy.
*Avoid:* computer config, Windows config, desktop data.

**Running copy**: The `Win95Setup` that a computer runs, copied from its Win95 setup at the first boot and kept by `Game` for the whole game. The player's changes and the problems' breaks land here.
*Avoid:* live setup, save state.

**Report**: One F9 feedback report: a folder in `feedback/` with `shot.png` and `report.json`.
*Avoid:* ticket, bug report, feedback file.

**Prop**: A placeholder model scene in `Godot/props/`, such as `crt_monitor.tscn`. A room places props; it does not copy their parts.
*Avoid:* asset, model, object.

**Outside**: The world outside the shop windows (`rooms/shop/outside.tscn`): the back alley, the sky, the sun and moon, the lamps, the fog and the rain. It shows the daypart.
*Avoid:* street, environment, weather system.

**Open sign**: The sign that hangs in the shop window (`props/open_sign.tscn`). Its OPEN side faces the street while the shop is open, so the player, inside, reads CLOSED; the player clicks it to close the shop for the night, once every customer of the day has come in.
*Avoid:* closed sign, shop sign.

**Poster**: A paper picture on a shop wall (`props/poster.tscn`); each one sets its picture and size in the inspector. The shop has the "It's not a bug" poster on the front wall and the commercial poster on the right wall (`Room/CommercialPoster`).
*Avoid:* ad, advert, sign.

**Hat**: The scene that a 3D customer wears on the head (`Customer.hat`), matching the hat in the portrait and clear of the face. `CustomerBody` puts it on the `HatMount` at the brow line. Pierre wears the cap (`props/cap.tscn`) backwards.
*Avoid:* headwear, accessory, attachment.

**Sticker**: A small picture on the front or a side of a customer's computer case (a `Sticker` in `Computer.stickers`), shown with the poster prop. A computer has any number of stickers, or none. The case material (`Computer.case_material`) and the stickers tell the computers on the counter apart.
*Avoid:* decal, label, badge.

**Week calendar**: The calendar on the pin board in the Right view (`props/week_calendar.tscn`): one cell per day of the game with its weekday and date, Saturday and Sunday in red, and a check mark on each day that has passed. A day has passed when the shop closes for its night.
*Avoid:* calendar prop, day counter.

**Job**: One customer's computer on the counter, with its slot, its repair state and its post-it (`Job`, in `Game.jobs`). It stays from the drop-off to the pickup, overnight too.
*Avoid:* order, ticket, repair.

**Part**: One kind of computer part: motherboard, CPU, fan, graphics card or hard drive (`Part`, `parts/<id>.tres`). Every computer has one of each, and a part can sit on another (the fan on the CPU).
*Avoid:* component, hardware item.

**Piece**: One real part: which part it is and whether it is broken (`Piece`). A piece sits in a computer's place, lies on the mat, or is in the hand.
*Avoid:* item, instance.

**Place**: Where a part sits inside a computer. A job holds one piece per place, or none when the player took it out (`Job.places`).
*Avoid:* slot (that is a job's place on the counter).

**Side panel**: The panel that the player lifts off a computer to reach its parts, held by two screws (`Job.case_open`, `Job.panel_screws`). In the Workview the computer stands until the player clicks its top; then it lies on its side, the side panel up (`Game.lay_down`).
*Avoid:* lid, cover, shell.

**Mat**: The strip in front of an open computer where the player lays the pieces that they took out (`Job.mat`).
*Avoid:* tray, bench.

**Hand**: The one piece that the player holds (`Game.hand`). Its model shows low in the view, held in front of the camera, with its name (`rooms/shop/hand.tscn`).
*Avoid:* inventory, cursor item.

**Storage View**: The close-up of the parts desk in the storage room, with one box of new parts per part. The storage door in the Left View leads there.
*Avoid:* shelf view, parts screen.

**Bench screen**: The CRT at the left end of the counter, with its keyboard (`rooms/shop/bench.tscn`). It shows the screen buffer: the desktop of the computer that the VGA cable is connected to, or NO SIGNAL.
*Avoid:* bench monitor, bench computer.

**CRT look**: The look of a mid-90s VGA monitor on the bench screen, in the Screen View and in the 3D room: curve, faint scanlines, mask, glow ([crt.md](crt.md)).
*Avoid:* CRT filter, CRT effect, scanline shader.

**Tube**: The bench screen's picture tube as the game animates it (`CrtTube`): its power, its lock on the signal, the degauss and the magnetised screen.
*Avoid:* CRT state, monitor state.

**Degauss**: Demagnetising the bench screen's mask: the picture shakes, its colours swim, and the magnetised screen clears. It happens at power-on and when the player presses the Degauss button under the bench screen.
*Avoid:* demagnetise, reset the screen.

**Magnetised screen**: Blotches of wrong colour on the bench screen, which Cambion builds up faster as the day's warp rises. A degauss clears them.
*Avoid:* colour corruption, purity error.

**VGA cable**: The cable from the bench screen to one computer on the counter (`Game.connected`). The player drags its plug onto a computer to connect it, or off a computer to disconnect it.
*Avoid:* keyboard cable, screen cable.

**Slot**: One of the `Game.MAX_JOBS` places on the work mat where a job's computer stands (`Job.slot`). In the scene it is a `Slot<n>` marker in `rooms/shop/job_slots.tscn`.
*Avoid:* place, spot, position.

**Visitor**: The customer who is in the shop now, to drop off or to pick up a computer (`Game.visitor`). Only one at a time.
*Avoid:* current customer.

**Daypart**: The time of day in the game: morning, midday, afternoon or evening (`Game.daypart`). The day starts in the morning, the second and third customers who come in make it midday and afternoon, and closing the shop makes it evening; time does not pass on its own. The Outside shows it.
*Avoid:* hour, time, clock.

**Debug menu**: The F2 panel in debug builds, with three tabs: World (the time of day, the day cycle, the rain), Game (the `Game` state) and Presets.
*Avoid:* dev menu, cheat menu.

**Preset**: A `Game` state that the debug menu sets with one click, in the format of `Game.snapshot()`. The presets are in `ui/debug_presets.gd`.
*Avoid:* quick button, shortcut, save state.

**Flag**: A fact of the story in `Game.flags`: a name and a number. 0 or missing means not set.
*Avoid:* variable, story state, switch.

**Trigger**: The moment a conversation can play, such as `ARRIVE` when a customer brings a computer, or `PICKUP` when they come back for it.
*Avoid:* event, hook.

**Condition**: The days and flags that a conversation needs to play (`Condition` resource).
*Avoid:* requirement, rule, filter.

**Conversation**: One exchange with a customer: the lines they say, one at a time. A `Conversation` resource in the `Customer` file; `Game` plays the first one whose trigger and condition match.
*Avoid:* dialog, dialogue tree, script.

**Dialogue tab**: The editor tab (`addons/dialogue_editor/`) that lists every customer and edits their conversations.
*Avoid:* admin UI, dialogue tool, dialogue editor.

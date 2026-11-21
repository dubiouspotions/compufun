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

**View**: A fixed point of view in a room, such as Main, Left, Right, or a close-up (Workview, Screen, CompufunDB). In the scene it is a `ViewMarker` node with the view's name.
*Avoid:* camera, room view, screen.

**Hotspot**: A thing in a room that the player clicks (`rooms/hotspot.tscn`).
*Avoid:* button, clickable, interactable.

**Post-it**: The repair ticket on the customer's computer: the perceived issue and the Done box.
*Avoid:* ticket, note.

**CompufunDB**: The database on the work computer that maps a set of symptoms to the repair steps. It lists every `Problem` file.
*Avoid:* Company Database, BBS, database.

**Screen buffer**: The 1280 x 960 viewport that runs the Win95 desktop. The 3D monitor and the Screen View both show it.
*Avoid:* desktop viewport, screen texture.

**Win95 setup**: The `Win95Setup` resource of one customer's computer: what the Win95 desktop looks like and holds when it boots. `ComputerState` holds the running copy.
*Avoid:* computer config, Windows config, desktop data.

**Report**: One F9 feedback report: a folder in `feedback/` with `shot.png` and `report.json`.
*Avoid:* ticket, bug report, feedback file.

**Prop**: A placeholder model scene in `Godot/props/`, such as `crt_monitor.tscn`. A room places props; it does not copy their parts.
*Avoid:* asset, model, object.

**Outside**: The world outside the shop windows (`rooms/shop/outside.tscn`): the back alley, the sky, the sun and moon, the lamps, the fog and the rain. It runs the time of day.
*Avoid:* street, environment, weather system.

**Debug menu**: The F2 panel in debug builds that sets the time of day, the day cycle and the rain.
*Avoid:* dev menu, cheat menu.

**Conversation**: One exchange with a customer: the lines they say, then the replies the player picks. A `Conversation` resource in the `Customer` file, found by its id (`arrive`).
*Avoid:* dialog, dialogue tree, script.

**Dialogue tab**: The editor tab (`addons/dialogue_editor/`) that lists every customer and edits their conversations.
*Avoid:* admin UI, dialogue tool, dialogue editor.

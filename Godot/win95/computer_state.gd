class_name ComputerState
extends Node
## The live Win95 state of one job's computer. ScreenView makes one desktop per job, at the job's
## first connection, and keeps it while the cable is on another computer. Its setup is the
## computer's running copy from Game.setup_for, which outlives this node: a power cycle or a return
## visit keeps the player's changes. It follows the job's power.

## The power came on, or the computer rebooted. [member setup] is ready: rebuild everything from it.
signal booted
## Windows starts to hang, as an overheating computer does; it reboots [param seconds] later.
signal hanging(seconds: float)
## The power went off.
signal powered_off
## Windows shut down (Start > Shut Down). The power stays on, and only a power cycle boots it again.
signal shut_down_done
## A setter changed [member setup]; re-read what you show.
signal changed

const _NEW_FOLDER_ICON := preload("res://win95/theme/icons/folder_closed_32.png")
const _SYSTEM_PATH := "C:\\WINDOWS\\SYSTEM"
const _PROGRAM_FILES_PATH := "C:\\Program Files"
const _START_MENU_PATH := "C:\\WINDOWS\\Start Menu"

## The running copy; null when the computer has no Win95 setup. Change it only through the setters
## here, so that Game hears whether the problem is fixed.
var setup: Win95Setup
var is_on: bool = false
## The job whose computer this is. Set once, before the node enters the tree.
var job: Job

## Counts boots, so that a hang timer from an earlier boot does nothing.
var _boots: int = 0
## The boot whose desktop stayed up for the problem's hangs_after seconds; -1 for none.
var _stayed_up: int = -1


func _ready() -> void:
	if job != null:
		setup = Game.setup_for(job)
		_report_fixed()
	Game.changed.connect(_sync)
	Game.changed.connect(_report_tested)
	_sync()


func set_sound(volume: float, muted: bool) -> void:
	if setup == null or (setup.volume == volume and setup.muted == muted):
		return
	setup.volume = volume
	setup.muted = muted
	_changed()


## Sets each Win95Setup property in [param values] (property name to value) and reports once, as
## a property sheet's Apply does. A name that Win95Setup lacks is a programmer error, and then
## nothing changes.
func apply_settings(values: Dictionary[StringName, Variant]) -> void:
	if setup == null:
		return
	for property in values:
		if not property in setup:
			push_error("ComputerState.apply_settings: Win95Setup has no setting %s" % property)
			return
	var any := false
	for property in values:
		if setup.get(property) != values[property]:
			setup.set(property, values[property])
			any = true
	if any:
		_changed()


## The Control Panel's icons: the applets of every file in C:\WINDOWS\SYSTEM whose name ends in
## .CPL, sorted by name as Win95 lists them.
func control_panel() -> Array[Applet]:
	var applets: Array[Applet] = []
	var system := setup.file_at(_SYSTEM_PATH) if setup != null else null
	if system == null:
		return applets
	for file: Win95File in system.children:
		if not file.is_folder and file.name.get_extension().to_lower() == "cpl":
			applets.append_array(file.applets)
	applets.sort_custom(func(a: Applet, b: Applet) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return applets


## The programs that Add/Remove Programs lists: the folders in C:\Program Files, by name.
func removable_programs() -> Array[Win95File]:
	var found: Array[Win95File] = []
	var program_files := setup.file_at(_PROGRAM_FILES_PATH) if setup != null else null
	if program_files != null:
		for file: Win95File in program_files.children:
			if file.is_folder:
				found.append(file)
	found.sort_custom(func(a: Win95File, b: Win95File) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return found


## Removes [param folder], one of [method removable_programs], for good, with every shortcut in the
## Start Menu that points into it, as an uninstaller does.
func uninstall(folder: Win95File) -> void:
	var program_files := setup.file_at(_PROGRAM_FILES_PATH) if setup != null else null
	if program_files == null or not program_files.children.has(folder):
		push_error("ComputerState.uninstall: %s is not in %s" % [folder.name, _PROGRAM_FILES_PATH])
		return
	var inside := (_PROGRAM_FILES_PATH + "\\" + folder.name + "\\").to_lower()
	program_files.children.erase(folder)
	var start_menu := setup.file_at(_START_MENU_PATH)
	if start_menu != null:
		_remove_shortcuts(start_menu.children, inside)
	_changed()


func _remove_shortcuts(container: Array, inside: String) -> void:
	for i in range(container.size() - 1, -1, -1):
		var file: Win95File = container[i]
		if file.is_folder:
			_remove_shortcuts(file.children, inside)
		elif file.target.to_lower().begins_with(inside):
			container.remove_at(i)


## This computer's clock: the game's date and the real time of day, moved by the setup's
## clock_offset_seconds. A Time datetime dictionary, weekday included.
func now() -> Dictionary:
	var offset := setup.clock_offset_seconds if setup != null else 0
	return Time.get_datetime_dict_from_unix_time(_game_unix() + offset)


## The clock_offset_seconds that makes [method now] show [param t], a Time datetime dictionary.
func offset_for(t: Dictionary) -> int:
	return Time.get_unix_time_from_datetime_dict(t) - _game_unix()


func _game_unix() -> int:
	var t: Dictionary = Game.date
	t.merge(Time.get_time_dict_from_system(), true)
	return Time.get_unix_time_from_datetime_dict(t)


func rename_file(file: Win95File, new_name: String) -> void:
	if setup == null or file.name == new_name:
		return
	file.name = new_name
	_changed()


## Saves [param text] as the contents of [param file], as Notepad's File > Save does.
func write_text(file: Win95File, text: String) -> void:
	if setup == null or file.contents == text:
		return
	file.contents = text
	_stamp(file)
	_changed()


## Saves [param image] as the picture of [param file], as Paint's File > Save does. Keeps a copy, so
## later strokes on [param image] stay unsaved.
func write_picture(file: Win95File, image: Image) -> void:
	if setup == null:
		return
	file.picture = ImageTexture.create_from_image(image.duplicate())
	_stamp(file)
	_changed()


## Puts [param file] first in the Start menu's Documents, as opening a document does in Win95,
## which lists 15.
func note_opened(file: Win95File) -> void:
	if setup == null:
		return
	setup.recent_documents.erase(file)
	setup.recent_documents.push_front(file)
	setup.recent_documents.resize(mini(setup.recent_documents.size(), 15))


## Marks [param email] read, as opening it in Exchange does.
func mark_read(email: Email) -> void:
	if setup == null or email.read:
		return
	email.read = true
	_changed()


## Moves [param email] to [param folder], as Exchange's Delete moves it to Deleted Items.
func move_email(email: Email, folder: Email.Folder) -> void:
	if setup == null or email.folder == folder:
		return
	email.folder = folder
	_changed()


## Removes [param email] for good, as deleting it from Deleted Items does.
func purge_email(email: Email) -> void:
	if setup == null or not setup.emails.has(email):
		return
	setup.emails.erase(email)
	_changed()


## Moves [param files] into the Recycle Bin, and remembers where each came from.
func delete_files(files: Array[Win95File]) -> void:
	if setup == null or files.is_empty():
		return
	for file in files:
		var from: Variant = _container_of(file)
		if from == null:
			push_error("ComputerState.delete_files: %s is not on the desktop or drive C" % file.name)
			continue
		(from as Array).erase(file)
		setup.deleted_from[file] = from
		setup.recycle_bin.append(file)
	_changed()


## Puts [param files] from the Recycle Bin back where they were deleted from; files that the setup
## put in the bin go to the desktop.
func restore_files(files: Array[Win95File]) -> void:
	if setup == null or files.is_empty():
		return
	for file in files:
		if not setup.recycle_bin.has(file):
			push_error("ComputerState.restore_files: %s is not in the Recycle Bin" % file.name)
			continue
		setup.recycle_bin.erase(file)
		var to: Array = setup.deleted_from.get(file, setup.desktop)
		to.append(file)
		setup.deleted_from.erase(file)
	_changed()


## Removes [param files] from the Recycle Bin for good.
func purge_files(files: Array[Win95File]) -> void:
	if setup == null or files.is_empty():
		return
	for file in files:
		setup.recycle_bin.erase(file)
		setup.deleted_from.erase(file)
	_changed()


func empty_recycle_bin() -> void:
	if setup != null:
		purge_files(setup.recycle_bin.duplicate())


## Moves [param files] into [param container] (the desktop, drive_c or a folder's children), as
## Cut and Paste or a drag do. [param places] says where each one stands on the desktop
## (Win95File.desktop_position); without it, a moved file lines up with the others. Returns why a
## file stayed where it was, as Win95 says it, or "" when all moved.
func move_files(files: Array[Win95File], container: Array, places: Array[Vector2] = []) -> String:
	if setup == null:
		return "Cannot move files: the computer is off."
	var refused := ""
	for i in files.size():
		var file := files[i]
		var from: Variant = _container_of(file)
		var why := ""
		var place := places[i] if i < places.size() else Vector2.ZERO
		if from == null:
			why = "Cannot move %s: Cannot find the specified file. Make sure you specify the correct path and filename." % file.name
		elif is_same(from, container):
			if i < places.size():
				file.desktop_position = place
			continue
		elif file.is_folder and _holds(file.children, container):
			why = "Cannot move %s: The destination folder is a subfolder of the source folder." % file.name
		elif container.any(func(other: Win95File) -> bool: return other.name.nocasecmp_to(file.name) == 0):
			why = "Cannot move %s: There is already a file with the same name in this location." % file.name
		if why != "":
			if refused == "":
				refused = why
			continue
		(from as Array).erase(file)
		container.append(file)
		file.desktop_position = place
	_changed()
	return refused


# [param container] is [param children] or the children of a folder somewhere in it.
static func _holds(children: Array, container: Array) -> bool:
	if is_same(children, container):
		return true
	for file: Win95File in children:
		if file.is_folder and _holds(file.children, container):
			return true
	return false


## Adds an empty folder named "New Folder" (or "New Folder (2)", ...) to [param container]: the
## setup's desktop or drive_c, or a folder's children. Returns it.
func new_folder(container: Array) -> Win95File:
	var taken := {}
	for file: Win95File in container:
		taken[file.name] = true
	var folder := Win95File.new()
	folder.name = "New Folder"
	var n := 2
	while taken.has(folder.name):
		folder.name = "New Folder (%d)" % n
		n += 1
	folder.icon = _NEW_FOLDER_ICON
	folder.is_folder = true
	container.append(folder)
	_changed()
	return folder


## The installed programs: program files on drive C, at any depth, whose names end in .EXE or
## .COM, as Win95 runs only those.
func installed_programs() -> Array[Win95File]:
	var found: Array[Win95File] = []
	if setup != null:
		_collect_programs(setup.drive_c, func(file: Win95File) -> bool: return is_runnable(file), found)
	return found


## The program files on drive C whose app opens files with [param extension] (lower case, no dot),
## installed or not: a program file that lost its .EXE still claims its files.
func programs_for(extension: String) -> Array[Win95File]:
	var found: Array[Win95File] = []
	if setup != null and extension != "":
		_collect_programs(setup.drive_c, func(file: Win95File) -> bool: return opens_of(file.program).has(extension), found)
	return found


## True when [param file] is a program file that Win95 would run: it has a program, and its name
## ends in .EXE or .COM.
static func is_runnable(file: Win95File) -> bool:
	return file.program != null and is_program_name(file.name)


## True when Win95 would run a file named [param file_name]: it ends in .EXE or .COM.
static func is_program_name(file_name: String) -> bool:
	return file_name.get_extension().to_lower() in ["exe", "com"]


## The extensions that the app in [param program] opens: its root's `opens`, from the scene or
## else from the root script's default. Read without making the app.
static func opens_of(program: PackedScene) -> Array:
	var state := program.get_state()
	var script: Script
	for i in state.get_node_property_count(0):
		var property := state.get_node_property_name(0, i)
		if property == &"opens":
			return state.get_node_property_value(0, i)
		if property == &"script":
			script = state.get_node_property_value(0, i)
	if script == null:
		return []
	var opens: Variant = script.get_property_default_value(&"opens")
	return opens if opens is Array else []


## Where [param file] is, as Properties shows it: "Desktop", "C:\", "C:\WINDOWS" or "Recycle Bin".
func location_of(file: Win95File) -> String:
	if setup.desktop.has(file):
		return "Desktop"
	if setup.recycle_bin.has(file):
		return "Recycle Bin"
	var path: Variant = _folder_path(setup.drive_c, file, "C:")
	return path if path != null else "C:\\"


## Where [param file] in the Recycle Bin was deleted from, as its Original Location column shows
## it: "C:\WINDOWS\Desktop", "C:\" or "C:\WINDOWS". The setup's own bin files came from the desktop.
func original_location(file: Win95File) -> String:
	var from: Array = setup.deleted_from.get(file, setup.desktop)
	if is_same(from, setup.desktop):
		return "C:\\WINDOWS\\Desktop"
	var folder := _folder_holding(setup.drive_c, from)
	return path_of(folder) if folder != null else "C:\\"


# The folder whose children are [param children], by identity: two empty folders are equal Arrays.
func _folder_holding(container: Array, children: Array) -> Win95File:
	for other: Win95File in container:
		if other.is_folder:
			if is_same(other.children, children):
				return other
			var found := _folder_holding(other.children, children)
			if found != null:
				return found
	return null


func _folder_path(container: Array, file: Win95File, path: String) -> Variant:
	if container.has(file):
		return path + "\\" if path == "C:" else path
	for other: Win95File in container:
		if other.is_folder:
			var found: Variant = _folder_path(other.children, file, path + "\\" + other.name)
			if found != null:
				return found
	return null


## The full path of [param file], as Notepad names it: "C:\WINDOWS\Desktop\todo.txt".
func path_of(file: Win95File) -> String:
	var location := location_of(file)
	if location == "Desktop":
		location = "C:\\WINDOWS\\Desktop"
	return location.trim_suffix("\\") + "\\" + file.name


func _collect_programs(container: Array, wanted: Callable, found: Array[Win95File]) -> void:
	for file: Win95File in container:
		if file.is_folder:
			_collect_programs(file.children, wanted, found)
		elif file.program != null and wanted.call(file):
			found.append(file)


## The Array that holds [param file] (the desktop, drive C or a folder's children), or null.
func _container_of(file: Win95File) -> Variant:
	for top: Array in [setup.desktop, setup.drive_c]:
		var found: Variant = _find_container(top, file)
		if found != null:
			return found
	return null


func _find_container(container: Array, file: Win95File) -> Variant:
	if container.has(file):
		return container
	for other: Win95File in container:
		if other.is_folder:
			var found: Variant = _find_container(other.children, file)
			if found != null:
				return found
	return null


## Shuts Windows down: the running boot ends, with its hang and its test (see
## [method reached_desktop]), and [signal shut_down_done] fires. The power stays on, so the computer
## boots again only after its power button turns it off and on. Does nothing while it is off.
func shut_down() -> void:
	if not is_on:
		return
	_boots += 1
	shut_down_done.emit()


## Restarts the computer: Windows shuts down, and [param wait_seconds] later the power goes off,
## then [param off_seconds] later on again, through Game.set_powered as the power button does. It
## stops where the player switches the power or takes the job off the counter meanwhile. Does
## nothing while it is off.
func restart(wait_seconds: float, off_seconds: float) -> void:
	if not is_on:
		return
	shut_down()
	var boot := _boots
	await get_tree().create_timer(wait_seconds).timeout
	if not _still_on(boot):
		return
	Game.set_powered(job, false)
	await get_tree().create_timer(off_seconds).timeout
	if boot == _boots and not job.powered and job in Game.jobs:
		Game.set_powered(job, true)


func _sync() -> void:
	var on := setup != null and job.powered
	if on == is_on:
		return
	is_on = on
	if on:
		_boots += 1
		booted.emit()
	else:
		setup.defragmenting = false  # switching off stops the run
		powered_off.emit()


## The desktop appeared after a boot. A problem that hangs Windows starts counting: the computer
## hangs, then reboots, and does it again after every boot until the hardware is fixed. A desktop
## that stays up that long tests the computer (see [member Job.tested]).
func reached_desktop() -> void:
	var problem := job.problem
	var boot := _boots
	var hangs := problem.hangs_after > 0.0 and not job.hardware_fixed
	if problem.hangs_after > 0.0:
		await get_tree().create_timer(problem.hangs_after).timeout
		if not _still_on(boot):
			return
	if not hangs or job.hardware_fixed:
		_stayed_up = boot
		_report_tested()
		return
	hanging.emit(problem.hang_seconds)
	await get_tree().create_timer(problem.hang_seconds).timeout
	if _still_on(boot):  # hung is hung, also if the fan was fixed meanwhile
		_boots += 1
		booted.emit()


func _still_on(boot: int) -> bool:
	return boot == _boots and is_on and job in Game.jobs


func _report_tested() -> void:
	if _still_on(_stayed_up) and job.fixed and not job.tested:
		Game.set_tested(job)


## Starts Disk Defragmenter on drive C. It finishes overnight while the computer stays on.
func start_defrag() -> void:
	if setup == null or setup.defragmenting:
		return
	setup.defragmenting = true
	_changed()


func _stamp(file: Win95File) -> void:
	var t := now()
	file.modified = "%s %s" % [Win95Time.long_date(t), Win95Time.clock(t, true)]


func _changed() -> void:
	changed.emit()
	_report_fixed()


func _report_fixed() -> void:
	if setup != null and job.problem.software_check != null:
		Game.set_software_fixed(job, job.problem.software_check.is_fixed(setup))

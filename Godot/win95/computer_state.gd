class_name ComputerState
extends Node
## The live Win95 state of one job's computer. ScreenView makes one desktop per job, at the job's
## first connection, and keeps it while the cable is on another computer. Its setup is the
## computer's running copy from Game.setup_for, which outlives this node: a power cycle or a return
## visit keeps the player's changes. It follows the job's power.

## The power came on. [member setup] is ready: rebuild everything from it.
signal booted
## The power went off.
signal powered_off
## A setter changed [member setup]; re-read what you show.
signal changed

const _NEW_FOLDER_ICON := preload("res://win95/theme/icons/folder_closed_32.png")

## The running copy; null when the computer has no Win95 setup. Change it only through the setters
## here, so that Game hears whether the problem is fixed.
var setup: Win95Setup
var is_on: bool = false
## The job whose computer this is. Set once, before the node enters the tree.
var job: Job


func _ready() -> void:
	if job != null:
		setup = Game.setup_for(job)
		_report_fixed()
	Game.changed.connect(_sync)
	_sync()


func set_sound(volume: float, muted: bool) -> void:
	if setup == null or (setup.volume == volume and setup.muted == muted):
		return
	setup.volume = volume
	setup.muted = muted
	_changed()


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
	_changed()


## Saves [param image] as the picture of [param file], as Paint's File > Save does. Keeps a copy, so
## later strokes on [param image] stay unsaved.
func write_picture(file: Win95File, image: Image) -> void:
	if setup == null:
		return
	file.picture = ImageTexture.create_from_image(image.duplicate())
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
	return file.program != null and file.name.get_extension().to_lower() in ["exe", "com"]


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


func _sync() -> void:
	var on := setup != null and job.powered
	if on == is_on:
		return
	is_on = on
	if on:
		booted.emit()
	else:
		powered_off.emit()


func _changed() -> void:
	changed.emit()
	_report_fixed()


func _report_fixed() -> void:
	if setup != null and job.problem.software_check != null:
		Game.set_software_fixed(job, job.problem.software_check.is_fixed(setup))

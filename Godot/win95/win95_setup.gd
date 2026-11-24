class_name Win95Setup
extends Resource
## The Win95 desktop that one customer's computer boots into. This is the starting state; at
## runtime, Game.setup_for makes the running copy that ComputerState changes, never this resource.

## The folder whose items Windows opens each time a boot reaches the desktop.
const STARTUP_PATH := "C:\\WINDOWS\\Start Menu\\Programs\\StartUp"
const _PROGRAMS_PATH := "C:\\WINDOWS\\Start Menu\\Programs"
const _PROGRAM_FILES_PATH := "C:\\Program Files"
## The shortcuts that every desktop gets after the customer's own icons, each while its program is
## installed and the desktop and Recycle Bin hold no shortcut to it yet.
const _DESKTOP_SHORTCUTS: Array[Win95File] = [
	preload("res://win95/office/word_shortcut.tres"),
	preload("res://win95/office/excel_shortcut.tres"),
]

## "Windows theme": the system colours. The default is the stock Win95 palette.
@export var palette: Win95Palette = preload("res://win95/theme/palette.tres")
## Null shows only [member desktop_color].
@export var wallpaper: Texture2D = preload("res://win95/wallpapers/win95-default.png")
## The colour of the desktop around and under the wallpaper; Win95's teal by default.
@export var desktop_color: Color = Color(0, 0.5019608, 0.5019608)
## Display > Screen Saver: the screensaver by the name that the list shows, such as "3D Pipes";
## empty for none.
@export var screensaver: String = ""
## The icons on the desktop, in the order that they appear. The running copy puts Win95's own
## icons first (Win95File.system), so they move and hide like files, and the shortcuts to Word and
## Excel last.
@export var desktop: Array[Win95File] = []
## The top folder of drive C.
@export var drive_c: Array[Win95File] = []
## The files in the Recycle Bin. Restoring one of these puts it on the desktop.
@export var recycle_bin: Array[Win95File] = []
## Drive C is fragmented: Windows boots slower and folders take seconds to open, until a Disk
## Defragmenter run finishes (see [member defrag_days]).
@export var fragmented: bool = false
## A Disk Defragmenter run on a fragmented drive finishes at this many [member defrag_daypart]s after
## it started (1: the next one), or as the computer next comes on after that.
@export var defrag_days: int = 1
## The daypart that a run finishes at, one of CallOuts.DAYPARTS, such as &"afternoon".
@export var defrag_daypart: StringName = &"afternoon"
## Disk Defragmenter is running on a fragmented drive. Only while the game runs.
var defragmenting: bool = false
## The day number and the Game.Daypart that the running Disk Defragmenter started on; Game.defrag_finish
## and Game.defrag_progress follow from them. Only while the game runs.
var defrag_started_day: int = 0
var defrag_started_daypart: int = 0
## Where each file in the Recycle Bin was deleted from: the desktop, drive_c or a folder's
## children. Only while the game runs.
var deleted_from: Dictionary[Win95File, Array] = {}
## The documents that the player opened, newest first, as the Start menu's Documents lists them.
## Only while the game runs.
var recent_documents: Array[Win95File] = []
## The screenshot that the desktop prank (DesktopPrankCheck) set as the wallpaper, or null. Only
## while the game runs.
var desktop_screenshot: DesktopScreenshot
## The errands whose setup patches (SetupPatch) this running copy has, by file name. Only while the
## game runs.
var patched: PackedStringArray = []
## Every email in every folder; each Email says which folder it is in.
@export var emails: Array[Email] = []
## The programs that the Start menu lists, by their name in the menu.
@export var installed_apps: PackedStringArray = []
## Shortcuts and folders that this computer's own programs put in the Start menu's Programs, on top
## of the stock ones in C:\WINDOWS\Start Menu\Programs; the running copy adds them there. A folder
## named like one there, such as StartUp, adds its items to that one.
@export var start_menu_programs: Array[Win95File] = []
## Program folders that setup programs installed in C:\Program Files, such as the stock Microsoft
## Office (win95/office/office97.tres); the running copy adds them there, making the folder if it
## is missing.
@export var program_files: Array[Win95File] = []
## The documents that the customer opened last, newest first, by path, such as
## "C:\My Documents\Invitation.doc": the running copy's [member recent_documents] start with them.
@export var recently_opened: PackedStringArray = []
## Dial-Up Networking: the connection that AutoDial dials when a program goes online, by its name
## in the Connect To dialog, such as the provider's; empty for none, and programs then fail at once.
## At the customer's home it dialled; on the bench the modem has no phone line.
@export var dial_up_name: String = ""
## The user name and phone number that Connect To shows for [member dial_up_name].
@export var dial_up_user: String = ""
@export var dial_up_number: String = ""

@export_group("Sound")
## 0 to 100, as the tray volume slider shows it.
@export_range(0, 100) var volume: float = 75.0
@export var muted: bool = false

@export_group("Mouse")
## Mouse > Buttons: the left and right buttons swap.
@export var left_handed: bool = false
## Mouse > Buttons: the longest gap between the two clicks of a double-click, in milliseconds.
@export_range(100, 900) var double_click_ms: int = 500
## Mouse > Motion: 0 draws no trail; 1 to 7, from short to long, draws that many ghost pointers.
@export_range(0, 7) var pointer_trails: int = 0
## Mouse > Motion: the pointer speed slider, 0 (slow) to 6 (fast). Saved; the pointer moves as before.
@export_range(0, 6) var pointer_speed: int = 3

@export_group("Clock")
## How far this computer's clock is ahead of the game's time, in seconds; negative is behind.
## Date/Time sets it, and the taskbar clock and file dates read it (ComputerState.now()).
@export var clock_offset_seconds: int = 0

@export_group("CMOS")
## What BIOS Setup's BIOS FEATURES SETUP page keeps: a feature id of BiosSetup.FEATURES to the index
## of its option. A missing id is the feature's default; BiosSetup.value() reads it.
@export var cmos: Dictionary[StringName, int] = {}

@export_group("System")
## What System > General shows under "Microsoft Windows 95", for example "4.00.950".
@export var version: String = "4.00.950"
## System > General, "Registered to": the owner, the organisation and the product ID. An empty
## owner shows the customer's display_name.
@export var registered_owner: String = ""
@export var registered_organization: String = ""
@export var product_id: String = "12345-OEM-0012345-12345"
## System > General, "Computer": the processor and the memory.
@export var processor: String = "Pentium(r)"
@export var memory_mb: int = 16

@export_group("Drives")
## A floppy is in drive A:. The PC tries to boot from it and stops on "Non-System disk or disk
## error", so Windows does not start until the floppy is out.
@export var floppy_in_a: bool = false
## The disk in drive A: while [member floppy_in_a]; null for the boot floppy that a problem puts
## there. Only while the game runs.
var floppy_disk: FloppyDisk
## The files on the disk in A:, this computer's own copies; empty while A: is empty. Only while the
## game runs.
var floppy_files: Array[Win95File] = []


## A copy to run: every file and folder is the copy's own, also the ones that came from another
## .tres, such as the stock Start Menu folder. duplicate_deep() alone shares those. Files with a
## contents_file hold its text, and Start Menu\Programs holds [member start_menu_programs].
func copy() -> Win95Setup:
	var running := duplicate_deep() as Win95Setup
	for files: Array in [running.desktop, running.drive_c, running.recycle_bin, running.start_menu_programs, running.program_files]:
		_own(files)
	if not running.program_files.is_empty():
		var folder := running._program_files_folder()
		if folder != null:
			_merge(folder.children, running.program_files)
		running.program_files.clear()  # drive C holds them now
	if not running.start_menu_programs.is_empty():
		var programs := running.file_at(_PROGRAMS_PATH)
		if programs == null:
			push_error("Win95Setup: no %s folder, so the Start menu misses %s" % [_PROGRAMS_PATH, running.start_menu_programs.map(func(file: Win95File) -> String: return file.name)])
		else:
			_merge(programs.children, running.start_menu_programs)
		running.start_menu_programs.clear()  # the folder holds them now; a copy of this copy mustn't add them twice
	running._add_desktop_shortcuts()
	for path in running.recently_opened:
		var document := running.file_at(path)
		if document == null:
			push_error("Win95Setup: recently_opened names %s, which isn't on the desktop or drive C" % path)
		else:
			running.recent_documents.append(document)
	running._add_system_icons()
	return running


func _add_desktop_shortcuts() -> void:
	for shortcut in _DESKTOP_SHORTCUTS:
		var linked := func(file: Win95File) -> bool: return file.target.nocasecmp_to(shortcut.target) == 0
		if file_at(shortcut.target) != null and not desktop.any(linked) and not recycle_bin.any(linked):
			desktop.append(shortcut.duplicate_deep())


# Adds [param items] to [param container]; a folder named like one in the container adds its items
# to that one instead.
static func _merge(container: Array, items: Array) -> void:
	for item: Win95File in items:
		var same: Win95File = null
		for existing: Win95File in container:
			if item.is_folder and existing.is_folder and existing.name.nocasecmp_to(item.name) == 0:
				same = existing
		if same != null:
			_merge(same.children, item.children)
		else:
			container.append(item)


# C:\Program Files, made when the drive has none; null, with an error, when a file has its name.
func _program_files_folder() -> Win95File:
	var folder := file_at(_PROGRAM_FILES_PATH)
	if folder == null:
		folder = Win95File.new()
		folder.name = "Program Files"
		folder.icon = preload("res://win95/theme/icons/folder_closed_32.png")
		folder.is_folder = true
		drive_c.append(folder)
	elif not folder.is_folder:
		push_error("Win95Setup: %s is a file, so %s can't be installed" % [_PROGRAM_FILES_PATH, program_files.map(func(file: Win95File) -> String: return file.name)])
		return null
	return folder


# Each icon of desktop_icons.tscn that the setup doesn't hold yet, in the scene's order. Loaded,
# not preloaded: the scene's windows use this script.
func _add_system_icons() -> void:
	var state := (load("res://win95/desktop_icons.tscn") as PackedScene).get_state()
	var added: Array[Win95File] = []
	for node in range(1, state.get_node_count()):
		var icon := Win95File.new()
		icon.system = state.get_node_name(node)
		for i in state.get_node_property_count(node):
			match state.get_node_property_name(node, i):
				&"text":
					icon.name = state.get_node_property_value(node, i)
				&"icon":
					icon.icon = state.get_node_property_value(node, i)
		if not _holds_system(desktop, icon.system) and not _holds_system(recycle_bin, icon.system):
			added.append(icon)
	for i in added.size():
		desktop.insert(i, added[i])


static func _holds_system(files: Array, system: StringName) -> bool:
	for file: Win95File in files:
		if file.system == system or _holds_system(file.children, system):
			return true
	return false


static func _own(files: Array) -> void:
	for i in files.size():
		var file: Win95File = files[i]
		if file.resource_path != "" and not file.resource_path.contains("::"):
			file = file.duplicate_deep()
			files[i] = file
		if file.contents_file != "":
			_read_contents(file)
		_own(file.children)


static func _read_contents(file: Win95File) -> void:
	var text := FileAccess.get_file_as_string(file.contents_file)
	var err := FileAccess.get_open_error()
	if err != OK:
		push_error("Win95Setup: couldn't read %s for %s: %s" % [file.contents_file, file.name, error_string(err)])
		return
	file.contents = text


## The owner's mail address: the sender of a sent mail, else the recipient of a received one, else
## [member registered_owner]; "" with none.
func own_address() -> String:
	for mail: Email in emails:
		if mail.folder in [Email.Folder.SENT, Email.Folder.OUTBOX] and mail.from != "":
			return mail.from
	for mail: Email in emails:
		if mail.folder == Email.Folder.INBOX and mail.to != "":
			return mail.to
	return registered_owner


## Every address on the mails, From and To, sorted, each once.
func addresses() -> PackedStringArray:
	var found := {}
	for mail: Email in emails:
		for address: String in [mail.from, mail.to]:
			if address != "":
				found[address] = true
	var sorted := PackedStringArray(found.keys())
	sorted.sort()
	return sorted


## Becomes [param other], a running copy too: every field, also the runtime ones.
func take(other: Win95Setup) -> void:
	for property: Dictionary in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(property.name, other.get(property.name))


## Puts [param disk] in drive A:, with copies of its files that the computer changes from now on,
## never the FloppyDisk resource.
func insert_floppy(disk: FloppyDisk) -> void:
	floppy_in_a = true
	floppy_disk = disk
	floppy_files.clear()
	for file: Win95File in disk.files:
		floppy_files.append(file.duplicate_deep())
	_own(floppy_files)


## Empties drive A:.
func eject_floppy() -> void:
	floppy_in_a = false
	floppy_disk = null
	floppy_files.clear()


## Deletes for good, from the desktop and drive C at any depth, every file that [param doomed] (a
## [code]func(file: Win95File) -> bool[/code]) holds true for, and every shortcut in the StartUp
## folder whose target is such a file, as an antivirus cleans a virus off. Running tasks are the
## caller's to end. Returns how many files it deleted, shortcuts not counted.
func remove_files(doomed: Callable) -> int:
	var startup := file_at(STARTUP_PATH)
	if startup != null:
		startup.children.assign(startup.children.filter(func(item: Win95File) -> bool:
			var target := file_at(item.target) if item.target != "" else null
			return target == null or not doomed.call(target)))
	return _remove_from(desktop, doomed) + _remove_from(drive_c, doomed)


static func _remove_from(container: Array, doomed: Callable) -> int:
	var removed := 0
	for i in range(container.size() - 1, -1, -1):
		var file: Win95File = container[i]
		if doomed.call(file):
			container.remove_at(i)
			removed += 1
		else:
			removed += _remove_from(file.children, doomed)
	return removed


## The file or folder at [param path], or null. The path starts at drive C or the desktop, with
## backslashes, and ignores case as Win95 does: "C:\WINDOWS\SYSTEM.INI", "Desktop\todo.txt".
func file_at(path: String) -> Win95File:
	var parts := path.split("\\", false)
	if parts.is_empty():
		return null
	var top := parts[0].to_lower()
	var container: Array = drive_c if top == "c:" else desktop if top == "desktop" else []
	var found: Win95File
	for i in range(1, parts.size()):
		found = null
		for file: Win95File in container:
			if file.name.nocasecmp_to(parts[i]) == 0:
				found = file
				break
		if found == null:
			return null
		container = found.children
	return found

class_name Win95Setup
extends Resource
## The Win95 desktop that one customer's computer boots into. This is the starting state; at
## runtime, Game.setup_for makes the running copy that ComputerState changes, never this resource.

## The folder whose items Windows opens each time a boot reaches the desktop.
const STARTUP_PATH := "C:\\WINDOWS\\Start Menu\\Programs\\StartUp"

## "Windows theme": the system colours. The default is the stock Win95 palette.
@export var palette: Win95Palette = preload("res://win95/theme/palette.tres")
@export var wallpaper: Texture2D = preload("res://win95/wallpapers/win95-default.png")
## Display > Screen Saver: the screensaver by the name that the list shows, such as "3D Pipes";
## empty for none.
@export var screensaver: String = ""
## The icons on the desktop, in the order that they appear. The running copy puts Win95's own
## icons first (Win95File.system), so they move and hide like files.
@export var desktop: Array[Win95File] = []
## The top folder of drive C.
@export var drive_c: Array[Win95File] = []
## The files in the Recycle Bin. Restoring one of these puts it on the desktop.
@export var recycle_bin: Array[Win95File] = []
## Drive C is fragmented: Windows boots slower and folders take seconds to open, until Disk
## Defragmenter has run overnight.
@export var fragmented: bool = false
## Disk Defragmenter is running; it finishes overnight if the computer stays on. Only while the
## game runs.
var defragmenting: bool = false
## Where each file in the Recycle Bin was deleted from: the desktop, drive_c or a folder's
## children. Only while the game runs.
var deleted_from: Dictionary[Win95File, Array] = {}
## The documents that the player opened, newest first, as the Start menu's Documents lists them.
## Only while the game runs.
var recent_documents: Array[Win95File] = []
## The screenshot that the desktop prank (DesktopPrankCheck) set as the wallpaper, or null. Only
## while the game runs.
var desktop_screenshot: DesktopScreenshot
## Every email in every folder; each Email says which folder it is in.
@export var emails: Array[Email] = []
## The programs that the Start menu lists, by their name in the menu.
@export var installed_apps: PackedStringArray = []

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
## .tres, such as the stock Start Menu folder. duplicate_deep() alone shares those.
func copy() -> Win95Setup:
	var running := duplicate_deep() as Win95Setup
	for files: Array in [running.desktop, running.drive_c, running.recycle_bin]:
		_own(files)
	running._add_system_icons()
	return running


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
		_own(file.children)


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

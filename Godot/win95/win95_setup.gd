class_name Win95Setup
extends Resource
## The Win95 desktop that one customer's computer boots into. This is the starting state; at
## runtime, Game.setup_for makes the running copy that ComputerState changes, never this resource.

## "Windows theme": the system colours. The default is the stock Win95 palette.
@export var palette: Win95Palette = preload("res://win95/theme/palette.tres")
@export var wallpaper: Texture2D = preload("res://win95/wallpapers/win95-default.png")
## The icons on the desktop, in the order that they appear, after the system icons.
@export var desktop: Array[Win95File] = []
## The top folder of drive C.
@export var drive_c: Array[Win95File] = []
## The files in the Recycle Bin. Restoring one of these puts it on the desktop.
@export var recycle_bin: Array[Win95File] = []
## Where each file in the Recycle Bin was deleted from: the desktop, drive_c or a folder's
## children. Only while the game runs.
var deleted_from: Dictionary[Win95File, Array] = {}
## Every email in every folder; each Email says which folder it is in.
@export var emails: Array[Email] = []
## The programs that the Start menu lists, by their name in the menu.
@export var installed_apps: PackedStringArray = []

@export_group("Sound")
## 0 to 100, as the tray volume slider shows it.
@export_range(0, 100) var volume: float = 75.0
@export var muted: bool = false


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

class_name VirusCheck
extends SoftwareCheck
## A virus: the break puts its program file on drive C and a shortcut to it in the StartUp folder,
## so it runs at every boot. Fixed when no file on the desktop or drive C runs its program; the
## Recycle Bin doesn't count. While it runs, the file is in use, so the player ends its task first.

## The virus's program file, copied onto the computer: its name, icon and program (a
## BackgroundTask scene, such as win95/bizopp.tscn).
@export var virus: Win95File
## The folder on drive C that the copy goes in, such as "C:\WINDOWS".
@export var folder_path: String = "C:\\WINDOWS"
## The name of the shortcut in the StartUp folder.
@export var startup_name: String = "BizOpp"


func apply_break(setup: Win95Setup) -> void:
	if virus == null or virus.program == null:
		push_error("VirusCheck: %s has no virus file with a program to put on the computer" % resource_path)
		return
	var path := _path_of_virus(setup)
	if path == "":
		var folder := setup.file_at(folder_path)
		if folder == null or not folder.is_folder:
			push_error("VirusCheck: the computer has no folder %s to put %s in" % [folder_path, virus.name])
			return
		folder.children.append(virus.duplicate())
		path = folder_path + "\\" + virus.name
	var startup := setup.file_at(Win95Setup.STARTUP_PATH)
	if startup == null:
		push_error("VirusCheck: the computer has no %s to start %s from" % [Win95Setup.STARTUP_PATH, virus.name])
		return
	if startup.children.any(func(item: Win95File) -> bool: return item.name.nocasecmp_to(startup_name) == 0):
		return
	var shortcut := Win95File.new()
	shortcut.name = startup_name
	shortcut.icon = virus.icon
	shortcut.target = path
	startup.children.append(shortcut)


## Deletes every copy of the virus, and each StartUp shortcut to one, for good.
func apply_fix(setup: Win95Setup) -> void:
	setup.remove_files(_is_virus)


func is_fixed(setup: Win95Setup) -> bool:
	return _path_of_virus(setup) == ""


## The copies of the virus on the desktop and drive C, at any depth.
func copies(setup: Win95Setup) -> Array[Win95File]:
	var found: Array[Win95File] = []
	for top: Array in [setup.desktop, setup.drive_c]:
		_collect(top, found)
	return found


func _is_virus(file: Win95File) -> bool:
	return virus != null and file.program != null and file.program == virus.program


func _collect(container: Array, found: Array[Win95File]) -> void:
	for file: Win95File in container:
		if _is_virus(file):
			found.append(file)
		_collect(file.children, found)


# The path of the first copy, such as "C:\WINDOWS\BIZOPP.EXE", or "" when there is none.
func _path_of_virus(setup: Win95Setup) -> String:
	for top: Array in [setup.desktop, setup.drive_c]:
		var found := _find(top, "Desktop" if is_same(top, setup.desktop) else "C:")
		if found != "":
			return found
	return ""


func _find(container: Array, path: String) -> String:
	for file: Win95File in container:
		if _is_virus(file):
			return path + "\\" + file.name
		var inside := _find(file.children, path + "\\" + file.name)
		if inside != "":
			return inside
	return ""

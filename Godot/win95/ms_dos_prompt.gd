extends "res://win95/window.gd"
## The MS-DOS Prompt: type a command and press Enter. DIR and CD walk drive_c; the rest are the
## few commands below. EXIT closes the window.

const BANNER: String = "Microsoft(R) Windows 95\n   (C)Copyright Microsoft Corp 1981-1995.\n\n"
const HELP: String = "CD       Changes the current directory.\nCLS      Clears the screen.\nDIR      Lists the files in a directory.\nECHO     Displays a message.\nEXIT     Closes the MS-DOS Prompt.\nHELP     Lists the commands.\nVER      Shows the Windows version."

## The top folder of drive C, as Win95Setup.drive_c holds it.
@export var drive_c: Array[Win95File] = []

## Everything on the screen above the prompt.
var _log: String = ""
## The folders from drive C's top down to the current one, by name.
var _path: PackedStringArray = ["WINDOWS"]

@onready var _output: Label = %Output
@onready var _prompt: Label = %Prompt
@onready var _command: LineEdit = %Command
@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	super()
	_log = BANNER
	_command.text_submitted.connect(_on_submitted)
	visibility_changed.connect(func() -> void:
		if visible:
			_command.grab_focus.call_deferred())
	_sync()


## Runs [param line] as if the player typed it, and returns what it printed.
func run(line: String) -> String:
	var words := line.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	var argument := " ".join(words.slice(1))
	match words[0].to_upper():
		"CLS":
			_log = ""
			return ""
		"DIR":
			return _dir()
		"CD", "CHDIR":
			return _cd(argument)
		"ECHO":
			return argument
		"VER":
			return "Windows 95. [Version 4.00.950]"
		"HELP":
			return HELP
		"EXIT":
			close()
			return ""
	return "Bad command or file name"


func _on_submitted(line: String) -> void:
	var said := "%s%s\n" % [_prompt.text, line]
	_command.clear()
	_log += said
	var printed := run(line)
	if printed != "":
		_log += printed + "\n"
	_sync()


func _dir() -> String:
	var lines: PackedStringArray = [" Volume in drive C has no label", " Directory of %s" % _where(), ""]
	var files := 0
	for file: Win95File in _folder():
		var parts := file.name.split(".")
		var extension := parts[1] if parts.size() > 1 else ""
		lines.append("%-8s %-3s  %s" % [parts[0], extension, "<DIR>" if file.is_folder else ""])
		files += 1
	lines.append("%9d file(s)" % files)
	return "\n".join(lines)


func _cd(argument: String) -> String:
	var target := argument.strip_edges().to_upper()
	if target == "":
		return _where()
	var path := _path.duplicate()
	if target.begins_with("\\"):
		path = []
	for step in target.split("\\", false):
		if step == "..":
			if not path.is_empty():
				path.remove_at(path.size() - 1)
			continue
		var found := _files_in(path).filter(func(f: Win95File) -> bool: return f.is_folder and f.name.to_upper() == step)
		if found.is_empty():
			return "Invalid directory"
		path.append(found[0].name)
	_path = path
	return ""


## The files in the current folder.
func _folder() -> Array:
	return _files_in(_path)


## The files in the folder at [param path], or [] when there is no such folder.
func _files_in(path: PackedStringArray) -> Array:
	var files: Array = drive_c
	for folder_name in path:
		var found := files.filter(func(f: Win95File) -> bool: return f.is_folder and f.name == folder_name)
		if found.is_empty():
			return []
		files = found[0].children
	return files


func _where() -> String:
	return "C:\\" + "\\".join(_path)


func _sync() -> void:
	_output.text = _log.trim_suffix("\n")
	_output.visible = _output.text != ""
	_prompt.text = _where() + ">"
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

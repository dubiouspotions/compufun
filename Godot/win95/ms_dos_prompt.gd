extends "res://win95/window.gd"
## The MS-DOS Prompt: type a command and press Enter. DIR, CD and TYPE walk the computer's drive
## C (drive_c here when the window isn't on a computer's desktop); the rest are the few commands
## below. EXIT closes the window. While it is the active window, the prompt has the
## focus with a blinking cursor and takes every key, so typing never reaches the game; Esc clears
## the line, as in DOS.

const BANNER: String = "Microsoft(R) Windows 95\n   (C)Copyright Microsoft Corp 1981-1995.\n\n"
const HELP: String = "CD       Changes the current directory.\nCLS      Clears the screen.\nDIR      Lists the files in a directory.\nECHO     Displays a message.\nEXIT     Closes the MS-DOS Prompt.\nHELP     Lists the commands.\nTYPE     Displays the contents of a text file.\nVER      Shows the Windows version."
## What DIR says is free on drive C.
const BYTES_FREE: int = 312885248

## The top folder of drive C when the window isn't on a computer's desktop, as in a scene preview.
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
	# The range changes once the new text is laid out, which can be a frame or more after _sync.
	_scroll.get_v_scroll_bar().changed.connect(_scroll_to_end)
	# Tab would move the focus out of the prompt.
	_command.focus_next = NodePath(".")
	_command.focus_previous = NodePath(".")
	# The field would swallow Esc before _unhandled_key_input sees it.
	_command.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			_command.clear()
			_command.accept_event())
	var desktop := get_parent() as Win95Desktop
	if desktop != null:
		desktop.windows_changed.connect(_sync_focus)
	_sync()
	_sync_focus.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_active():
		return
	get_viewport().set_input_as_handled()


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
		"TYPE":
			return _type(argument)
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


# As Win95 lists a folder: the short 8.3 name, the size or <DIR>, the date and the long name.
func _dir() -> String:
	var lines: PackedStringArray = [" Volume in drive C has no label", " Volume Serial Number is 1F2A-0C17", " Directory of %s" % _where(), ""]
	var files := 0
	var folders := 0
	var bytes := 0
	if not _path.is_empty():
		lines.append_array([_dir_line(".", "", true, 0, {}, "."), _dir_line("..", "", true, 0, {}, "..")])
		folders += 2
	var taken := {}
	for file: Win95File in _folder():
		var short := short_name(file.name, taken)
		var dot := short.find(".")
		var when := Win95Time.parse_long(file.modified) if file.modified != "" else {}
		lines.append(_dir_line(short.left(dot) if dot >= 0 else short, short.substr(dot + 1) if dot >= 0 else "", file.is_folder, file.size_in_bytes(), when, file.name))
		if file.is_folder:
			folders += 1
		else:
			files += 1
			bytes += file.size_in_bytes()
	lines.append("%9d file(s) %14s bytes" % [files, _grouped(bytes)])
	lines.append("%9d dir(s)  %14s bytes free" % [folders, _grouped(BYTES_FREE)])
	return "\n".join(lines)


func _dir_line(base: String, extension: String, is_folder: bool, size: int, when: Dictionary, long_name: String) -> String:
	var amount := "<DIR>       " if is_folder else "%12s" % _grouped(size)
	var date := ""
	if not when.is_empty():
		var hour: int = when.hour
		date = "%02d-%02d-%02d %2d:%02d%s" % [when.month, when.day, when.year % 100, (hour + 11) % 12 + 1, when.minute, "p" if hour >= 12 else "a"]
	return "%-8s %-3s %s  %-15s %s" % [base, extension, amount, date, long_name]


## The DOS name of [param long_name], as Win95 makes it: "TAXES1~1.TXT" for "taxes 1995.txt".
## [param taken] holds the short names already given in the folder and gets this one.
static func short_name(long_name: String, taken: Dictionary) -> String:
	var dot := long_name.rfind(".")
	var base := long_name.left(dot) if dot > 0 else long_name
	var extension := long_name.substr(dot + 1) if dot > 0 else ""
	var clean := func(text: String) -> String:
		var kept := ""
		for c in text.to_upper():
			if c != " " and c != ".":
				kept += c
		return kept
	var short_base: String = clean.call(base)
	var short_extension: String = clean.call(extension).left(3)
	if short_base.length() > 8 or short_base != base.to_upper() or extension.length() > 3:
		var n := 1
		while true:
			var candidate := "%s~%d" % [short_base.left(8 - 1 - str(n).length()), n]
			if not taken.has(candidate + "." + short_extension):
				short_base = candidate
				break
			n += 1
	var short := short_base + ("." + short_extension if short_extension != "" else "")
	taken[short] = true
	return short


static func _grouped(value: int) -> String:
	var text := str(value)
	for i in range(text.length() - 3, 0, -3):
		text = text.insert(i, ",")
	return text


# TYPE prints a text file, by its long or its short name.
func _type(argument: String) -> String:
	var wanted := argument.strip_edges().to_upper()
	if wanted == "":
		return "Required parameter missing"
	var taken := {}
	for file: Win95File in _folder():
		if not file.is_folder and (file.name.to_upper() == wanted or short_name(file.name, taken) == wanted):
			return file.contents.trim_suffix("\n")
	return "File not found - %s" % argument.strip_edges()


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
		var here := _files_in(path)
		var found := here.filter(func(f: Win95File) -> bool: return f.is_folder and (f.name.to_upper() == step or _short_in(here, f) == step))
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
	var desktop := get_parent() as Win95Desktop
	var computer := desktop.computer if desktop != null else null
	var files: Array = computer.setup.drive_c if computer != null and computer.setup != null else drive_c
	for folder_name in path:
		var found := files.filter(func(f: Win95File) -> bool: return f.is_folder and f.name == folder_name)
		if found.is_empty():
			return []
		files = found[0].children
	return files


## The prompt has the focus exactly while this is the desktop's active window.
func _sync_focus() -> void:
	if _is_active():
		if not _command.has_focus():
			_command.grab_focus()
	elif _command.has_focus():
		_command.release_focus()


func _is_active() -> bool:
	var desktop := get_parent() as Win95Desktop
	return is_visible_in_tree() and (desktop == null or desktop.active_window() == self)


# DOS shows the short names: C:\MYDOCU~1.
func _where() -> String:
	var shorts: PackedStringArray = []
	for depth in _path.size():
		var here := _files_in(_path.slice(0, depth))
		var found := here.filter(func(f: Win95File) -> bool: return f.is_folder and f.name == _path[depth])
		shorts.append(_short_in(here, found[0]) if not found.is_empty() else _path[depth].to_upper())
	return "C:\\" + "\\".join(shorts)


## The short name of [param file] among [param files], its folder, which numbers the ~1, ~2 in order.
static func _short_in(files: Array, file: Win95File) -> String:
	var taken := {}
	for other: Win95File in files:
		var short := short_name(other.name, taken)
		if other == file:
			return short
	return ""


func _sync() -> void:
	_output.text = _log.trim_suffix("\n")
	_output.visible = _output.text != ""
	_prompt.text = _where() + ">"


func _scroll_to_end() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

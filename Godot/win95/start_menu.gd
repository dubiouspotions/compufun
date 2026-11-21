extends ContextMenu
## The Start menu, as Win95's: the Windows95 banner; Programs, Documents, Settings, Find, Help,
## Run and Shut Down with large icons. Programs lists the shortcuts in C:\WINDOWS\Start Menu\
## Programs, folders as submenus, so a shortcut whose program was renamed stays and fails as in
## Win95. Documents lists the documents opened lately. Opens above its parent, the Start button,
## when that is pressed.

const _PROGRAMS_PATH := "C:\\WINDOWS\\Start Menu\\Programs"
const _ICONS := "res://win95/theme/icons/"

## The window that Shut Down... opens.
@export var shut_down: PackedScene

## What each item id opens: a shortcut or a document.
var _files: Dictionary[StringName, Win95File] = {}

@onready var _button: Button = get_parent()
@onready var _state: ComputerState = owner.get_node_or_null(^"%ComputerState") if owner != null else null


func _ready() -> void:
	banner = true
	outside = owner as Control
	if _state == null:
		push_error("Start menu: no %ComputerState in the scene, so it lists no programs")
	_button.toggled.connect(func(on: bool) -> void:
		if on:
			open(_button.get_global_rect().position, _entries_now())
		else:
			hide())
	popup_hide.connect(func() -> void: _button.set_pressed_no_signal(false))
	chosen.connect(_on_chosen)


func _entries_now() -> Array[ContextMenu.Entry]:
	_files.clear()
	var setup := _state.setup if _state != null else null
	var programs := setup.file_at(_PROGRAMS_PATH) if setup != null else null
	var documents: Array[ContextMenu.Entry] = []
	if setup != null:
		for file in setup.recent_documents:
			documents.append(_file_item(file.name, file, Win95File.small_icon(file.icon)))
	var settings: Array[ContextMenu.Entry] = [
		_stub("&Control Panel", "control_panel_16"), _stub("&Printers", "folder_printers_16"), _stub("&Taskbar...", "application_settings_16")]
	var find: Array[ContextMenu.Entry] = [_stub("&Files or Folders...", "find_files_16"), _stub("&Computer...", "find_computer_16")]
	return [
		ContextMenu.submenu("&Programs", _folder_entries(programs), _icon("start_programs_32")),
		ContextMenu.submenu("&Documents", _or_empty(documents), _icon("start_documents_32")),
		ContextMenu.submenu("&Settings", settings, _icon("start_settings_32")),
		ContextMenu.submenu("&Find", find, _icon("start_find_32")),
		ContextMenu.item("&Help", &"", false, false, false, _icon("start_help_32")),
		ContextMenu.item("&Run...", &"", false, false, false, _icon("start_run_32")),
		ContextMenu.separator(),
		ContextMenu.item("Sh&ut Down...", &"shut_down", false, false, false, _icon("start_shutdown_32")),
	]


# A Start Menu folder's contents: folders first as submenus, then shortcuts, each group by name.
func _folder_entries(folder: Win95File) -> Array[ContextMenu.Entry]:
	var entries: Array[ContextMenu.Entry] = []
	if folder == null:
		return _or_empty(entries)
	var children: Array = folder.children.duplicate()
	children.sort_custom(func(a: Win95File, b: Win95File) -> bool:
		if a.is_folder != b.is_folder:
			return a.is_folder
		return a.name.naturalnocasecmp_to(b.name) < 0)
	for file: Win95File in children:
		if file.is_folder:
			entries.append(ContextMenu.submenu(file.name, _folder_entries(file), Win95File.small_icon(file.icon)))
		elif file.target == "":
			entries.append(ContextMenu.item(file.name, &"", false, false, false, _shortcut_icon(file)))  # a stock item that isn't built
		else:
			entries.append(_file_item(file.name, file, _shortcut_icon(file)))
	return _or_empty(entries)


func _file_item(label: String, file: Win95File, icon: Texture2D) -> ContextMenu.Entry:
	var id := StringName("file_%d" % _files.size())
	_files[id] = file
	return ContextMenu.item(label, id, false, false, false, icon)


# A shortcut shows its program's own icon while the program is there, as Win95 does.
func _shortcut_icon(file: Win95File) -> Texture2D:
	var target := _state.setup.file_at(file.target) if file.target != "" else null
	var icon: Texture2D = Win95Desktop.window_icon(target.program) if target != null and target.program != null else null
	return icon if icon != null else Win95File.small_icon(file.icon)


# Win95 shows an empty folder as one grey "(Empty)".
func _or_empty(entries: Array[ContextMenu.Entry]) -> Array[ContextMenu.Entry]:
	if entries.is_empty():
		entries.append(ContextMenu.item("(Empty)", &"", false, true))
	return entries


func _stub(label: String, icon: String) -> ContextMenu.Entry:
	return ContextMenu.item(label, &"", false, false, false, _icon(icon))


func _icon(icon_name: String) -> Texture2D:
	return load(_ICONS + icon_name + ".png")


func _on_chosen(id: StringName) -> void:
	if id == &"shut_down":
		var desktop := get_tree().get_first_node_in_group(Win95Desktop.GROUP) as Win95Desktop
		if desktop == null:
			push_error("Start menu: no Win95Desktop in the tree for Shut Down")
			return
		desktop.open(shut_down)
		return
	var file: Win95File = _files.get(id)
	if file == null:
		return
	if not owner.has_method(&"open_file"):
		push_error("Start menu: its scene, %s, can't open %s" % [owner.name, file.name])
		return
	owner.open_file(file)

extends Control
## The Win95 screen of one job's computer. It shows NO SIGNAL while the computer is off, and on
## boot it rebuilds the desktop from %ComputerState's setup: palette, wallpaper, desktop icons,
## folders, the Recycle Bin and sound. Right-click menus act on the setup through %ComputerState,
## and every icon view lists the setup again after each change. While the cable is on another
## computer, ScreenView takes it out of the tree, and puts it back as it was.

const _BOOT := preload("res://win95/boot_sequence.tscn")
const _FOLDER := preload("res://win95/folder_window.tscn")
const _PROPERTIES := preload("res://win95/properties_window.tscn")
const _MESSAGE := preload("res://win95/message_box.tscn")
const _BIN_EMPTY := preload("res://win95/theme/icons/recycle_bin_empty_32.png")
const _BIN_FULL := preload("res://win95/theme/icons/recycle_bin_full_32.png")
const _COVER := preload("res://win95/cover_screen.gd")
const _SHARED_PALETTE := preload("res://win95/theme/palette.tres")
const _ICONS := "res://win95/theme/icons/"
## The meta key on a FileIcon that holds its Win95File.
const _FILE_META := &"win95_file"

## What an icon view shows: the desktop, a folder, drive C, My Computer or the Recycle Bin.
class Listing:
	extends RefCounted
	var title: String = ""
	## 32 x 32; the title bar shows its 16 px twin.
	var icon: Texture2D
	var kind: StringName = &"folder"
	## Returns the Array of Win95Files to show. For a folder, the desktop or drive C it is the live
	## Array, which New Folder adds to.
	var files: Callable
	var creatable: bool = false
	## What the listing shows: a folder's Win95File, or a name such as &"drive_c". Two windows never
	## show the same key; opening it again brings the open one to the front.
	var key: Variant

	func _init(listing_title: String, listing_icon: Texture2D, listing_kind: StringName, listing_files: Callable, can_create: bool, listing_key: Variant) -> void:
		title = listing_title
		icon = listing_icon
		kind = listing_kind
		files = listing_files
		creatable = can_create
		key = listing_key


static var _stock_palette: Win95Palette
var _setup_icons: Array[FileIcon] = []
var _listings: Dictionary[IconView, Listing] = {}
var _drive_c: Win95File
var _drives: Array[Win95File] = []
var _context: ContextMenu
var _context_view: IconView
var _context_item: FileIcon
var _boot: Node

@onready var _state: ComputerState = %ComputerState
@onready var _desktop: Win95Desktop = $Desktop
@onready var _background: TextureRect = $Desktop/DesktopBackground
@onready var _icons: IconView = $Desktop/DesktopIcons
@onready var _systray: Node = %Systray
@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
	if _stock_palette == null:
		_stock_palette = _SHARED_PALETTE.duplicate() as Win95Palette
	_state.booted.connect(_on_booted)
	_state.powered_off.connect(_on_powered_off)
	_state.changed.connect(_on_changed)
	_context = ContextMenu.new()
	add_child(_context)
	_context.chosen.connect(_on_action)
	_wire_view(_icons)
	_systray.mute_toggled.connect(func(_muted: bool) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_systray.volume_changed.connect(func(_volume: float) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_no_signal.visible = not _state.is_on
	if _state.is_on:
		_on_booted()


func _enter_tree() -> void:
	if is_node_ready() and _state.is_on:
		_apply_palette(_state.setup.palette)


func _on_booted() -> void:
	var setup := _state.setup
	_desktop.close_all()
	for child in get_children():
		if child.get_script() == _COVER:
			child.queue_free()
	if is_inside_tree():
		_apply_palette(setup.palette)
	if setup.wallpaper != null:
		_background.texture = setup.wallpaper
		# As Win95 showed them: a small pattern tiles, a picture fills the screen.
		var tiles := setup.wallpaper.get_width() * 2 < _background.size.x
		_background.stretch_mode = TextureRect.STRETCH_TILE if tiles else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drive_c = _folder("(C:)", "drive_hard_32.png")
	_drives.assign([_folder("3\u00bd Floppy (A:)", "drive_floppy_35_32.png"), _drive_c, _folder("(D:)", "drive_cdrom_32.png"),
		_folder("Control Panel", "folder_control_panel_32.png"), _folder("Printers", "folder_printers_32.png")])
	_listings.clear()
	_listings[_icons] = Listing.new("Desktop", null, &"desktop", func() -> Array: return _state.setup.desktop, true, &"desktop")
	_fill(_icons)
	_apply_sound()
	_no_signal.hide()
	if is_instance_valid(_boot):
		_boot.queue_free()
	_boot = _BOOT.instantiate()
	add_child(_boot)
	move_child(_boot, _no_signal.get_index())


func _on_powered_off() -> void:
	if is_instance_valid(_boot):
		_boot.queue_free()
	_no_signal.show()


# Every bevel draws with the one shared palette; the desktop on screen sets it, also on entering the tree.
func _apply_palette(palette: Win95Palette) -> void:
	var source := _stock_palette if palette == null or palette == _SHARED_PALETTE else palette
	for colour in [&"face_color", &"window_color", &"highlight_color", &"light_color", &"shadow_color", &"dark_shadow_color"]:
		_SHARED_PALETTE.set(colour, source.get(colour))


func _apply_sound() -> void:
	if _state.setup == null:
		return
	_systray.volume = _state.setup.volume
	_systray.muted = _state.setup.muted


func _on_changed() -> void:
	_apply_sound()
	for view: IconView in _listings.keys():
		_fill(view)


## Lists the view's Win95Files again, keeping the selection. On the desktop, the system icons from
## desktop_icons.tscn stay and the Recycle Bin shows whether it is empty.
func _fill(view: IconView) -> void:
	var listing: Listing = _listings[view]
	var keep: Array[Win95File] = []
	for item in view.selected_items():
		var file := _file_of(item)
		if file != null:
			keep.append(file)
	var old: Array = _setup_icons if view == _icons else view.get_children()
	for item: Node in old:
		item.queue_free()
	var added: Array[FileIcon] = []
	for file: Win95File in listing.files.call():
		var item := view.add_item(file.name, file.icon)
		item.set_meta(_FILE_META, file)
		item.name_edited.connect(func(_old: String, new_text: String) -> void: _state.rename_file(file, new_text))
		item.selected = keep.has(file)
		added.append(item)
	if view == _icons:
		_setup_icons = added
		(_icons.get_node("RecycleBin") as FileIcon).icon = _BIN_EMPTY if _state.setup.recycle_bin.is_empty() else _BIN_FULL


func _folder(folder_name: String, icon_file: String) -> Win95File:
	var folder := Win95File.new()
	folder.name = folder_name
	folder.icon = load(_ICONS + icon_file)
	folder.is_folder = true
	return folder


func _file_of(item: FileIcon) -> Win95File:
	return item.get_meta(_FILE_META) if item.has_meta(_FILE_META) else null


func _wire_view(view: IconView) -> void:
	view.item_opened.connect(_open_item)
	view.context_requested.connect(func(item: FileIcon, at: Vector2) -> void: _open_context(view, item, at))
	view.delete_requested.connect(func(items: Array[FileIcon]) -> void: _delete(view, items))


func _open_item(item: FileIcon) -> void:
	var file := _file_of(item)
	if item.name == &"MyComputer":
		_show(Listing.new("My Computer", load(_ICONS + "my_computer_32.png"), &"my_computer", func() -> Array: return _drives, false, &"my_computer"))
	elif item.name == &"RecycleBin":
		_show(Listing.new("Recycle Bin", _BIN_EMPTY, &"recycle_bin", func() -> Array: return _state.setup.recycle_bin, false, &"recycle_bin"))
	elif file == null or _listing_of_item(item).kind == &"recycle_bin":
		return
	elif file == _drive_c:
		_show(Listing.new("(C:)", file.icon, &"folder", func() -> Array: return _state.setup.drive_c, true, &"drive_c"))
	elif file.is_folder:
		_show(Listing.new(file.name, file.icon, &"folder", func() -> Array: return file.children, not _drives.has(file), file))
	else:
		_open_file(file)


## Opens [param file] as Win95 does: a program file runs while its name ends in .EXE or .COM;
## any other file opens in the installed program whose app lists its extension. A program file
## whose name lost its .EXE still claims the extension, so its files fail with "Cannot find the file".
func _open_file(file: Win95File) -> void:
	if ComputerState.is_runnable(file):
		_launch(file.program, null)
		return
	var programs := _state.programs_for(file.name.get_extension().to_lower())
	for program in programs:
		if ComputerState.is_runnable(program):
			_launch(program.program, file)
			return
	if not programs.is_empty():
		var location := _state.location_of(programs[0]).trim_suffix("\\")
		var expected := "%s\\%s.EXE" % [location, programs[0].name.get_basename().to_upper()]
		_message(file.name, "Cannot find the file '%s' (or one of its components). Make sure the path and filename are correct and that all required libraries are available." % expected)
	else:
		_message(file.name, "Windows cannot open this file:\n\n%s\n\nNo program on this computer opens files of this type." % file.name)


func _launch(program: PackedScene, file: Win95File) -> void:
	var window: Node = _desktop.open(program)
	if file != null and window.has_method(&"open_file"):
		window.open_file(file, _state)


func _message(title: String, text: String) -> void:
	var box: Node = _desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.show_message(title, text)


func _listing_of_item(item: FileIcon) -> Listing:
	return _listings.get(item.get_parent() as IconView)


func _show(listing: Listing) -> void:
	for view: IconView in _listings.keys():
		if view != _icons and is_same(_listings[view].key, listing.key) and _desktop.windows().has(view.owner):
			_desktop.activate(view.owner)
			return
	var window: Node = _desktop.open(_FOLDER, false)
	var title_bar: Node = window.get_node("%TitleBar")
	title_bar.title = listing.title
	title_bar.icon = _small_icon(listing.icon)
	var view: IconView = window.items
	_wire_view(view)
	window.closed.connect(func() -> void:
		_listings.erase(view)
		window.queue_free())
	_listings[view] = listing
	_fill(view)


func _open_context(view: IconView, item: FileIcon, at: Vector2) -> void:
	_context_view = view
	_context_item = item
	_context.open(at, _entries_for(view, item))


func _entries_for(view: IconView, item: FileIcon) -> Array[ContextMenu.Entry]:
	var listing: Listing = _listings[view]
	var properties := ContextMenu.item("Properties", &"properties")
	if item == null:
		return _background_entries(listing)
	var multi := view.selected_items().size() > 1
	if listing.kind == &"recycle_bin":
		return _entries([["Restore", &"restore"], [], ["Cut"], [], ["Delete", &"purge"], [], properties])
	match item.name:
		&"MyComputer":
			return _entries([["Open", &"open", true], ["Explore"], ["Find..."], [], ["Map Network Drive..."],
				["Disconnect Network Drive..."], [], ["Create Shortcut"], ["Rename", &"rename"], [], ["Properties"]])
		&"RecycleBin":
			return _entries([["Open", &"open", true], ["Explore"], ContextMenu.item("Empty Recycle Bin", &"empty_bin", false, _state.setup.recycle_bin.is_empty()),
				[], ["Create Shortcut"], [], ["Properties"]])
		&"NetworkNeighborhood":
			return _entries([["Open", &"open", true], ["Explore"], ["Find Computer..."], [], ["Map Network Drive..."],
				["Disconnect Network Drive..."], [], ["Create Shortcut"], ["Rename", &"rename"], [], ["Properties"]])
	var file := _file_of(item)
	if listing.kind == &"my_computer":
		return _entries([["Open", &"open", true], ["Explore"], ["Find..."], [], ["Create Shortcut"], [], properties])
	var entries := _entries([["Open", &"open", true]])
	if file != null and file.is_folder:
		entries.append_array(_entries([["Explore"], ["Find..."]]))
	entries.append_array(_entries([[], ContextMenu.submenu("Send To", _entries([["3\u00bd Floppy (A)"], ["Mail Recipient"], ["My Briefcase"]])),
		[], ["Cut"], ["Copy"], [], ["Create Shortcut"], ["Delete", &"delete"]]))
	if not multi:
		entries.append(ContextMenu.item("Rename", &"rename"))
	entries.append_array(_entries([[], properties]))
	return entries


func _background_entries(listing: Listing) -> Array[ContextMenu.Entry]:
	var arrange := ContextMenu.submenu("Arrange Icons", _entries([["by Name"], ["by Type"], ["by Size"], ["by Date"], [], ["Auto Arrange"]]))
	var view_menu := ContextMenu.submenu("View", _entries([ContextMenu.item("Large Icons", &"", false, false, true), ["Small Icons"], ["List"], ["Details"]]))
	var new_menu := ContextMenu.submenu("New", _entries([["Folder", &"new_folder"], ["Shortcut"], [], ["Text Document"], ["WordPad Document"], ["Bitmap Image"], ["Wave Sound"]]))
	var paste := ContextMenu.item("Paste", &"", false, true)
	var paste_shortcut := ContextMenu.item("Paste Shortcut", &"", false, true)
	match listing.kind:
		&"desktop":
			return _entries([arrange, ["Line up Icons"], [], paste, paste_shortcut, [], new_menu, [], ["Properties"]])
		&"recycle_bin":
			return _entries([view_menu, [], arrange, ["Line up Icons"], [], ContextMenu.item("Empty Recycle Bin", &"empty_bin", false, _state.setup.recycle_bin.is_empty()), [], ["Properties"]])
		&"my_computer":
			return _entries([view_menu, [], arrange, ["Line up Icons"], [], ["Properties"]])
	if not listing.creatable:
		return _entries([view_menu, [], arrange, ["Line up Icons"], [], ["Properties"]])
	return _entries([view_menu, [], arrange, ["Line up Icons"], [], paste, paste_shortcut, [], new_menu, [], ["Properties"]])


# Each spec is an Entry, [] for a separator, or [label, id = &"", is_default = false].
func _entries(specs: Array) -> Array[ContextMenu.Entry]:
	var entries: Array[ContextMenu.Entry] = []
	for spec: Variant in specs:
		if spec is ContextMenu.Entry:
			entries.append(spec)
		elif (spec as Array).is_empty():
			entries.append(ContextMenu.separator())
		else:
			var parts: Array = spec
			entries.append(ContextMenu.item(parts[0], parts[1] if parts.size() > 1 else &"", parts.size() > 2 and parts[2]))
	return entries


func _on_action(id: StringName) -> void:
	var view := _context_view
	if not is_instance_valid(view):
		return
	var item := _context_item if is_instance_valid(_context_item) else null
	var listing: Listing = _listings[view]
	var files := _files(view.selected_items())
	match id:
		&"open":
			for selected in view.selected_items():
				view.open_item(selected)
		&"rename":
			if item != null:
				item.start_rename()
		&"delete":
			_delete(view, view.selected_items())
		&"purge":
			_state.purge_files(files)
		&"restore":
			_state.restore_files(files)
		&"empty_bin":
			_state.empty_recycle_bin()
		&"new_folder":
			var folder := _state.new_folder(listing.files.call())
			_rename_new.call_deferred(view, folder)
		&"properties":
			var file := _file_of(item) if item != null else null
			if file != null:
				var window: Node = _desktop.open(_PROPERTIES)
				window.show_file(file, _state.location_of(file))
		_:
			push_error("Win95: no action for the menu id %s" % id)


func _delete(view: IconView, items: Array[FileIcon]) -> void:
	var files := _files(items)
	if _listings[view].kind == &"recycle_bin":
		_state.purge_files(files)
	else:
		_state.delete_files(files)


# Win95 names a new folder by letting the player type over "New Folder" at once.
func _rename_new(view: IconView, folder: Win95File) -> void:
	for item in view.get_children():
		if item is FileIcon and _file_of(item) == folder and not item.is_queued_for_deletion():
			view.select_only(item)
			item.start_rename()
			return


func _files(items: Array[FileIcon]) -> Array[Win95File]:
	var files: Array[Win95File] = []
	for item in items:
		var file := _file_of(item)
		if file != null:
			files.append(file)
	return files


# Kalle's icon set pairs every name_32.png with a name_16.png.
func _small_icon(icon: Texture2D) -> Texture2D:
	if icon == null or not icon.resource_path.ends_with("_32.png"):
		return null
	var small := icon.resource_path.trim_suffix("_32.png") + "_16.png"
	return load(small) if ResourceLoader.exists(small) else null

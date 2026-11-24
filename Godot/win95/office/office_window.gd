class_name OfficeWindow
extends "res://win95/document_window.gd"
## The frame that every Office 97 app shares (win95/office/office_window.tscn): the title "Microsoft
## Word - Document1", the menu bar with Office's File menu, the Standard and Formatting toolbars, the
## app's own body, the status bar, and a layer for the Office Assistant. It opens maximized, as
## Office 97 does. docs/win95-reference.md, "Office 97", lists what the reference shows.
##
## An app is a scene that inherits office_window.tscn, with a script that extends this one. It puts
## its document view under %Body and its status cells in %StatusBar, and overrides:
## - [method _menus]: the menus after File, as AppBar.add_menu takes them.
## - [method _standard_tools] and [method _formatting_tools]: the toolbar buttons (see
##   [method _add_tools]).
## - document_window's [code]_load[/code], [code]_save[/code] and [code]_is_dirty[/code].
## The app calls [method edited] when the player changes the document.

## The player asked for help: F1, the Help menu's first item or the Office Assistant button. The
## assistant answers it; with no assistant, nothing happens.
signal help_requested
## The player changed the document. The assistant reads it through [method document_text].
signal document_edited

## The File menu's own ids, after document_window's FileMenu (New, Close, Save).
enum OfficeFileMenu { OPEN = 10, SAVE_AS, VERSIONS, PAGE_SETUP, PRINT_PREVIEW, PRINT, SEND_TO, PROPERTIES, EXIT, RECENT = 100 }

const _ICONS := "res://win95/office/icons/"
const _PROPERTIES := preload("res://win95/office/office_properties.tscn")
const _RECENT_COUNT := 4

## The name of an untitled document: "Document1" in Word, "Book1" in Excel.
@export var untitled_name: String = "Document1"
## The Office Assistant: a scene that the window puts in %AssistantLayer as it opens, or null for
## none. A root method [code]attach(window: OfficeWindow)[/code] is called once it is in the tree;
## from there it listens to [signal help_requested] and [signal document_edited]. Its root ignores
## the mouse outside what it draws (the layer covers the whole window).
@export var assistant: PackedScene
## Opens filling the desktop, as Office 97 does.
@export var starts_maximized: bool = true
## File > Properties > Summary's Template row: "Normal" in Word; empty hides the row, as in Excel.
@export var template_name: String = ""
## Office 97's setup registered the types that its apps open to them, so Windows opens those files
## here even where another program opens them too, as Word took .doc from WordPad
## (ComputerState.programs_for).
@export var claims_file_types: bool = true

var _tools: Dictionary[StringName, Button] = {}
var _untitled: Win95File  # holds an untitled document's Properties


func _ready() -> void:
	_build_file_menu()
	super()
	for menu: Array in _menus():
		AppBar.add_menu(%MenuBar, menu[0], menu[1])
	_add_tools(%Standard, _standard_tools())
	_add_tools(%Formatting, _formatting_tools())
	if assistant != null:
		var helper := assistant.instantiate()
		%AssistantLayer.add_child(helper)
		if helper.has_method(&"attach"):
			helper.call(&"attach", self)
	if starts_maximized:
		toggle_maximized.call_deferred()


## The app's name, as the title bar shows it before the document's: "Microsoft Word".
func app_title() -> String:
	return _app_title


## The document's text without formatting, for the assistant; the base has none.
func document_text() -> String:
	return ""


## The toolbar button that [method _add_tools] made for [param id], or null.
func tool(id: StringName) -> Button:
	return _tools.get(id)


## Adds a cell to the status bar, [param width] pixels wide (0: as wide as [param text]), and returns
## its label.
func add_status_cell(text: String, width: float = 0.0) -> Label:
	var cell := PanelContainer.new()
	cell.theme_type_variation = &"OfficeStatusCell"
	cell.custom_minimum_size.x = width
	var label := Label.new()
	label.text = text
	label.clip_text = width > 0.0
	cell.add_child(label)
	%StatusBar.add_child(cell)
	return label


## Shows [param opened], a file in [param state]'s running copy, and notes it among the recent
## documents that Start > Documents and the File menu list.
func open_file(opened: Win95File, state: ComputerState) -> void:
	super(opened, state)
	state.note_opened(opened)


## Shows the document's File > Properties, modal to the window: "Letter Properties", open on Summary.
## An untitled document's properties last as long as the window.
func show_properties() -> void:
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("OfficeWindow %s: not on a Win95Desktop, so it can't show Properties" % _app_title)
		return
	var shown := file
	if shown == null:
		if _untitled == null:
			_untitled = Win95File.new()
			_untitled.name = untitled_name
			var computer := desktop.computer if _state == null else _state
			var owner_name := computer.setup.registered_owner if computer != null and computer.setup != null else ""
			if owner_name != "":
				_untitled.summary[&"author"] = owner_name  # Office fills Author with the user's name
		shown = _untitled
	var location := _state.location_of(file).trim_suffix("\\") if file != null and _state != null else ""
	var sheet: Node = desktop.open(_PROPERTIES, false)
	sheet.show_document(shown, shown.name.get_basename() if file != null else untitled_name, location, template_name)
	sheet.belong_to(self)


## Tells the window, and through it the assistant, that the player changed the document.
func edited() -> void:
	document_edited.emit()


## The menus after File, each [title, items] with items as AppBar.add_menu takes them.
func _menus() -> Array:
	return []


## The Standard toolbar's buttons, as [method _add_tools] takes them.
func _standard_tools() -> Array:
	return []


## The Formatting toolbar's buttons, as [method _add_tools] takes them.
func _formatting_tools() -> Array:
	return []


## The files that the File menu lists above Exit, newest first: the computer's recent documents
## that this app opens, at most [constant _RECENT_COUNT], as Office 97 lists 4 by default.
func _recent_files() -> Array[Win95File]:
	var found: Array[Win95File] = []
	if _state == null or _state.setup == null:
		return found
	var types: Variant = get(&"opens")
	for recent in _state.setup.recent_documents:
		if found.size() < _RECENT_COUNT and types is Array and (types as Array).has(recent.name.get_extension().to_lower()) and _state.has_file(recent):
			found.append(recent)
	return found


## Adds [param tools] to [param row]: each is [id, tooltip, action] for a button with the icon
## win95/office/icons/<id>.png (a null action marks it a stub), with a fourth item true for a button
## that stays pushed in; "|" for the gap between groups; "v" for the narrow drop-down arrow beside the
## button before it (a stub); or a Control, such as a font box, as it is.
func _add_tools(row: HBoxContainer, tools: Array) -> void:
	if row.get_child_count() == 0 and not tools.is_empty():
		for i: int in 2:  # the toolbar's grip: two thin raised bars
			var bar := Panel.new()
			bar.theme_type_variation = &"OfficeGrip"
			bar.custom_minimum_size = Vector2(3, 0)
			row.add_child(bar)
		AppBar.add_gap(row)
	for entry: Variant in tools:
		if entry is Control:
			row.add_child(entry)
		elif entry is String and entry == "|":
			row.add_child(_separator())
		elif entry is String and entry == "v":
			var arrow := AppBar.add_button(row, load(_ICONS + "dropdown_arrow.png"), "")
			arrow.theme_type_variation = &"OfficeToolButton"
			arrow.custom_minimum_size.x = 11
		elif entry is Array:
			var id: StringName = entry[0]
			var icon: Texture2D = load(_ICONS + String(id) + ".png")
			var button := AppBar.add_button(row, icon, entry[1], entry[2])
			button.theme_type_variation = &"OfficeToolButton"
			button.custom_minimum_size.x = 23
			button.toggle_mode = entry.size() > 3 and entry[3]
			_tools[id] = button
		else:
			push_error("OfficeWindow %s: %s is no toolbar entry" % [_app_title, entry])


# The etched line between two groups of toolbar buttons.
func _separator() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	var line := Panel.new()
	line.theme_type_variation = &"OfficeSeparator"
	line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	line.offset_left = 2
	line.offset_right = 4
	line.offset_top = 1
	line.offset_bottom = -1
	gap.add_child(line)
	return gap


func _build_file_menu() -> void:
	var menu: PopupMenu = %File
	menu.clear()
	var stub := Stub.dot()
	for item: Array in [
			["New...", FileMenu.NEW, KEY_MASK_CTRL | KEY_N], ["Open...", OfficeFileMenu.OPEN, KEY_MASK_CTRL | KEY_O, stub],
			["Close", FileMenu.CLOSE], [], ["Save", FileMenu.SAVE, KEY_MASK_CTRL | KEY_S], ["Save As...", OfficeFileMenu.SAVE_AS, 0, stub],
			["Versions...", OfficeFileMenu.VERSIONS, 0, stub], [], ["Page Setup...", OfficeFileMenu.PAGE_SETUP, 0, stub],
			["Print Preview", OfficeFileMenu.PRINT_PREVIEW, 0, stub], ["Print...", OfficeFileMenu.PRINT, KEY_MASK_CTRL | KEY_P, stub], [],
			["Send To", OfficeFileMenu.SEND_TO, 0, stub], ["Properties", OfficeFileMenu.PROPERTIES], []]:
		if item.is_empty():
			menu.add_separator()
			continue
		menu.add_item(item[0], item[1], item[2] if item.size() > 2 else 0)
		menu.set_item_shortcut_disabled(menu.item_count - 1, true)  # the label only: keys go to the front window (_unhandled_key_input)
		if item.size() > 3:
			menu.set_item_icon(menu.item_count - 1, item[3])
	menu.add_item("Exit", OfficeFileMenu.EXIT)
	menu.about_to_popup.connect(_list_recent_files)
	menu.id_pressed.connect(_on_office_file_menu)


# The recent files go between the last separator and Exit, numbered from 1.
func _list_recent_files() -> void:
	var menu: PopupMenu = %File
	var exit := menu.get_item_index(OfficeFileMenu.EXIT)
	while menu.get_item_id(exit - 1) >= OfficeFileMenu.RECENT:
		menu.remove_item(exit - 1)
		exit -= 1
	var recent := _recent_files()
	for i: int in recent.size():
		menu.add_item("%d %s" % [i + 1, recent[i].name.get_basename()], OfficeFileMenu.RECENT + i)  # Explorer hides the extension, and Office follows
		menu.set_item_index(menu.item_count - 1, exit + i)
	if not recent.is_empty():
		menu.add_separator()
		menu.set_item_index(menu.item_count - 1, exit + recent.size())


func _on_office_file_menu(id: int) -> void:
	if id == OfficeFileMenu.EXIT:
		request_close()
	elif id == OfficeFileMenu.PROPERTIES:
		show_properties()
	elif id >= OfficeFileMenu.RECENT:
		var recent := _recent_files()
		var index := id - OfficeFileMenu.RECENT
		if index < recent.size() and _state != null:
			var chosen := recent[index]
			_settle(func() -> void: open_file(chosen, _state))


func _retitle() -> void:
	%TitleBar.title = "%s - %s" % [_app_title, file.name if file != null else untitled_name]
	%File.set_item_disabled(%File.get_item_index(FileMenu.SAVE), file == null)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _is_front():
		return
	var shortcut := key.get_keycode_with_modifiers()
	if shortcut == KEY_F1:
		help_requested.emit()
	elif shortcut == KEY_MASK_CTRL | KEY_N:
		_on_file_menu(FileMenu.NEW)
	elif shortcut == KEY_MASK_CTRL | KEY_S:
		save()
	else:
		return
	get_viewport().set_input_as_handled()


func _is_front() -> bool:
	var desktop := get_parent() as Win95Desktop
	return desktop != null and desktop.active_window() == self

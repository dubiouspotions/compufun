class_name ContextMenu
extends PopupPanel
## A Win95 right-click menu. Unlike PopupMenu, it draws the default item bold, and disabled items
## embossed. Build it from Entry values, pop it up with open(), and listen to chosen.
##
## [codeblock]
## var menu := ContextMenu.new()
## add_child(menu)
## menu.chosen.connect(_on_action)
## menu.open(at, [ContextMenu.item("Open", &"open", true), ContextMenu.separator(),
##         ContextMenu.submenu("Send To", [ContextMenu.item("3½ Floppy (A)", &"")])])
## [/codeblock]

## The player picked an item. [param id] is the item's id; items with an empty id do nothing, and
## don't emit.
signal chosen(id: StringName)

## One line of a menu: an item, a separator, or a submenu.
class Entry:
	extends RefCounted
	var label: String = ""
	var id: StringName = &""
	## Drawn bold: the action that a double-click does.
	var is_default: bool = false
	var disabled: bool = false
	## Drawn with a radio dot, as the current choice in a group.
	var checked: bool = false
	var is_separator: bool = false
	var children: Array[Entry] = []


const _ROW_HEIGHT := 17.0
const _SEPARATOR_HEIGHT := 9.0
## The left column holds the check mark; the right one the submenu arrow.
const _COLUMN := 18.0
const _SUBMENU_DELAY := 0.3
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
const _PALETTE := preload("res://win95/theme/palette.tres")

var _entries: Array[Entry] = []
var _hover: int = -1
var _rows: Control
var _sub: ContextMenu
var _sub_index: int = -1
var _sub_timer: Timer
var _screen := Vector2.ZERO
## False until the mouse moves over the rows or presses on them, so the release of the right-click
## that opened the menu doesn't pick an item.
var _armed := false


static func item(label: String, id: StringName, is_default := false, disabled := false, checked := false) -> Entry:
	var entry := Entry.new()
	entry.label = label
	entry.id = id
	entry.is_default = is_default
	entry.disabled = disabled
	entry.checked = checked
	return entry


static func separator() -> Entry:
	var entry := Entry.new()
	entry.is_separator = true
	return entry


static func submenu(label: String, children: Array[Entry]) -> Entry:
	var entry := Entry.new()
	entry.label = label
	entry.children = children
	return entry


func _init() -> void:
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_STOP
	_rows.focus_mode = Control.FOCUS_ALL
	_rows.draw.connect(_draw_rows)
	_rows.gui_input.connect(_rows_input)
	_rows.mouse_exited.connect(func() -> void:
		if _sub == null or not _sub.visible:
			_set_hover(-1))
	add_child(_rows)
	_sub_timer = Timer.new()
	_sub_timer.one_shot = true
	_sub_timer.wait_time = _SUBMENU_DELAY
	_sub_timer.timeout.connect(func() -> void: _open_submenu(_hover))
	add_child(_sub_timer)
	popup_hide.connect(func() -> void:
		if _sub != null:
			_sub.hide())


## Shows [param entries] with the top-left corner at [param at] (pixels of the screen that the menu
## is on), moved left or up where the menu would leave the screen.
func open(at: Vector2, entries: Array[Entry]) -> void:
	_open_on(at, entries, get_parent().get_viewport().get_visible_rect().size)


func _open_on(at: Vector2, entries: Array[Entry], screen: Vector2) -> void:
	_entries = entries
	_screen = screen
	_hover = -1
	_armed = false
	var menu_size := _menu_size()
	_rows.custom_minimum_size = menu_size
	var panel := get_theme_stylebox("panel")
	var full := menu_size + panel.get_minimum_size()
	var corner := at
	if corner.x + full.x > screen.x:
		corner.x = maxf(0.0, at.x - full.x)
	if corner.y + full.y > screen.y:
		corner.y = maxf(0.0, at.y - full.y)
	if get_parent() is Control and not visible:
		PopupCatcher.attach(self, get_parent())
	popup(Rect2i(Vector2i(corner), Vector2i(full)))
	grab_focus()  # a popup closes when it loses focus, so it must have it to begin with
	_rows.grab_focus.call_deferred()
	_rows.queue_redraw()


func _menu_size() -> Vector2:
	var font := get_theme_font("font", &"PopupMenu")
	var font_size := get_theme_font_size("font_size", &"PopupMenu")
	var width := 0.0
	var height := 0.0
	for entry in _entries:
		if entry.is_separator:
			height += _SEPARATOR_HEIGHT
			continue
		var label_font: Font = _BOLD if entry.is_default else font
		width = maxf(width, label_font.get_string_size(entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		height += _ROW_HEIGHT
	return Vector2(ceilf(width) + _COLUMN * 2.0 + 8.0, height)


func _row_rect(index: int) -> Rect2:
	var y := 0.0
	for i in index:
		y += _SEPARATOR_HEIGHT if _entries[i].is_separator else _ROW_HEIGHT
	var height := _SEPARATOR_HEIGHT if _entries[index].is_separator else _ROW_HEIGHT
	return Rect2(0.0, y, _rows.size.x, height)


func _row_at(point: Vector2) -> int:
	for i in _entries.size():
		if _row_rect(i).has_point(point):
			return i
	return -1


func _draw_rows() -> void:
	var font := get_theme_font("font", &"PopupMenu")
	var font_size := get_theme_font_size("font_size", &"PopupMenu")
	var normal := get_theme_color("font_color", &"PopupMenu")
	var hover_color := get_theme_color("font_hover_color", &"PopupMenu")
	var disabled := _PALETTE.shadow_color
	var emboss := _PALETTE.highlight_color
	for i in _entries.size():
		var entry := _entries[i]
		var rect := _row_rect(i)
		if entry.is_separator:
			var y := rect.position.y + floorf(rect.size.y / 2.0) - 1.0
			_rows.draw_rect(Rect2(1.0, y, rect.size.x - 2.0, 1.0), disabled)
			_rows.draw_rect(Rect2(1.0, y + 1.0, rect.size.x - 2.0, 1.0), emboss)
			continue
		var hovered := i == _hover and not entry.disabled
		if hovered:
			_rows.draw_style_box(get_theme_stylebox("hover", &"PopupMenu"), rect)
		var label_font: Font = _BOLD if entry.is_default else font
		var baseline := rect.position.y + floorf((rect.size.y - label_font.get_height(font_size)) / 2.0) + label_font.get_ascent(font_size)
		var text_at := Vector2(_COLUMN, baseline)
		if entry.disabled:
			_rows.draw_string(label_font, text_at + Vector2.ONE, entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, emboss)
			_rows.draw_string(label_font, text_at, entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, disabled)
		else:
			_rows.draw_string(label_font, text_at, entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, hover_color if hovered else normal)
		var mark_color := hover_color if hovered else normal
		if entry.checked:
			_draw_icon_centered(get_theme_icon("radio_checked", &"PopupMenu"), Rect2(rect.position, Vector2(_COLUMN, rect.size.y)), mark_color)
		if not entry.children.is_empty():
			_draw_icon_centered(get_theme_icon("submenu", &"PopupMenu"), Rect2(rect.end.x - _COLUMN, rect.position.y, _COLUMN, rect.size.y), mark_color)


func _draw_icon_centered(icon: Texture2D, cell: Rect2, tint: Color) -> void:
	var at := (cell.position + (cell.size - icon.get_size()) / 2.0).floor()
	_rows.draw_texture(icon, at, tint)


func _rows_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_armed = true
		var row := _row_at(motion.position)
		if row != _hover:
			_set_hover(row)
		return
	var button := event as InputEventMouseButton
	if button and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_rows.accept_event()
		if button.pressed:
			_armed = true
		elif _armed:
			_activate(_row_at(button.position))
		return
	var key := event as InputEventKey
	if key and key.pressed:
		_rows.accept_event()
		match key.keycode:
			KEY_DOWN:
				_step(1)
			KEY_UP:
				_step(-1)
			KEY_RIGHT:
				_open_submenu(_hover)
			KEY_LEFT, KEY_ESCAPE:
				hide()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate(_hover)


func _step(direction: int) -> void:
	if _entries.is_empty():
		return
	var i := _hover
	for n in _entries.size():
		i = posmod(i + direction, _entries.size())
		if not _entries[i].is_separator and not _entries[i].disabled:
			_set_hover(i)
			return


func _set_hover(index: int) -> void:
	_hover = index
	_rows.queue_redraw()
	_sub_timer.stop()
	if _sub != null and _sub.visible and index != _sub_index:
		_sub.hide()
	if index >= 0 and not _entries[index].children.is_empty() and index != _sub_index:
		_sub_timer.start()


func _activate(index: int) -> void:
	if index < 0:
		return
	var entry := _entries[index]
	if entry.is_separator or entry.disabled:
		return
	if not entry.children.is_empty():
		_open_submenu(index)
		return
	hide()
	if entry.id != &"":
		chosen.emit(entry.id)


func _open_submenu(index: int) -> void:
	if index < 0 or _entries[index].children.is_empty() or _entries[index].disabled:
		return
	if _sub == null:
		_sub = ContextMenu.new()
		add_child(_sub)
		_sub.chosen.connect(func(id: StringName) -> void:
			hide()
			chosen.emit(id))
	_sub_index = index
	var row := _row_rect(index)
	var at := Vector2(position) + _rows.position + Vector2(row.end.x - 3.0, row.position.y - 3.0)
	_sub._open_on(at, _entries[index].children, _screen)
	_sub.popup_hide.connect(func() -> void: _sub_index = -1, CONNECT_ONE_SHOT)

class_name ContextMenu
extends PopupPanel
## A Win95 menu: right-click menus and the Start menu. Unlike PopupMenu, it draws the default item
## bold, disabled items embossed, icons as the Start menu has them, and the underlined letter that
## the keyboard picks. Build it from Entry values, pop it up with open(), and listen to chosen.
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
	## An & marks the letter that is underlined and that its key picks: "&Programs".
	var label: String = ""
	## Drawn left of the label: 32 px in the Start menu, 16 px in its submenus. A menu with icons
	## has no check column.
	var icon: Texture2D
	var id: StringName = &""
	## The key named right-aligned after the label, as "Alt+F4". The menu doesn't bind the key.
	var shortcut: String = ""
	## Drawn bold: the action that a double-click does.
	var is_default: bool = false
	var disabled: bool = false
	## Drawn with a radio dot, as the current choice in a group.
	var checked: bool = false
	var is_separator: bool = false
	var children: Array[Entry] = []

	## The label without its &.
	func text() -> String:
		return label.replace("&", "")

	## The index in text() of the underlined letter, or -1.
	func mnemonic() -> int:
		return label.find("&")

	## An enabled item with no id does nothing yet; Stub marks it.
	func is_stub() -> bool:
		return id == &"" and not (disabled or checked or is_separator) and children.is_empty()


const _ROW_HEIGHT := 17.0
const _BANNER_WIDTH := 21.0
const _SEPARATOR_HEIGHT := 9.0
## The left column holds the check mark; the right one the submenu arrow.
const _COLUMN := 18.0
## The least space between a label and its shortcut.
const _SHORTCUT_GAP := 16.0
const _SUBMENU_DELAY := 0.3
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
const _PALETTE := preload("res://win95/theme/palette.tres")

## Draws the "Windows95" banner down the left side, as the Start menu does; its submenus don't.
var banner := false
## The control that covers the screen under the menu, so that a click outside closes it; the
## menu's parent when null.
var outside: Control

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


static func item(label: String, id: StringName, is_default := false, disabled := false, checked := false, icon: Texture2D = null) -> Entry:
	var entry := Entry.new()
	entry.icon = icon
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


static func submenu(label: String, children: Array[Entry], icon: Texture2D = null) -> Entry:
	var entry := Entry.new()
	entry.icon = icon
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
	window_input.connect(_window_input)
	_sub_timer = Timer.new()
	_sub_timer.one_shot = true
	_sub_timer.wait_time = _SUBMENU_DELAY
	_sub_timer.timeout.connect(_switch_submenu)
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
	var host := outside if outside != null else get_parent() as Control
	if host != null and not visible:
		PopupCatcher.attach(self, host)
	popup(Rect2i(Vector2i(corner), Vector2i(full)))
	grab_focus()  # a popup closes when it loses focus, so it must have it to begin with
	_rows.grab_focus.call_deferred()
	_rows.queue_redraw()


func _menu_size() -> Vector2:
	var font := get_theme_font("font", &"PopupMenu")
	var font_size := get_theme_font_size("font_size", &"PopupMenu")
	var width := 0.0
	var shortcut_width := 0.0
	var height := 0.0
	for entry in _entries:
		if entry.is_separator:
			height += _SEPARATOR_HEIGHT
			continue
		var label_font: Font = _BOLD if entry.is_default else font
		width = maxf(width, label_font.get_string_size(entry.text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if entry.shortcut != "":
			shortcut_width = maxf(shortcut_width, label_font.get_string_size(entry.shortcut, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		height += _row_height()
	if shortcut_width > 0.0:
		width += _SHORTCUT_GAP + shortcut_width
	return Vector2(ceilf(width) + _text_x() + _COLUMN + 8.0, height)


# The tallest icon, or 0 in a menu without icons.
func _icon_size() -> float:
	var tallest := 0.0
	for entry in _entries:
		if entry.icon != null:
			tallest = maxf(tallest, entry.icon.get_height())
	return tallest


func _row_height() -> float:
	var icon := _icon_size()
	if icon == 0.0:
		return _ROW_HEIGHT
	return icon + (2.0 if icon >= 32.0 else 6.0)


func _icon_x() -> float:
	return (_BANNER_WIDTH if banner else 0.0) + (6.0 if _icon_size() >= 32.0 else 4.0)


func _text_x() -> float:
	var icon := _icon_size()
	return _COLUMN if icon == 0.0 else _icon_x() + icon + 8.0


func _row_rect(index: int) -> Rect2:
	var y := 0.0
	for i in index:
		y += _SEPARATOR_HEIGHT if _entries[i].is_separator else _row_height()
	var height := _SEPARATOR_HEIGHT if _entries[index].is_separator else _row_height()
	var left := _BANNER_WIDTH if banner else 0.0
	return Rect2(left, y, _rows.size.x - left, height)


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
	if banner:
		_draw_banner()
	var text_x := _text_x()
	for i in _entries.size():
		var entry := _entries[i]
		var rect := _row_rect(i)
		if entry.is_separator:
			var y := rect.position.y + floorf(rect.size.y / 2.0) - 1.0
			_rows.draw_rect(Rect2(rect.position.x + 1.0, y, rect.size.x - 2.0, 1.0), disabled)
			_rows.draw_rect(Rect2(rect.position.x + 1.0, y + 1.0, rect.size.x - 2.0, 1.0), emboss)
			continue
		var hovered := i == _hover and not entry.disabled
		if hovered:
			_rows.draw_style_box(get_theme_stylebox("hover", &"PopupMenu"), rect)
		var label_font: Font = _BOLD if entry.is_default else font
		var baseline := rect.position.y + floorf((rect.size.y - label_font.get_height(font_size)) / 2.0) + label_font.get_ascent(font_size)
		var text_at := Vector2(text_x, baseline)
		var mark_color := hover_color if hovered else normal
		if entry.icon != null:
			_rows.draw_texture(entry.icon, Vector2(_icon_x(), rect.position.y + floorf((rect.size.y - entry.icon.get_height()) / 2.0)))
		if entry.disabled:
			_draw_label(entry, label_font, font_size, text_at + Vector2.ONE, emboss)
			_draw_label(entry, label_font, font_size, text_at, disabled)
		else:
			_draw_label(entry, label_font, font_size, text_at, mark_color)
		if entry.checked:
			_draw_icon_centered(get_theme_icon("radio_checked", &"PopupMenu"), Rect2(rect.position, Vector2(_COLUMN, rect.size.y)), mark_color)
		if not entry.children.is_empty():
			_draw_icon_centered(get_theme_icon("submenu", &"PopupMenu"), Rect2(rect.end.x - _COLUMN, rect.position.y, _COLUMN, rect.size.y), mark_color)
		if entry.is_stub():
			Stub.draw(_rows, (Vector2(rect.end.x - _COLUMN, rect.position.y) + (Vector2(_COLUMN, rect.size.y) - Vector2.ONE * Stub.SIZE) / 2.0).floor())


func _draw_label(entry: Entry, font: Font, font_size: int, at: Vector2, color: Color) -> void:
	var text := entry.text()
	_rows.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	var letter := entry.mnemonic()
	if letter >= 0 and letter < text.length():
		var x := font.get_string_size(text.left(letter), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var width := font.get_string_size(text[letter], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_rows.draw_rect(Rect2(at.x + x, at.y + 1.0, width, 1.0), color)
	if entry.shortcut != "":
		var nudge := at.x - _text_x()  # 1 px for the embossed copy of a disabled item
		var right := _rows.size.x - _COLUMN + nudge
		_rows.draw_string(font, Vector2(right - font.get_string_size(entry.shortcut, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, at.y), entry.shortcut, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# Win95's banner: "Windows" in light gray and "95" in white, bold, reading upwards on dark gray.
func _draw_banner() -> void:
	var height := _rows.size.y
	_rows.draw_rect(Rect2(0, 0, _BANNER_WIDTH, height), _PALETTE.shadow_color)
	var size := 16
	_rows.draw_set_transform(Vector2(_BANNER_WIDTH - 5.0, height - 6.0), -PI / 2.0)
	_rows.draw_string(_BOLD, Vector2.ZERO, "Windows", HORIZONTAL_ALIGNMENT_LEFT, -1, size, _PALETTE.face_color)
	var after := _BOLD.get_string_size("Windows", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_rows.draw_string(_BOLD, Vector2(after, 0), "95", HORIZONTAL_ALIGNMENT_LEFT, -1, size, _PALETTE.highlight_color)
	_rows.draw_set_transform(Vector2.ZERO, 0.0)


func _draw_icon_centered(icon: Texture2D, cell: Rect2, tint: Color) -> void:
	var at := (cell.position + (cell.size - icon.get_size()) / 2.0).floor()
	_rows.draw_texture(icon, at, tint)


func _rows_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_point_at(motion.position)
		var parent := get_parent() as ContextMenu
		if parent != null and parent._hover != parent._sub_index:
			parent._set_hover(parent._sub_index)  # back in the submenu: its row in the parent lights up again
		return
	var button := event as InputEventMouseButton
	if button and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_rows.accept_event()
		var row := _row_at(button.position)
		if row != _hover:
			_set_hover(row)
		if button.pressed:
			_armed = true
			_sub_timer.stop()  # the release decides
		elif _armed:
			_activate(row)
		return
	var key := event as InputEventKey
	if key and key.pressed:
		_rows.accept_event()
		if key.unicode > 0 and _pick_letter(String.chr(key.unicode)):
			return
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


func _point_at(at: Vector2) -> void:
	_armed = true
	var row := _row_at(at)
	if row != _hover:
		_set_hover(row)


# An open submenu has the focus, and the focused popup gets all the mouse motion, also over its
# parent menus; so it hands motion outside itself to the menu under the mouse.
func _window_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Rect2(_rows.position, _rows.size).has_point(motion.position):
		return
	var at := Vector2(position) + motion.position
	var menu := get_parent() as ContextMenu
	while menu != null:
		var local := at - Vector2(menu.position) - menu._rows.position
		if Rect2(Vector2.ZERO, menu._rows.size).has_point(local):
			menu._point_at(local)
			return
		menu = menu.get_parent() as ContextMenu


# The item whose underlined letter is [param letter] runs, or opens its submenu.
func _pick_letter(letter: String) -> bool:
	for i in _entries.size():
		var at := _entries[i].mnemonic()
		if at >= 0 and _entries[i].text().substr(at, 1).to_lower() == letter.to_lower():
			_set_hover(i)
			_activate(i)
			return true
	return false


func _step(direction: int) -> void:
	if _entries.is_empty():
		return
	var i := _hover
	for n in _entries.size():
		i = posmod(i + direction, _entries.size())
		if not _entries[i].is_separator and not _entries[i].disabled:
			_set_hover(i)
			return


# As in Win95, an open submenu stays while the mouse crosses other rows on the way to it, and
# switches only after the hover delay.
func _set_hover(index: int) -> void:
	_hover = index
	_rows.queue_redraw()
	_sub_timer.stop()
	var has_children := index >= 0 and not _entries[index].children.is_empty()
	if index != _sub_index and (has_children or (_sub != null and _sub.visible)):
		_sub_timer.start()


func _switch_submenu() -> void:
	if _hover == _sub_index:
		return
	if _hover >= 0 and not _entries[_hover].children.is_empty():
		_open_submenu(_hover)
	else:
		_close_submenu()


# A popup closes when it loses focus, so the menu takes it back from the submenu.
func _close_submenu() -> void:
	if _sub != null and _sub.visible:
		_sub.hide()
		grab_focus()
		_rows.grab_focus()


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
	_sub_timer.stop()  # a click opens at once; the hover delay must not switch it again
	_close_submenu()
	if _sub == null:
		_sub = ContextMenu.new()
		add_child(_sub)
		_sub.chosen.connect(func(id: StringName) -> void:
			hide()
			chosen.emit(id))
		_sub.popup_hide.connect(func() -> void:
			if visible:
				grab_focus()
				_rows.grab_focus())
	_sub_index = index
	var row := _row_rect(index)
	var at := Vector2(position) + _rows.position + Vector2(row.end.x - 3.0, row.position.y - 3.0)
	_sub._open_on(at, _entries[index].children, _screen)
	_sub.popup_hide.connect(func() -> void: _sub_index = -1, CONNECT_ONE_SHOT)

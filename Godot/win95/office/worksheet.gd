class_name Worksheet
extends Control
## Excel's grid (win95/office/excel.tscn): the column letters, the row numbers and the cells of an
## XlsSheet. The player selects cells with the mouse or the keys, types into them, and drags a
## column letter's right edge to change its width (a double-click fits the column to its text).
## Typing starts Enter mode, F2 or a double-click Edit mode, as in Excel 97; Enter, Tab and the
## arrows commit and move. A [member formula_bar] edits the active cell too.

## The selection, the active cell or the mode (Ready, Enter, Edit) changed.
signal state_changed
## The player changed a cell's value or formatting, or a column's width.
signal edited

enum Mode { READY, ENTER, EDIT }

const ROW_HEIGHT := 17
const HEADER_HEIGHT := 17
const FONT_SIZE := 13  # Arial 10 at 96 dpi
const PAD := 2  # between a cell's edge and its text
const _GRIDLINE := Color("#c0c0c0")
const _MOST_CHANGED := 10000  # cells; a bigger selection changes only the cells in use
const _GRAB := 3  # how far from a column's edge a press takes the edge
const _FONTS := {
	[false, false]: preload("res://win95/theme/fonts/liberation_sans_regular.ttf"),
	[true, false]: preload("res://win95/theme/fonts/liberation_sans_bold.ttf"),
	[false, true]: preload("res://win95/theme/fonts/liberation_sans_italic.ttf"),
	[true, true]: preload("res://win95/theme/fonts/liberation_sans_bold_italic.ttf"),
}

static var _palette: Win95Palette = preload("res://win95/theme/palette.tres")

## The cells that the grid shows and edits; [method show_sheet] replaces them.
var sheet := XlsSheet.new()
## The active cell, which typing goes into.
var active := Vector2i.ZERO
## The other corner of the selection; the active cell when only one cell is selected.
var anchor := Vector2i.ZERO
## The cell in the top left corner of the grid.
var first := Vector2i.ZERO
## Ready, or Enter or Edit while the player types into a cell.
var mode := Mode.READY
## The formula bar's text field: it shows the active cell's value and edits it. Null for none.
var formula_bar: LineEdit:
	set(value):
		formula_bar = value
		formula_bar.focus_entered.connect(_on_formula_bar_focused)
		formula_bar.text_changed.connect(func(text: String) -> void: _mirror(_editor, text))
		formula_bar.gui_input.connect(_on_editor_key.bind(formula_bar))
		_show_formula()
## Scroll bars that follow and move [member first]. Null for none.
var vertical_bar: ScrollBar:
	set(value):
		vertical_bar = value
		vertical_bar.value_changed.connect(func(row: float) -> void: _scroll_to(Vector2i(first.x, int(row))))
var horizontal_bar: ScrollBar:
	set(value):
		horizontal_bar = value
		horizontal_bar.value_changed.connect(func(column: float) -> void: _scroll_to(Vector2i(int(column), first.y)))

var _editor := LineEdit.new()
var _dragging := false
var _resizing := -1  # the column whose right edge the mouse drags


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_editor.visible = false
	_editor.add_theme_stylebox_override(&"normal", _editor_style())
	_editor.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_editor.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_editor.text_changed.connect(func(text: String) -> void:
		_mirror(formula_bar, text)
		_fit_editor())
	_editor.gui_input.connect(_on_editor_key.bind(_editor))
	add_child(_editor)
	_palette.changed.connect(queue_redraw)
	resized.connect(_sync_bars)


## Shows [param shown] from A1, dropping any typing in progress.
func show_sheet(shown: XlsSheet) -> void:
	cancel_edit()
	sheet = shown
	active = Vector2i.ZERO
	anchor = Vector2i.ZERO
	first = Vector2i.ZERO
	_changed_state()


## The font of a cell's text: Arial 10, or Liberation Sans as the game has it.
static func cell_font(bold: bool, italic: bool) -> Font:
	return _FONTS[[bold, italic]]


## The cell at the active place, or null when it is blank.
func active_cell() -> XlsSheet.Cell:
	return sheet.cell_at(active)


## The selected cells, from the top left to the bottom right corner, inclusive.
func selection() -> Rect2i:
	var from := Vector2i(mini(active.x, anchor.x), mini(active.y, anchor.y))
	var to := Vector2i(maxi(active.x, anchor.x), maxi(active.y, anchor.y))
	return Rect2i(from, to - from + Vector2i.ONE)


## Selects [param to], with [param from] as the other corner, and scrolls it into view.
func select(to: Vector2i, from: Vector2i = to) -> void:
	commit_edit()
	active = _clamped(to)
	anchor = _clamped(from)
	_scroll_into_view(active)
	_changed_state()


## The sum of the numbers in the selection, as Excel's status bar shows it, or null while one cell
## or no number is selected.
func selection_sum() -> Variant:
	var area := selection()
	if area.size == Vector2i.ONE:
		return null
	var total := 0.0
	var any := false
	for place: Vector2i in sheet.cells:
		var cell: XlsSheet.Cell = sheet.cells[place]
		if area.has_point(place) and XlsSheet.is_number(cell.value):
			total += cell.value.to_float()
			any = true
	return total if any else null


## Starts typing into the active cell with [param text] in it: Enter mode replaces the value, Edit
## mode ([param editing]) changes it.
func begin_edit(text: String, editing: bool = false) -> void:
	mode = Mode.EDIT if editing else Mode.ENTER
	_editor.text = text
	_mirror(formula_bar, text)
	_place_editor()
	_editor.show()
	_editor.grab_focus()
	_editor.edit()  # focus alone doesn't take typing in Godot 4.7
	_editor.caret_column = text.length()
	state_changed.emit()


## Puts what the player typed into the active cell and ends Enter or Edit mode.
func commit_edit() -> void:
	if mode == Mode.READY:
		return
	var cell := active_cell()
	cell = cell.duplicate() if cell != null else XlsSheet.Cell.new()
	XlsSheet.enter(cell, _editor.text)
	sheet.put(active, cell)
	_end_edit()
	edited.emit()


## Ends Enter or Edit mode and leaves the cell as it was.
func cancel_edit() -> void:
	if mode != Mode.READY:
		_end_edit()


## Turns [param style] (&"bold", &"italic" or &"underline") on for the selection, or off when the
## active cell has it.
func toggle_style(style: StringName) -> void:
	var cell := active_cell()
	var on: bool = not (cell != null and cell.get(style))
	_change_selection(func(each: XlsSheet.Cell) -> void: each.set(style, on))


## Lines up the selection's text by [param align], or back to General when the active cell already is.
func set_align(align: XlsSheet.Align) -> void:
	var cell := active_cell()
	var chosen := XlsSheet.Align.GENERAL if cell != null and cell.align == align else align
	_change_selection(func(each: XlsSheet.Cell) -> void: each.align = chosen)


## Shows the selection's numbers in [param format], with its usual decimals
## (XlsSheet.DEFAULT_DECIMALS).
func set_format(format: XlsSheet.Format) -> void:
	_change_selection(func(each: XlsSheet.Cell) -> void:
		each.format = format
		each.decimals = XlsSheet.DEFAULT_DECIMALS.get(format, 0))


## Shows one more ([param step] 1) or one fewer (-1) decimal in the selection's numbers. A General
## number becomes a Number with the decimals that it showed, plus [param step].
func change_decimals(step: int) -> void:
	_change_selection(func(each: XlsSheet.Cell) -> void:
		if each.format == XlsSheet.Format.GENERAL:
			if not XlsSheet.is_number(each.value):
				return
			var shown := XlsSheet.general(each.value.to_float())
			each.format = XlsSheet.Format.NUMBER
			each.decimals = shown.length() - shown.find(".") - 1 if shown.contains(".") else 0
		each.decimals = clampi(each.decimals + step, 0, 30))


## Empties the selected cells and keeps their formatting, as the Delete key does.
func clear_contents() -> void:
	commit_edit()
	var area := selection()
	var changed := false
	for place: Vector2i in sheet.cells.keys():
		if area.has_point(place):
			var cell: XlsSheet.Cell = sheet.cells[place].duplicate()
			changed = changed or cell.value != ""
			cell.value = ""
			sheet.put(place, cell)
	if changed:
		queue_redraw()
		edited.emit()


## The left edge of [param column] in the grid, in pixels; columns left of [member first] are
## off to the left.
func column_x(column: int) -> int:
	var x := _row_header_width()
	if column >= first.x:
		for c: int in range(first.x, column):
			x += column_pixels(c)
	else:
		for c: int in range(column, first.x):
			x -= column_pixels(c)
	return x


## The width of [param column] on screen, in pixels: Excel's 7 per character of Arial 10, plus 5.
func column_pixels(column: int) -> int:
	var characters := sheet.width_of(column)
	return 0 if characters <= 0.0 else roundi(characters * 7.0 + 5.0)


## The cell under [param point], a position in the grid; null over the headers.
func cell_at_point(point: Vector2) -> Variant:
	if point.x < _row_header_width() or point.y < HEADER_HEIGHT:
		return null
	return Vector2i(_column_at(point.x), first.y + int((point.y - HEADER_HEIGHT) / ROW_HEIGHT))


## The rectangle of the cell at [param place] in the grid, gridlines excluded.
func cell_rect(place: Vector2i) -> Rect2:
	var x := column_x(place.x)
	var y := HEADER_HEIGHT + (place.y - first.y) * ROW_HEIGHT
	return Rect2(x, y, column_pixels(place.x) - 1, ROW_HEIGHT - 1)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_on_mouse_motion(motion)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and _on_key(key):
		accept_event()


func _on_mouse_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_WHEEL_DOWN or button.button_index == MOUSE_BUTTON_WHEEL_UP:
		if button.pressed:
			_scroll_to(first + Vector2i(0, 3 if button.button_index == MOUSE_BUTTON_WHEEL_DOWN else -3))
		accept_event()
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not button.pressed:
		if _resizing >= 0:
			edited.emit()
		_dragging = false
		_resizing = -1
		return
	commit_edit()
	grab_focus()
	var point := button.position
	var edge := _column_edge_at(point)
	if edge >= 0:
		if button.double_click:
			_fit_column(edge)
			edited.emit()
		else:
			_resizing = edge
		return
	var place: Variant = cell_at_point(point)
	var shift := button.shift_pressed
	if point.y < HEADER_HEIGHT and point.x < _row_header_width():
		_select_keeping_scroll(Vector2i.ZERO, Vector2i(XlsSheet.COLUMNS - 1, XlsSheet.ROWS - 1))
	elif point.y < HEADER_HEIGHT:
		var column := _column_at(point.x)
		_select_keeping_scroll(Vector2i(column, 0), Vector2i(anchor.x if shift else column, XlsSheet.ROWS - 1))
	elif point.x < _row_header_width():
		var row := first.y + int((point.y - HEADER_HEIGHT) / ROW_HEIGHT)
		_select_keeping_scroll(Vector2i(0, row), Vector2i(XlsSheet.COLUMNS - 1, anchor.y if shift else row))
	elif place != null:
		if button.double_click:
			_select_keeping_scroll(place, place)
			begin_edit(XlsSheet.edit_text(active_cell()), true)
			return
		_select_keeping_scroll(place, anchor if shift else place)
		_dragging = true


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _resizing >= 0:
		var pixels := maxf(0.0, motion.position.x - column_x(_resizing))
		sheet.set_width(_resizing, maxf(0.0, (pixels - 5.0) / 7.0))
		_place_editor()
		_sync_bars()
		queue_redraw()
		return
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if _column_edge_at(motion.position) >= 0 else Control.CURSOR_ARROW
	if _dragging:
		var place: Variant = cell_at_point(motion.position.clamp(Vector2(_row_header_width(), HEADER_HEIGHT), size - Vector2.ONE))
		if place != null and place != active:
			var keep := anchor
			active = _clamped(place)
			anchor = keep
			_changed_state()


# Returns true when it handled [param key].
func _on_key(key: InputEventKey) -> bool:
	var shift := key.shift_pressed
	var ctrl := key.ctrl_pressed or key.meta_pressed
	if ctrl:
		match key.keycode:
			KEY_B:
				toggle_style(&"bold")
			KEY_I:
				toggle_style(&"italic")
			KEY_U:
				toggle_style(&"underline")
			KEY_HOME:
				select(Vector2i.ZERO)
			_:
				return false
		return true
	match key.keycode:
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			var to := active + _step(key.keycode)
			select(to, anchor if shift else to)
		KEY_TAB:
			_move(Vector2i(-1 if shift else 1, 0))
		KEY_ENTER, KEY_KP_ENTER:
			_move(Vector2i(0, -1 if shift else 1))
		KEY_HOME:
			select(Vector2i(0, active.y), Vector2i(anchor.x if shift else 0, anchor.y if shift else active.y))
		KEY_PAGEDOWN, KEY_PAGEUP:
			var page := _rows_visible() * (1 if key.keycode == KEY_PAGEDOWN else -1)
			first = _clamped(first + Vector2i(0, page))
			select(active + Vector2i(0, page))
		KEY_DELETE:
			clear_contents()
		KEY_BACKSPACE:
			begin_edit("")
		KEY_F2:
			begin_edit(XlsSheet.edit_text(active_cell()), true)
		_:
			if key.unicode < 32 or key.alt_pressed:
				return false
			begin_edit(char(key.unicode))
	return true


func _on_editor_key(event: InputEvent, field: LineEdit) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or mode == Mode.READY:
		return
	var shift := key.shift_pressed
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_commit_and_move(Vector2i(0, -1 if shift else 1))
		KEY_TAB:
			_commit_and_move(Vector2i(-1 if shift else 1, 0))
		KEY_ESCAPE:
			cancel_edit()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			if mode == Mode.EDIT or field == formula_bar:
				return
			_commit_and_move(_step(key.keycode))
		_:
			return
	field.accept_event()


func _commit_and_move(step: Vector2i) -> void:
	commit_edit()
	_move(step)


# Moves the active cell by [param step] and leaves one cell selected.
func _move(step: Vector2i) -> void:
	var to := active + step
	select(to, to)
	grab_focus()


func _on_formula_bar_focused() -> void:
	if mode == Mode.READY:
		mode = Mode.EDIT
		_editor.text = XlsSheet.edit_text(active_cell())
		_place_editor()
		_editor.show()
		state_changed.emit()


func _end_edit() -> void:
	mode = Mode.READY
	_editor.hide()
	if formula_bar != null and formula_bar.has_focus():
		formula_bar.release_focus()
	if is_inside_tree():
		grab_focus()
	_changed_state()


# Applies [param change] to a copy of each selected cell. A selection of whole rows or columns
# reaches only as far as the cells in use.
func _change_selection(change: Callable) -> void:
	commit_edit()
	var area := selection()
	if area.get_area() > _MOST_CHANGED:
		area = area.intersection(_used_area().merge(Rect2i(active, Vector2i.ONE)))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var place := Vector2i(x, y)
			var cell := sheet.cell_at(place)
			cell = cell.duplicate() if cell != null else XlsSheet.Cell.new()
			change.call(cell)
			sheet.put(place, cell)
	_changed_state()
	edited.emit()


# The smallest rectangle that holds every cell in use.
func _used_area() -> Rect2i:
	var area := Rect2i()
	for place: Vector2i in sheet.cells:
		area = Rect2i(place, Vector2i.ONE) if area.size == Vector2i.ZERO else area.merge(Rect2i(place, Vector2i.ONE))
	return area


# Selects without scrolling, for a press on a cell that is already in view.
func _select_keeping_scroll(to: Vector2i, from: Vector2i) -> void:
	active = _clamped(to)
	anchor = _clamped(from)
	_changed_state()


func _changed_state() -> void:
	_show_formula()
	_sync_bars()
	queue_redraw()
	state_changed.emit()


func _show_formula() -> void:
	if formula_bar != null and mode == Mode.READY:
		formula_bar.text = XlsSheet.edit_text(active_cell())


func _mirror(field: LineEdit, text: String) -> void:
	if field != null and field.text != text:
		var caret := field.caret_column
		field.text = text
		field.caret_column = mini(caret, text.length())
		if field == _editor:
			_fit_editor()


func _place_editor() -> void:
	var rect := cell_rect(active).grow(-1)  # inside the selection frame
	_editor.position = rect.position
	_editor.size = rect.size
	var cell := active_cell()
	_editor.add_theme_font_override(&"font", _font_of(cell))
	_fit_editor()


# Widens the editor to the right as the text grows, as Excel's does.
func _fit_editor() -> void:
	var rect := cell_rect(active).grow(-1)
	var needed := _editor.get_theme_font(&"font").get_string_size(_editor.text + "M", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + PAD * 2
	_editor.size = Vector2(minf(maxf(rect.size.x, needed), size.x - rect.position.x), rect.size.y)


func _scroll_into_view(place: Vector2i) -> void:
	var top := first
	if place.y < top.y:
		top.y = place.y
	elif place.y >= top.y + _rows_visible():
		top.y = place.y - _rows_visible() + 1
	if place.x < top.x:
		top.x = place.x
	else:
		while top.x < place.x and column_x(place.x) - column_x(top.x) + column_pixels(place.x) + _row_header_width() > size.x:
			top.x += 1
	_scroll_to(top)


func _scroll_to(top: Vector2i) -> void:
	top = _clamped(top)
	if top == first:
		return
	first = top
	if mode != Mode.READY:
		_place_editor()
	_sync_bars()
	queue_redraw()


func _sync_bars() -> void:
	var used := _used_area()
	if vertical_bar != null:
		vertical_bar.page = _rows_visible()
		vertical_bar.max_value = maxi(maxi(used.end.y, active.y) + _rows_visible(), first.y + _rows_visible() * 2)
		vertical_bar.set_value_no_signal(first.y)
	if horizontal_bar != null:
		horizontal_bar.page = 8
		horizontal_bar.max_value = maxi(maxi(used.end.x, active.x) + 8, first.x + 16)
		horizontal_bar.set_value_no_signal(first.x)


func _rows_visible() -> int:
	return maxi(1, int((size.y - HEADER_HEIGHT) / ROW_HEIGHT))


func _row_header_width() -> int:
	return maxi(26, str(first.y + _rows_visible() + 1).length() * 7 + 6)


func _column_at(x: float) -> int:
	var column := first.x
	var left := _row_header_width()
	while column < XlsSheet.COLUMNS - 1 and left + column_pixels(column) <= x:
		left += column_pixels(column)
		column += 1
	return column


# The column whose right edge in the header row is under [param point], or -1.
func _column_edge_at(point: Vector2) -> int:
	if point.y >= HEADER_HEIGHT or point.x < _row_header_width():
		return -1
	var right := _row_header_width()
	for column: int in range(first.x, XlsSheet.COLUMNS):
		right += column_pixels(column)
		if absf(point.x - right) <= _GRAB:
			return column
		if right > point.x + _GRAB:
			return -1
	return -1


func _fit_column(column: int) -> void:
	var widest := 0.0
	for place: Vector2i in sheet.cells:
		if place.x == column:
			var cell: XlsSheet.Cell = sheet.cells[place]
			widest = maxf(widest, _font_of(cell).get_string_size(XlsSheet.shown(cell), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	if widest > 0.0:
		sheet.set_width(column, (widest + PAD * 2 - 5.0) / 7.0)
		_sync_bars()
		queue_redraw()


func _clamped(place: Vector2i) -> Vector2i:
	return place.clamp(Vector2i.ZERO, Vector2i(XlsSheet.COLUMNS - 1, XlsSheet.ROWS - 1))


static func _step(keycode: Key) -> Vector2i:
	match keycode:
		KEY_UP:
			return Vector2i.UP
		KEY_DOWN:
			return Vector2i.DOWN
		KEY_LEFT:
			return Vector2i.LEFT
	return Vector2i.RIGHT


static func _font_of(cell: XlsSheet.Cell) -> Font:
	return cell_font(cell != null and cell.bold, cell != null and cell.italic)


func _editor_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	return style


func _draw() -> void:
	var header_width := _row_header_width()
	draw_rect(Rect2(Vector2.ZERO, size), _palette.window_color)
	var columns: Array[int] = []
	var x := header_width
	var column := first.x
	while x < size.x and column < XlsSheet.COLUMNS:
		columns.append(column)
		x += column_pixels(column)
		column += 1
	var rows := mini(_rows_visible() + 1, XlsSheet.ROWS - first.y)
	var area := selection()
	for i: int in rows:
		_draw_row(first.y + i, columns, area)
	_draw_gridlines(columns, rows)
	_draw_selection_frame(area)
	_draw_headers(columns, rows, area)


func _draw_row(row: int, columns: Array[int], area: Rect2i) -> void:
	for column: int in columns:
		var place := Vector2i(column, row)
		if area.has_point(place) and place != active:
			draw_rect(cell_rect(place), _palette.window_text_color)
	for i: int in columns.size():
		var place := Vector2i(columns[i], row)
		var cell := sheet.cell_at(place)
		if cell == null or cell.value == "":
			continue
		var rect := cell_rect(place)
		var text := XlsSheet.shown(cell)
		var font := _font_of(cell)
		var symbol := XlsSheet.symbol(cell)
		var width := font.get_string_size(symbol + text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var number := XlsSheet.is_number(cell.value)
		var room := rect.size.x - PAD * 2
		if symbol != "" and width <= room:
			draw_string(font, Vector2(rect.position.x + PAD, _baseline(rect, font)), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _ink(area, place))
			width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if number and width > room:
			text = "#".repeat(maxi(0, int(room / font.get_string_size("#", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)))
			width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var align := cell.align
		if align == XlsSheet.Align.GENERAL:
			align = XlsSheet.Align.RIGHT if number else XlsSheet.Align.LEFT
		if align == XlsSheet.Align.LEFT:
			for j: int in range(i + 1, columns.size()):  # text runs on into empty cells to its right
				if width <= room or not _is_empty(Vector2i(columns[j], row)):
					break
				room += column_pixels(columns[j])
		text = _fitted(text, font, room)
		width = minf(width, room)
		var left := rect.position.x + PAD
		if align == XlsSheet.Align.RIGHT:
			left = rect.end.x - PAD - width
		elif align == XlsSheet.Align.CENTER:
			left = rect.position.x + (rect.size.x - width) / 2.0
		var color := _ink(area, place)
		var baseline := _baseline(rect, font)
		draw_string(font, Vector2(roundf(left), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		if cell.underline:
			draw_rect(Rect2(roundf(left), baseline + 1, ceilf(width), 1), color)


# The text colour of the cell at [param place]: white on the black of a selection.
func _ink(area: Rect2i, place: Vector2i) -> Color:
	return _palette.window_color if area.has_point(place) and place != active else _palette.window_text_color


# Where text in [param rect] stands: at the bottom, as Excel's cells line it up.
static func _baseline(rect: Rect2, font: Font) -> float:
	return rect.end.y - roundf(font.get_descent(FONT_SIZE)) - 1.0


func _is_empty(place: Vector2i) -> bool:
	var cell := sheet.cell_at(place)
	return cell == null or cell.value == ""


# [param text] cut to fit [param room] pixels.
static func _fitted(text: String, font: Font, room: float) -> String:
	while text != "" and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > room:
		text = text.left(-1)
	return text


func _draw_gridlines(columns: Array[int], rows: int) -> void:
	for column: int in columns:
		var right := column_x(column) + column_pixels(column) - 1
		draw_rect(Rect2(right, HEADER_HEIGHT, 1, size.y - HEADER_HEIGHT), _GRIDLINE)
	for i: int in rows:
		draw_rect(Rect2(0, HEADER_HEIGHT + (i + 1) * ROW_HEIGHT - 1, size.x, 1), _GRIDLINE)


func _draw_headers(columns: Array[int], rows: int, area: Rect2i) -> void:
	var header_width := _row_header_width()
	var font: Font = cell_font(false, false)
	var bold: Font = cell_font(true, false)
	draw_rect(Rect2(0, 0, size.x, HEADER_HEIGHT), _palette.face_color)
	draw_rect(Rect2(0, 0, header_width, size.y), _palette.face_color)
	_draw_header_box(Rect2(0, 0, header_width, HEADER_HEIGHT), "", font)
	for column: int in columns:
		var picked := column >= area.position.x and column < area.end.x
		_draw_header_box(Rect2(column_x(column), 0, column_pixels(column), HEADER_HEIGHT), XlsSheet.column_name(column), bold if picked else font)
	for i: int in rows:
		var row := first.y + i
		var picked := row >= area.position.y and row < area.end.y
		_draw_header_box(Rect2(0, HEADER_HEIGHT + i * ROW_HEIGHT, header_width, ROW_HEIGHT), str(row + 1), bold if picked else font)


# A raised header box with [param text] in its middle.
func _draw_header_box(rect: Rect2, text: String, font: Font) -> void:
	if rect.size.x <= 0.0:
		return
	draw_rect(Rect2(rect.position, Vector2(rect.size.x - 1, 1)), _palette.highlight_color)
	draw_rect(Rect2(rect.position, Vector2(1, rect.size.y - 1)), _palette.highlight_color)
	draw_rect(Rect2(rect.position.x, rect.end.y - 1, rect.size.x, 1), _palette.shadow_color)
	draw_rect(Rect2(rect.end.x - 1, rect.position.y, 1, rect.size.y), _palette.shadow_color)
	if text != "":
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var baseline := rect.position.y + roundf((rect.size.y - font.get_height(FONT_SIZE)) / 2.0 + font.get_ascent(FONT_SIZE))
		draw_string(font, Vector2(roundf(rect.position.x + (rect.size.x - width) / 2.0), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _palette.button_text_color)


# Excel's thick frame around the selection, with the fill handle in its bottom right corner.
func _draw_selection_frame(area: Rect2i) -> void:
	var top_left := cell_rect(area.position)
	var bottom_right := cell_rect(area.end - Vector2i.ONE)
	var frame := Rect2(top_left.position - Vector2.ONE, bottom_right.end - top_left.position + Vector2(2, 2))
	var black := _palette.window_text_color
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 2)), black)
	draw_rect(Rect2(frame.position.x, frame.end.y - 2, frame.size.x, 2), black)
	draw_rect(Rect2(frame.position, Vector2(2, frame.size.y)), black)
	draw_rect(Rect2(frame.end.x - 2, frame.position.y, 2, frame.size.y), black)
	var handle := Rect2(frame.end - Vector2(4, 4), Vector2(6, 6))
	draw_rect(handle, _palette.window_color)
	draw_rect(handle.grow(-1), black)

class_name ReportList
extends Control
## A Win95 list in report view, as Exchange and Explorer's Details show it: a row of column
## headers, then one row per item with an icon or a text in each column. A click selects a row; a
## double-click or Enter opens it. Put it in a FieldPanel.

## The player selected the row at [param index].
signal row_selected(index: int)
## The player double-clicked the row at [param index], or pressed Enter on it.
signal row_activated(index: int)


class Column:
	extends RefCounted
	var title: String = ""
	## Drawn instead of the title, as Exchange's ! and envelope columns do.
	var icon: Texture2D
	## In pixels; the last column takes the rest of the width.
	var width: float = 80.0
	## Ends the title and the texts at the right edge, as Win95 does for sizes.
	var right_aligned: bool = false

	func _init(column_title: String, column_width: float, column_icon: Texture2D = null, align_right := false) -> void:
		title = column_title
		width = column_width
		icon = column_icon
		right_aligned = align_right


class Row:
	extends RefCounted
	## One per column: a String, a Texture2D, or null for an empty cell.
	var cells: Array = []
	## Drawn bold, as Exchange draws unread mail.
	var bold: bool = false

	func _init(row_cells: Array, row_bold := false) -> void:
		cells = row_cells
		bold = row_bold


const _HEADER_HEIGHT := 17.0
const _ROW_HEIGHT := 16.0
const _PAD := 3.0
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")

## The selected row, or -1.
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()

var _columns: Array[Column] = []
var _rows: Array[Row] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_columns(columns: Array[Column]) -> void:
	_columns = columns
	queue_redraw()


## Shows [param rows]; the selection stays on the same index while it exists.
func set_rows(rows: Array[Row]) -> void:
	_rows = rows
	if selected >= rows.size():
		selected = -1
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(0, _HEADER_HEIGHT + _ROW_HEIGHT)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
		var index := int((button.position.y - _HEADER_HEIGHT) / _ROW_HEIGHT)
		if button.position.y < _HEADER_HEIGHT or index >= _rows.size():
			return
		if index != selected:
			selected = index
			row_selected.emit(index)
		if button.double_click:
			row_activated.emit(index)
	var key := event as InputEventKey
	if key and key.pressed and not _rows.is_empty():
		match key.keycode:
			KEY_UP, KEY_DOWN:
				selected = clampi(selected + (1 if key.keycode == KEY_DOWN else -1), 0, _rows.size() - 1)
				row_selected.emit(selected)
			KEY_ENTER, KEY_KP_ENTER:
				if selected >= 0:
					row_activated.emit(selected)
			_:
				return
		accept_event()


func _draw() -> void:
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var ink := get_theme_color("font_color", &"IconLabel")
	var header := get_theme_stylebox("normal", &"Button")
	var highlight := (get_theme_stylebox("normal", &"IconLabelSelected") as StyleBoxFlat).bg_color
	var x := 0.0
	for i in _columns.size():
		var width := _width(i, x)
		var cell := Rect2(x, 0, width, _HEADER_HEIGHT)
		draw_style_box(header, cell)
		@warning_ignore("incompatible_ternary")
		_draw_cell(cell, _columns[i].icon if _columns[i].icon else _columns[i].title, font, font_size, ink, _columns[i].right_aligned)
		x += width
	for r in _rows.size():
		var y := _HEADER_HEIGHT + r * _ROW_HEIGHT
		var row := _rows[r]
		var row_font: Font = _BOLD if row.bold else font
		var color := ink
		if r == selected:
			draw_rect(Rect2(0, y, size.x, _ROW_HEIGHT), highlight)
			color = get_theme_color("font_color", &"IconLabelSelected")
		x = 0.0
		for i in _columns.size():
			var width := _width(i, x)
			if i < row.cells.size() and row.cells[i] != null:
				_draw_cell(Rect2(x, y, width, _ROW_HEIGHT), row.cells[i], row_font, font_size, color, _columns[i].right_aligned)
			x += width


func _width(column: int, x: float) -> float:
	return maxf(_columns[column].width, size.x - x) if column == _columns.size() - 1 else _columns[column].width


func _draw_cell(cell: Rect2, content: Variant, font: Font, font_size: int, color: Color, right_aligned: bool) -> void:
	if content is Texture2D:
		var icon := content as Texture2D
		draw_texture(icon, (cell.position + (cell.size - icon.get_size()) / 2.0).floor())
		return
	draw_text(self, cell, str(content), font, font_size, color, _PAD, right_aligned)


## Draws [param text] on [param canvas] in [param cell], centred vertically, [param pad] pixels in
## from the left edge, or from the right one when [param right_aligned]; cut with "..." to fit.
static func draw_text(canvas: CanvasItem, cell: Rect2, text: String, font: Font, font_size: int, color: Color, pad: float, right_aligned := false) -> void:
	var fitted := fit(text, font, font_size, cell.size.x - 2.0 * pad)
	var baseline := cell.position.y + floorf((cell.size.y - font.get_height(font_size)) / 2.0) + font.get_ascent(font_size)
	var x := cell.position.x + pad
	if right_aligned:  # the advance after the last glyph already leaves 1 px
		x = cell.end.x - (pad - 1.0) - font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, Vector2(x, baseline), fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## [param text] as Win95 fits it into [param width] pixels: whole, or cut and ended with "...".
static func fit(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	while text.length() > 0 and font.get_string_size(text + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		text = text.left(-1)
	return text + "..."

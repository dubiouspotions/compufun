extends Control
## The day grid of Date/Time: a sunken field with the weekday initials on a dark band, then the
## days of one month in weeks from Sunday, the selected day highlighted. A click on a day picks it.

## The player clicked [param day], 1 to the month's last day.
signal day_picked(day: int)

const _WEEKDAYS := ["S", "M", "T", "W", "T", "F", "S"]
const _PALETTE := preload("res://win95/theme/palette.tres")

## The height of the weekday band, and of each week, in pixels.
@export var row_height: int = 18

var _year: int = 1996
var _month: int = 1
var _day: int = 1


func _ready() -> void:
	_PALETTE.changed.connect(queue_redraw)


## Shows [param month] (1 to 12) of [param year] with [param day] selected.
func show_month(year: int, month: int, day: int) -> void:
	_year = year
	_month = month
	_day = day
	queue_redraw()


## The number of days in [param month] (1 to 12) of [param year].
static func days_in(year: int, month: int) -> int:
	var next := {year = year + month / 12, month = month % 12 + 1, day = 1}
	return Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(next) - 86400).day


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var row := int((button.position.y - _inner().position.y) / row_height) - 1
	var column := int((button.position.x - _inner().position.x) / _column_width())
	var day := row * 7 + column - _first_weekday() + 1
	if row >= 0 and column >= 0 and column < 7 and day >= 1 and day <= days_in(_year, _month) and day != _day:
		_day = day
		queue_redraw()
		day_picked.emit(day)


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", &"FieldPanel"), Rect2(Vector2.ZERO, size))
	var inner := _inner()
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, row_height)), _PALETTE.shadow_color)
	for column in 7:
		_draw_centered(font, font_size, _WEEKDAYS[column], 0, column, _PALETTE.face_color)
	var selection := (get_theme_stylebox("normal", &"IconLabelSelected") as StyleBoxFlat).bg_color
	var first := _first_weekday()
	for day in range(1, days_in(_year, _month) + 1):
		var cell := first + day - 1
		var color := get_theme_color("font_color", &"Label")
		if day == _day:
			var text_size := font.get_string_size(str(day), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var center := _cell_center(cell / 7 + 1, cell % 7)
			draw_rect(Rect2((center - Vector2(text_size.x / 2.0 + 2.0, 6.0)).floor(), Vector2(text_size.x + 4.0, 13.0)), selection)
			color = Color.WHITE
		_draw_centered(font, font_size, str(day), cell / 7 + 1, cell % 7, color)


func _draw_centered(font: Font, font_size: int, text: String, row: int, column: int, color: Color) -> void:
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var center := _cell_center(row, column)
	# Capitals are 9 px tall, from 1 px below the font's top: centre them on the cell.
	draw_string(font, Vector2(floorf(center.x - text_width / 2.0), center.y - 5.0 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _cell_center(row: int, column: int) -> Vector2:
	var inner := _inner()
	return Vector2(inner.position.x + _column_width() * (column + 0.5), inner.position.y + row * row_height + row_height / 2.0).floor()


func _column_width() -> float:
	return _inner().size.x / 7.0


func _inner() -> Rect2:
	var box := get_theme_stylebox("panel", &"FieldPanel")
	return Rect2(box.get_offset(), size - box.get_minimum_size())


func _first_weekday() -> int:
	return Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({year = _year, month = _month, day = 1})).weekday

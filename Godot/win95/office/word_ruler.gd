extends Control
## Word 97's horizontal ruler: a white strip as wide as the line, with a tick every eighth of an
## inch, a taller one every half inch and the inch numbers, between the indent markers.

## Where the line starts, in pixels from the ruler's left edge, and how wide it is.
@export var line_start: float = 26.0
@export var line_width: float = 576.0

const _INCH := 96.0
const _FONT_SIZE := 9


func _draw() -> void:
	var face := Color(0.75, 0.75, 0.75)
	draw_rect(Rect2(Vector2.ZERO, size), face)
	var strip := Rect2(line_start, 3, line_width, size.y - 7)
	draw_rect(Rect2(0, 3, size.x, strip.size.y), Color(0.5, 0.5, 0.5))
	draw_rect(strip, Color.WHITE)
	var mid := strip.get_center().y
	var font := get_theme_default_font()
	for eighth: int in range(1, int(line_width / _INCH * 8.0)):
		var x := line_start + eighth * _INCH / 8.0
		if eighth % 8 == 0:
			var number := str(eighth / 8)
			var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
			draw_string(font, Vector2(x - width / 2.0, mid + 4.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, Color.BLACK)
		elif eighth % 4 == 0:
			draw_line(Vector2(x, mid - 2.0), Vector2(x, mid + 2.0), Color.BLACK)
		elif eighth % 2 == 0:
			draw_rect(Rect2(x, mid, 1, 1), Color.BLACK)
	_marker(line_start, true)
	_marker(line_start + line_width, false)


# An indent marker: the hourglass at the left (first line and hanging indent), the house at the right.
func _marker(x: float, hourglass: bool) -> void:
	var top := 3.0
	var bottom := size.y - 4.0
	var points := PackedVector2Array([Vector2(x - 4, bottom), Vector2(x + 4, bottom), Vector2(x, bottom - 5)])
	draw_colored_polygon(points, Color(0.75, 0.75, 0.75))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK)
	if hourglass:
		var head := PackedVector2Array([Vector2(x - 4, top), Vector2(x + 4, top), Vector2(x, top + 5)])
		draw_colored_polygon(head, Color(0.75, 0.75, 0.75))
		draw_polyline(head + PackedVector2Array([head[0]]), Color.BLACK)

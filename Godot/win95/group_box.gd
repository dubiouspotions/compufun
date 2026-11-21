@tool
extends Control
## A Win95 group box: an etched frame with its title set into the top edge, drawn behind the
## controls that it groups. Place those controls as its siblings; it holds none.

const _PALETTE := preload("res://win95/theme/palette.tres")

## The text in the gap of the top edge; empty draws an unbroken frame.
@export var title: String = "":
	set(value):
		title = value
		queue_redraw()
## Where the title starts, in pixels from the left edge.
@export var title_x: int = 10:
	set(value):
		title_x = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_PALETTE.changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shadow := _PALETTE.shadow_color
	var light := _PALETTE.highlight_color
	_frame(Rect2(0, 0, w, h), shadow, light)
	_frame(Rect2(1, 1, w - 2, h - 2), light, shadow)
	if title == "":
		return
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_rect(Rect2(title_x - 3, 0, width + 5, 2), _PALETTE.face_color)
	# The capitals start 4 px above the frame, as in Win95.
	draw_string(font, Vector2(title_x, font.get_ascent(font_size) - 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", &"Label"))


# Top and left edges in [param top_left], bottom and right in [param bottom_right], 1 px each.
func _frame(r: Rect2, top_left: Color, bottom_right: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x - 1, 1), top_left)
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y - 1), top_left)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), bottom_right)
	draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), bottom_right)

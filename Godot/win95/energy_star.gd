extends Control
## The EPA's Energy Star mark, as BIOSes of 1995 drew it in the top right corner of the power-on
## self test: an arc, "energy" in italics, a star, and "EPA POLLUTION PREVENTER" under a line.

@export var mark_color := Color("#e8d878")
@export var caption_color := Color("#3cc83c")
@export var script_font: Font = preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
@export var caption_font: Font = preload("res://win95/theme/fonts/w95fa_pixel_regular.ttf")


func _get_minimum_size() -> Vector2:
	return Vector2(136, 96)


func _draw() -> void:
	draw_arc(Vector2(64, 66), 50, deg_to_rad(200), deg_to_rad(318), 48, mark_color, 2.0)
	draw_polyline(_star(Vector2(112, 40), 20, 8), mark_color, 2.0)
	# Italic: shear the text to the right as it rises.
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.3, 1), Vector2(10, 62)))
	draw_string(script_font, Vector2.ZERO, "energy", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, mark_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(4, 76, 128, 2), caption_color)
	draw_string(caption_font, Vector2(4, 91), "EPA POLLUTION PREVENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, caption_color)


static func _star(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 11:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append((center + Vector2(cos(angle), sin(angle)) * radius).round())
	return points

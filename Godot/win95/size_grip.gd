class_name SizeGrip
extends Control
## The grip in the bottom right corner of a window's status bar: dragging it resizes the window
## that it is in, from its bottom right corner.

static var _palette: Win95Palette = preload("res://win95/theme/palette.tres")
const _BOTTOM_RIGHT := 4 | 8


func _ready() -> void:
	custom_minimum_size = Vector2(12, 12)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	var window := _window()
	if mouse == null or window == null:
		return
	var at := get_global_transform_with_canvas() * mouse.position
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			window.begin_resize(_BOTTOM_RIGHT, at)
		else:
			window.end_resize()
		accept_event()
	elif mouse is InputEventMouseMotion and (mouse as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		window.resize_to(at)
		accept_event()


# Three grooves, each a light line and two shadow lines, as Win95 draws the grip.
func _draw() -> void:
	var corner := size - Vector2.ONE
	for groove in 3:
		for line in 3:
			var color := _palette.highlight_color if line == 0 else _palette.shadow_color
			var reach := 2 + groove * 4 + line
			for i in reach + 1:
				draw_rect(Rect2(corner - Vector2(reach - i, i), Vector2.ONE), color)


func _window() -> Node:
	var node := get_parent()
	while node != null and not node.has_method(&"begin_resize"):
		node = node.get_parent()
	return node

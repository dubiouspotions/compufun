class_name FolderTree
extends Control
## A Win95 folder tree, as Exchange and Explorer show it on the left: indented items with icons,
## joined by dotted lines, with a box marking each item that has items under it. Every item is
## shown expanded. A click selects an item. Put it in a FieldPanel.

## The player selected the item at [param index].
signal item_selected(index: int)


class Item:
	extends RefCounted
	var text: String = ""
	var icon: Texture2D
	## 0 for the top item; each level under it is one more.
	var depth: int = 0
	## Drawn bold, as Exchange draws a folder with unread mail.
	var bold: bool = false

	func _init(item_text: String, item_icon: Texture2D, item_depth: int, item_bold := false) -> void:
		text = item_text
		icon = item_icon
		depth = item_depth
		bold = item_bold


const _ROW_HEIGHT := 17.0
const _INDENT := 19.0
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")

## The selected item, or -1.
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()

var _items: Array[Item] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_items(items: Array[Item]) -> void:
	_items = items
	if selected >= items.size():
		selected = -1
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(0, _ROW_HEIGHT * _items.size() + 4.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
		var index := int((button.position.y - 2.0) / _ROW_HEIGHT)
		if index >= 0 and index < _items.size() and index != selected:
			selected = index
			item_selected.emit(index)


func _draw() -> void:
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var ink := get_theme_color("font_color", &"IconLabel")
	var line := Color(0.5, 0.5, 0.5)
	var highlight := (get_theme_stylebox("normal", &"IconLabelSelected") as StyleBoxFlat).bg_color
	for i in _items.size():
		var item := _items[i]
		var mid := floorf(_center_y(i))
		var icon_x := 2.0 + item.depth * _INDENT
		if item.depth > 0:
			var parent := _parent(i)
			var stem_x := 2.0 + (item.depth - 1) * _INDENT + 8.0
			_dots(Vector2(stem_x, floorf(_center_y(parent)) + 9.0), Vector2(stem_x, mid), line)
			_dots(Vector2(stem_x, mid), Vector2(icon_x - 1.0, mid), line)
		if i + 1 < _items.size() and _items[i + 1].depth > item.depth and item.depth > 0:
			_draw_box(Vector2(2.0 + (item.depth - 1) * _INDENT + 8.0, mid), ink, line)
		if item.icon:
			draw_texture(item.icon, Vector2(icon_x, mid - 8.0))
		var item_font: Font = _BOLD if item.bold else font
		var text_x := icon_x + 19.0
		var text_width := item_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var color := ink
		if i == selected:
			draw_rect(Rect2(text_x - 2.0, mid - 7.0, text_width + 4.0, 15.0), highlight)
			color = Color.WHITE
		var baseline := mid - floorf(item_font.get_height(font_size) / 2.0) + item_font.get_ascent(font_size)
		draw_string(item_font, Vector2(text_x, baseline), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _center_y(index: int) -> float:
	return 2.0 + index * _ROW_HEIGHT + _ROW_HEIGHT / 2.0


func _parent(index: int) -> int:
	for i in range(index - 1, -1, -1):
		if _items[i].depth < _items[index].depth:
			return i
	return index


# Win95's tree lines are dotted: every other pixel.
func _dots(from: Vector2, to: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
	for s in range(0, steps + 1, 2):
		draw_rect(Rect2(from.lerp(to, float(s) / maxf(steps, 1)).floor(), Vector2.ONE), color)


# The 9 x 9 box with a minus, as an expanded item has.
func _draw_box(center: Vector2, ink: Color, frame: Color) -> void:
	var box := Rect2(center - Vector2(4, 4), Vector2(9, 9))
	draw_rect(box, Color.WHITE)
	draw_rect(box.grow(-0.5), frame, false, 1.0)
	draw_rect(Rect2(center + Vector2(-2, 0), Vector2(5, 1)), ink)

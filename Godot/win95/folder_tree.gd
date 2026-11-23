class_name FolderTree
extends Control
## A Win95 tree, as Exchange and Explorer show folders on the left and Device Manager shows devices:
## indented items with icons, joined by dotted lines, with a box marking each item that has items
## under it: a minus while they show, a plus while they are hidden. A click on the box, or a double
## click on the item, shows or hides them; a click selects an item. Put it in a FieldPanel, in a
## ScrollContainer when it can grow taller than the panel.

## The player selected the item at [param index] (an index into the items given to set_items).
signal item_selected(index: int)


class Item:
	extends RefCounted
	var text: String = ""
	var icon: Texture2D
	## 0 for the top item; each level under it is one more.
	var depth: int = 0
	## Drawn bold, as Exchange draws a folder with unread mail.
	var bold: bool = false
	## The items under this one show. The player changes it.
	var expanded: bool = true
	## A yellow exclamation mark over the icon, as Device Manager marks a device with a problem.
	var warning: bool = false

	func _init(item_text: String, item_icon: Texture2D, item_depth: int, item_bold := false) -> void:
		text = item_text
		icon = item_icon
		depth = item_depth
		bold = item_bold


const _ROW_HEIGHT := 17.0
const _INDENT := 19.0
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
const _WARNING := Color(1.0, 0.85, 0.0)

## The selected item, or -1.
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()

var _items: Array[Item] = []
# The indices of the items that show, top to bottom: every item whose parents are all expanded.
var _shown: Array[int] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_items(items: Array[Item]) -> void:
	_items = items
	if selected >= items.size():
		selected = -1
	_sync_shown()


## The text of each item that shows, top to bottom.
func shown_texts() -> PackedStringArray:
	return PackedStringArray(_shown.map(func(index: int) -> String: return _items[index].text))


func _get_minimum_size() -> Vector2:
	return Vector2(0, _ROW_HEIGHT * _shown.size() + 4.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	grab_focus()
	accept_event()
	var row := int((button.position.y - 2.0) / _ROW_HEIGHT)
	if row < 0 or row >= _shown.size():
		return
	var index := _shown[row]
	var item := _items[index]
	var box := Rect2(Vector2(_stem_x(item.depth), _center_y(row)) - Vector2(5, 5), Vector2(11, 11))
	if _has_children(index) and (button.double_click or (item.depth > 0 and box.has_point(button.position))):
		item.expanded = not item.expanded
		if not item.expanded and selected > index and _is_under(selected, index):
			selected = index
			item_selected.emit(index)
		_sync_shown()
		if box.has_point(button.position):
			return
	if index != selected:
		selected = index
		item_selected.emit(index)


func _draw() -> void:
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var ink := get_theme_color("font_color", &"IconLabel")
	var line := Color(0.5, 0.5, 0.5)
	var highlight := (get_theme_stylebox("normal", &"IconLabelSelected") as StyleBoxFlat).bg_color
	for row: int in _shown.size():
		var index := _shown[row]
		var item := _items[index]
		var mid := floorf(_center_y(row))
		var icon_x := 2.0 + item.depth * _INDENT
		if item.depth > 0:
			var stem_x := _stem_x(item.depth)
			_dots(Vector2(stem_x, floorf(_center_y(_shown.find(_parent(index)))) + 9.0), Vector2(stem_x, mid), line)
			_dots(Vector2(stem_x, mid), Vector2(icon_x - 1.0, mid), line)
		if item.icon:
			draw_texture(item.icon, Vector2(icon_x, mid - 8.0))
		if item.warning:
			_draw_warning(Vector2(icon_x, mid + 1.0), ink)
		var item_font: Font = _BOLD if item.bold else font
		var text_x := icon_x + 19.0
		var text_width := item_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var color := ink
		if index == selected:
			draw_rect(Rect2(text_x - 2.0, mid - 7.0, text_width + 4.0, 15.0), highlight)
			color = Color.WHITE
		var baseline := mid - floorf(item_font.get_height(font_size) / 2.0) + item_font.get_ascent(font_size)
		draw_string(item_font, Vector2(text_x, baseline), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	# The boxes last, over the dotted lines that run past them.
	for row: int in _shown.size():
		var index := _shown[row]
		if _items[index].depth > 0 and _has_children(index):
			_draw_box(Vector2(_stem_x(_items[index].depth), floorf(_center_y(row))), ink, line, _items[index].expanded)


func _sync_shown() -> void:
	_shown.clear()
	var hidden_below := -1
	for i: int in _items.size():
		if hidden_below >= 0 and _items[i].depth > hidden_below:
			continue
		hidden_below = -1
		_shown.append(i)
		if not _items[i].expanded:
			hidden_below = _items[i].depth
	update_minimum_size()
	queue_redraw()


func _center_y(row: int) -> float:
	return 2.0 + row * _ROW_HEIGHT + _ROW_HEIGHT / 2.0


func _stem_x(depth: int) -> float:
	return 2.0 + (depth - 1) * _INDENT + 8.0


func _has_children(index: int) -> bool:
	return index + 1 < _items.size() and _items[index + 1].depth > _items[index].depth


func _is_under(index: int, ancestor: int) -> bool:
	var at := index
	while at > ancestor:
		at = _parent(at)
		if at == ancestor:
			return true
		if _items[at].depth == 0:
			return false
	return false


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


# The 9 x 9 box with a minus, or with a plus while the items under it are hidden.
func _draw_box(center: Vector2, ink: Color, frame: Color, expanded: bool) -> void:
	var box := Rect2(center - Vector2(4, 4), Vector2(9, 9))
	draw_rect(box, Color.WHITE)
	draw_rect(box.grow(-0.5), frame, false, 1.0)
	draw_rect(Rect2(center + Vector2(-2, 0), Vector2(5, 1)), ink)
	if not expanded:
		draw_rect(Rect2(center + Vector2(0, -2), Vector2(1, 5)), ink)


# Device Manager's mark of a device with a problem: a yellow disc with a black exclamation mark,
# over the bottom left of the icon.
func _draw_warning(at: Vector2, ink: Color) -> void:
	draw_circle(at + Vector2(4.5, 3.5), 4.5, ink)
	draw_circle(at + Vector2(4.5, 3.5), 3.5, _WARNING)
	draw_rect(Rect2(at + Vector2(4, 0), Vector2(1, 4)), ink)
	draw_rect(Rect2(at + Vector2(4, 5), Vector2(1, 1)), ink)

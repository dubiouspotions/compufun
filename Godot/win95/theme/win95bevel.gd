@tool
class_name Win95Bevel
extends StyleBox
## A Windows 95 edge and face, drawn as 1 px rects so it stays pixel-exact under any texture filter.

enum Kind {
	RAISED, # buttons
	SUNKEN, # 1 px well: status bar fields, progress bar
	PRESSED, # down-state of a button
	WINDOW, # window frames, menus, scrollbar thumbs
	FIELD, # 2 px recess: text fields, lists, pressed caption buttons
	TOGGLED, # a button that stays pushed in, like the active taskbar button
	DEFAULT, # the default button of a dialog: a black frame around a raised button
	TAB, # a property sheet tab: raised, with cut top corners and no bottom edge
	FLAT, # 1 px shadow outline: a pushed spin box button
}

## What fills the inside of the edge. DITHER is a checkerboard of highlight and face.
enum Fill { FACE, WINDOW, DITHER }

## The state of the button that drop_down draws; NONE draws no button.
enum DropDown { NONE, UP, PUSHED, DISABLED }

const _DROP_DOWN_WIDTH := 16

const _DITHER_SIZE := 64

static var _stock_palette := Win95Palette.new()

var _dither: ImageTexture
var _dither_colors := PackedColorArray()

@export var kind := Kind.RAISED:
	set(value):
		kind = value
		emit_changed()
@export var fill := Fill.FACE:
	set(value):
		fill = value
		emit_changed()
## Colours to draw with; null draws the stock Windows 95 colours. Share one palette to retheme every bevel at once.
@export var palette: Win95Palette:
	set(value):
		if palette:
			palette.changed.disconnect(emit_changed)
		palette = value
		if palette:
			palette.changed.connect(emit_changed)
		emit_changed()
## Draws a combo box's 16 px drop-down button, with its arrow, inside the right of the face.
@export var drop_down := DropDown.NONE:
	set(value):
		drop_down = value
		emit_changed()
## Grows the drawn edge past the rect, in pixels, without moving the content; negative shrinks it.
@export var expand_margin_left := 0.0:
	set(value):
		expand_margin_left = value
		emit_changed()
@export var expand_margin_top := 0.0:
	set(value):
		expand_margin_top = value
		emit_changed()
@export var expand_margin_right := 0.0:
	set(value):
		expand_margin_right = value
		emit_changed()
@export var expand_margin_bottom := 0.0:
	set(value):
		expand_margin_bottom = value
		emit_changed()


func _init() -> void:
	# A saved .tres can set the margins before the script attaches; only fill in unset ones.
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if get_content_margin(side) < 0:
			set_content_margin(side, 2.0)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var p := palette if palette else _stock_palette
	var drawn := _get_draw_rect(rect)
	var r := Rect2(drawn.position.round(), drawn.size.round())
	var inner := r.grow(-1)
	match kind:
		Kind.RAISED:
			_edge(to_canvas_item, r, p.highlight_color, p.dark_shadow_color)
			_edge(to_canvas_item, inner, p.light_color, p.shadow_color)
		Kind.SUNKEN:
			_edge(to_canvas_item, r, p.shadow_color, p.highlight_color)
		Kind.PRESSED:
			_edge(to_canvas_item, r, p.dark_shadow_color, p.dark_shadow_color)
			_edge(to_canvas_item, inner, p.shadow_color, p.shadow_color)
		Kind.WINDOW:
			_edge(to_canvas_item, r, p.light_color, p.dark_shadow_color)
			_edge(to_canvas_item, inner, p.highlight_color, p.shadow_color)
		Kind.FIELD:
			_edge(to_canvas_item, r, p.shadow_color, p.highlight_color)
			_edge(to_canvas_item, inner, p.dark_shadow_color, p.light_color)
		Kind.TOGGLED:
			_edge(to_canvas_item, r, p.dark_shadow_color, p.highlight_color)
			_edge(to_canvas_item, inner, p.shadow_color, p.light_color)
		Kind.DEFAULT:
			_edge(to_canvas_item, r, p.dark_shadow_color, p.dark_shadow_color)
			_edge(to_canvas_item, inner, p.highlight_color, p.dark_shadow_color)
			_edge(to_canvas_item, inner.grow(-1), p.light_color, p.shadow_color)
		Kind.TAB:
			_draw_tab(to_canvas_item, r, p)
			return
		Kind.FLAT:
			_edge(to_canvas_item, r, p.shadow_color, p.shadow_color)
	var face := inner
	if kind == Kind.DEFAULT:
		face = inner.grow(-2)
	elif kind != Kind.SUNKEN and kind != Kind.FLAT:
		face = inner.grow(-1)
	_fill(to_canvas_item, face, p)
	if drop_down != DropDown.NONE:
		_draw_drop_down(to_canvas_item, Rect2(face.end.x - _DROP_DOWN_WIDTH, face.position.y, _DROP_DOWN_WIDTH, face.size.y), p)


func _fill(ci: RID, face: Rect2, p: Win95Palette) -> void:
	if not face.has_area():
		return
	match fill:
		Fill.FACE:
			RenderingServer.canvas_item_add_rect(ci, face, p.face_color)
		Fill.WINDOW:
			RenderingServer.canvas_item_add_rect(ci, face, p.window_color)
		Fill.DITHER:
			_draw_dither(ci, face, p.highlight_color, p.face_color)


func _draw_tab(ci: RID, r: Rect2, p: Win95Palette) -> void:
	if r.size.x < 4 or r.size.y < 2:
		return
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, y + 2, 1, h - 2), p.highlight_color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + 1, y + 1, 1, 1), p.highlight_color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + 2, y, w - 4, 1), p.highlight_color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + w - 2, y + 1, 1, 1), p.dark_shadow_color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + w - 2, y + 2, 1, h - 2), p.shadow_color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + w - 1, y + 2, 1, h - 2), p.dark_shadow_color)
	_fill(ci, Rect2(x + 2, y + 1, w - 4, 1), p)
	_fill(ci, Rect2(x + 1, y + 2, w - 3, h - 2), p)


func _draw_drop_down(ci: RID, b: Rect2, p: Win95Palette) -> void:
	if b.size.y < 4:
		return
	var pushed := drop_down == DropDown.PUSHED
	if pushed:
		_edge(ci, b, p.shadow_color, p.shadow_color)
	else:
		_edge(ci, b, p.light_color, p.dark_shadow_color)
		_edge(ci, b.grow(-1), p.highlight_color, p.shadow_color)
	var face := b.grow(-1 if pushed else -2)
	if face.has_area():
		RenderingServer.canvas_item_add_rect(ci, face, p.face_color)
	var tip := b.position + Vector2(floorf((b.size.x - 7) / 2), floorf((b.size.y - 4) / 2))
	if pushed:
		tip += Vector2.ONE
	if drop_down == DropDown.DISABLED:
		_draw_arrow(ci, tip + Vector2.ONE, p.highlight_color)
		_draw_arrow(ci, tip, p.shadow_color)
	else:
		_draw_arrow(ci, tip, p.button_text_color)


# The 7 px wide down arrow of scroll and drop-down buttons, from its top left corner.
func _draw_arrow(ci: RID, at: Vector2, color: Color) -> void:
	for row in 4:
		RenderingServer.canvas_item_add_rect(ci, Rect2(at + Vector2(row, row), Vector2(7 - 2 * row, 1)), color)


# Tiles the face with regions of one cached texture; a canvas item's texture repeat is off by default.
func _draw_dither(ci: RID, face: Rect2, a: Color, b: Color) -> void:
	var colors := PackedColorArray([a, b])
	if _dither == null or _dither_colors != colors:
		var img := Image.create_empty(_DITHER_SIZE, _DITHER_SIZE, false, Image.FORMAT_RGBA8)
		for y in _DITHER_SIZE:
			for x in _DITHER_SIZE:
				img.set_pixel(x, y, a if (x + y) % 2 == 0 else b)
		if _dither == null:
			_dither = ImageTexture.create_from_image(img)
		else:
			_dither.update(img) # keeps the RID that draw commands already hold
		_dither_colors = colors
	var x := 0.0
	while x < face.size.x:
		var y := 0.0
		while y < face.size.y:
			var chunk := Vector2(minf(_DITHER_SIZE, face.size.x - x), minf(_DITHER_SIZE, face.size.y - y))
			RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(face.position + Vector2(x, y), chunk), _dither.get_rid(), Rect2(Vector2.ZERO, chunk))
			y += _DITHER_SIZE
		x += _DITHER_SIZE


# Bottom and right run the full length and cover the corners, as in Windows.
func _edge(ci: RID, r: Rect2, top_left: Color, bottom_right: Color) -> void:
	if not r.has_area():
		return
	var p := r.position
	var s := r.size
	RenderingServer.canvas_item_add_rect(ci, Rect2(p, Vector2(s.x - 1, 1)), top_left)
	RenderingServer.canvas_item_add_rect(ci, Rect2(p + Vector2(0, 1), Vector2(1, s.y - 2)), top_left)
	RenderingServer.canvas_item_add_rect(ci, Rect2(p + Vector2(0, s.y - 1), Vector2(s.x, 1)), bottom_right)
	RenderingServer.canvas_item_add_rect(ci, Rect2(p + Vector2(s.x - 1, 0), Vector2(1, s.y - 1)), bottom_right)

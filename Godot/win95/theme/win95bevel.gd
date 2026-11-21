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
}

## What fills the inside of the edge. DITHER is a checkerboard of highlight and face.
enum Fill { FACE, WINDOW, DITHER }

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


func _init() -> void:
	# A saved .tres can set the margins before the script attaches; only fill in unset ones.
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if get_content_margin(side) < 0:
			set_content_margin(side, 2.0)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var p := palette if palette else _stock_palette
	var r := Rect2(rect.position.round(), rect.size.round())
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
	var face := inner
	if kind == Kind.DEFAULT:
		face = inner.grow(-2)
	elif kind != Kind.SUNKEN:
		face = inner.grow(-1)
	if not face.has_area():
		return
	match fill:
		Fill.FACE:
			RenderingServer.canvas_item_add_rect(to_canvas_item, face, p.face_color)
		Fill.WINDOW:
			RenderingServer.canvas_item_add_rect(to_canvas_item, face, p.window_color)
		Fill.DITHER:
			_draw_dither(to_canvas_item, face, p.highlight_color, p.face_color)


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

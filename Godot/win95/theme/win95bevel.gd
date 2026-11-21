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
}

## Which palette colour fills the inside of the edge.
enum Fill { FACE, WINDOW }

static var _stock_palette := Win95Palette.new()

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
	content_margin_left = 2.0
	content_margin_top = 2.0
	content_margin_right = 2.0
	content_margin_bottom = 2.0


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
	var face := inner if kind == Kind.SUNKEN else inner.grow(-1)
	if face.has_area():
		RenderingServer.canvas_item_add_rect(to_canvas_item, face, p.window_color if fill == Fill.WINDOW else p.face_color)


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

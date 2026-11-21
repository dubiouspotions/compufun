extends Control
## The picture at the top of Display > Appearance: an inactive window, an active window and a
## message box, drawn at Win95's pixel positions in the colours of [member palette]. The desktop,
## the title bars and the text keep Windows Standard's colours, which Win95Palette doesn't hold.

const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
const _ATLAS := preload("res://win95/theme/atlas.png")
const _MINIMIZE := Rect2(60, 31, 6, 8)
const _MAXIMIZE := Rect2(67, 31, 9, 9)
const _CLOSE := Rect2(51, 31, 8, 7)
const _DESKTOP := Color("#008080")
const _ACTIVE_TITLE := Color("#000080")
const _INACTIVE_TITLE := Color("#808080")
const _INACTIVE_TITLE_TEXT := Color("#c0c0c0")
const _GRAY_TEXT := Color("#808080")
const _SELECTED := Color("#000080")

## The colours to draw with. Changing its colours redraws the picture.
var palette: Win95Palette:
	set(value):
		if palette != null:
			palette.changed.disconnect(queue_redraw)
		palette = value
		palette.changed.connect(queue_redraw)
		for bevel: Win95Bevel in _bevels.values():
			bevel.palette = palette
		queue_redraw()

var _bevels: Dictionary[Win95Bevel.Kind, Win95Bevel] = {}
var _frame := Win95Bevel.new()  # the dialog's own edge, in the colours on screen
var _dither := ImageTexture.new()


func _init() -> void:
	for kind: Win95Bevel.Kind in [Win95Bevel.Kind.FIELD, Win95Bevel.Kind.WINDOW, Win95Bevel.Kind.RAISED]:
		_bevels[kind] = Win95Bevel.new()
		_bevels[kind].kind = kind
	_bevels[Win95Bevel.Kind.FIELD].fill = Win95Bevel.Fill.WINDOW
	_frame.kind = Win95Bevel.Kind.FIELD
	_frame.palette = preload("res://win95/theme/palette.tres")
	_frame.changed.connect(queue_redraw)
	palette = Win95Palette.new()
	texture_repeat = TEXTURE_REPEAT_ENABLED
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	_frame.draw(get_canvas_item(), Rect2(0, 0, 355, 193))
	draw_rect(Rect2(2, 2, 351, 189), _DESKTOP)

	_bevel(Win95Bevel.Kind.WINDOW, Rect2(10, 10, 317, 151))
	_title(Rect2(14, 14, 309, 18), "Inactive Window", _INACTIVE_TITLE, _INACTIVE_TITLE_TEXT)

	_bevel(Win95Bevel.Kind.WINDOW, Rect2(14, 33, 335, 133))
	_title(Rect2(18, 37, 327, 18), "Active Window", _ACTIVE_TITLE, Color.WHITE)
	_text(Vector2(25, 58), "Normal", Color.BLACK)
	_text(Vector2(71, 58), "Disabled", _GRAY_TEXT)
	draw_rect(Rect2(116, 56, 54, 17), _SELECTED)
	_text(Vector2(123, 58), "Selected", Color.WHITE)
	_bevel(Win95Bevel.Kind.FIELD, Rect2(18, 74, 327, 88))
	_text(Vector2(22, 80), "Window Text", Color.BLACK, _BOLD)
	_scroll_bar(Rect2(327, 76, 16, 84))

	_bevel(Win95Bevel.Kind.WINDOW, Rect2(22, 118, 213, 69))
	_title(Rect2(25, 121, 207, 18), "Message Box", _ACTIVE_TITLE, Color.WHITE, false)
	_text(Vector2(29, 143), "Message Text", Color.BLACK)
	_bevel(Win95Bevel.Kind.RAISED, Rect2(92, 157, 72, 24))
	_text(Vector2(91, 163), "OK", Color.BLACK, _BOLD, 72)


func _title(r: Rect2, title: String, colour: Color, text_colour: Color, all_buttons := true) -> void:
	draw_rect(r, colour)
	_text(r.position + Vector2(3, 3), title, text_colour, _BOLD)
	var button := Rect2(r.end.x - 18, r.position.y + 2, 16, 14)
	_caption_button(button, _CLOSE)
	if all_buttons:
		_caption_button(Rect2(button.position.x - 18, button.position.y, 16, 14), _MAXIMIZE)
		_caption_button(Rect2(button.position.x - 34, button.position.y, 16, 14), _MINIMIZE)


func _caption_button(r: Rect2, glyph: Rect2) -> void:
	_bevel(Win95Bevel.Kind.RAISED, r)
	var at := (r.position + (r.size - glyph.size) / 2).floor()
	draw_texture_rect_region(_ATLAS, Rect2(at, glyph.size), glyph)


func _scroll_bar(r: Rect2) -> void:
	_bevel(Win95Bevel.Kind.WINDOW, Rect2(r.position, Vector2(16, 16)))
	_arrow(Vector2(r.position.x + 4, r.position.y + 6), true)
	var down := Vector2(r.position.x, r.end.y - 16)
	_bevel(Win95Bevel.Kind.WINDOW, Rect2(down, Vector2(16, 16)))
	_arrow(down + Vector2(4, 6), false)
	_update_dither()
	draw_texture_rect(_dither, Rect2(r.position.x, r.position.y + 16, 16, r.size.y - 32), true)


# Win95's 7 x 4 scroll arrow, from its top-left corner.
func _arrow(at: Vector2, up: bool) -> void:
	for row in 4:
		var width := 1 + 2 * (row if up else 3 - row)
		draw_rect(Rect2(at.x + 3 - (width - 1) / 2.0, at.y + row, width, 1), Color.BLACK)


func _update_dither() -> void:
	var img := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	for i in 4:
		img.set_pixel(i % 2, i / 2, palette.highlight_color if (i % 2 + i / 2) % 2 == 0 else palette.face_color)
	if _dither.get_width() == 2:
		_dither.update(img)
	else:
		_dither.set_image(img)


# [param width] > 0 centres the text in that many pixels from [param at].
func _text(at: Vector2, text: String, colour: Color, font: Font = null, width: float = -1) -> void:
	var f := font if font != null else get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(f, at + Vector2(0, f.get_ascent(font_size)), text, align, width, font_size, colour)


# FIELD fills with the window colour, the others with the face.
func _bevel(kind: Win95Bevel.Kind, r: Rect2) -> void:
	_bevels[kind].draw(get_canvas_item(), r)

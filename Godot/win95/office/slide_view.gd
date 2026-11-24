class_name SlideView
extends Control
## One slide of a PptDeck, drawn at the control's size in its design: the background and the text
## of its layout's placeholders, titles lined up as the design says, bullets before each paragraph. When [member editable],
## as in Slide view, an empty placeholder shows "Click to add title" in a dashed outline, and a click
## on a placeholder edits its text in place. Keep the control 4:3: the slide is 10 x 7.5 inches.

## The player changed a placeholder's text; the slide holds it already.
signal edited

## The slide's size in points; font sizes are in points of it.
const SLIDE := Vector2(720, 540)
## Where each layout's placeholders sit, in fractions of the slide: title, body, right column.
## Measured on PowerPoint 97's Default Design.
const PLACES := {
	"Title Slide": [Rect2(0.073, 0.336, 0.85, 0.164), Rect2(0.146, 0.571, 0.7, 0.25)],
	"Bulleted List": [Rect2(0.073, 0.093, 0.85, 0.164), Rect2(0.073, 0.291, 0.85, 0.597)],
	"2 Column Text": [Rect2(0.073, 0.093, 0.85, 0.164), Rect2(0.073, 0.291, 0.417, 0.597), Rect2(0.507, 0.291, 0.417, 0.597)],
	"Title Only": [Rect2(0.073, 0.093, 0.85, 0.164)],
	"Blank": [],
}
const TITLE_POINTS := 44.0
## The body's points by outline level, from the first; deeper levels take the last.
const TEXT_POINTS: Array[float] = [32.0, 28.0, 24.0, 20.0]
## The bullet of each outline level, from the first.
const BULLETS: Array[String] = ["\u2022", "\u2013", "\u2022", "\u2013"]

## Whether a click edits a placeholder, as in Slide view.
@export var editable := false

var slide: PptDeck.Slide
var design: PptDesign

var _editor: TextEdit  # edits one placeholder at a time, while it has the focus
var _editing := -1  # the placeholder that _editor edits, or -1


## Shows [param shown] in [param in_design]; null [param in_design] is the Default Design.
func show_slide(shown: PptDeck.Slide, in_design: PptDesign) -> void:
	stop_editing()
	slide = shown
	design = in_design if in_design != null else PptDesign.new()
	queue_redraw()


## Where placeholder [param index] (0 title, 1 body, 2 right column) sits on the control; an empty
## rect when the layout has none.
func place_of(index: int) -> Rect2:
	var places: Array = PLACES.get(slide.layout, []) if slide != null else []
	if index >= places.size():
		return Rect2()
	var place: Rect2 = places[index]
	var inset := design.left_inset if design != null else 0.0
	place = Rect2(place.position.x * (1.0 - inset) + inset, place.position.y, place.size.x * (1.0 - inset), place.size.y)
	return Rect2(place.position * size, place.size * size)


## Starts editing placeholder [param index] with the caret at its end.
func edit(index: int) -> void:
	if not editable or place_of(index).size == Vector2.ZERO:
		return
	stop_editing()
	_editing = index
	_editor = TextEdit.new()
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.context_menu_enabled = false
	_editor.position = place_of(index).position
	_editor.size = place_of(index).size
	var font_points := TITLE_POINTS if index == 0 else TEXT_POINTS[0]
	_editor.add_theme_font_override(&"font", design.title_font if index == 0 else design.text_font)
	_editor.add_theme_font_size_override(&"font_size", _pixels(font_points))
	_editor.add_theme_color_override(&"font_color", design.title_color if index == 0 else design.text_color)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_border_width_all(1)
	frame.border_color = Color(0.5, 0.5, 0.5)
	for style in [&"normal", &"focus"]:
		_editor.add_theme_stylebox_override(style, frame)
	_editor.text = _text_of(index)
	_editor.text_changed.connect(_store)
	_editor.focus_exited.connect(stop_editing, CONNECT_DEFERRED)
	add_child(_editor)
	_editor.grab_focus()
	_editor.set_caret_line(_editor.get_line_count() - 1)
	_editor.set_caret_column(_editor.get_line(_editor.get_line_count() - 1).length())
	queue_redraw()


## Ends editing; the slide keeps what was typed.
func stop_editing() -> void:
	if _editor != null:
		_editor.queue_free()
		_editor = null
	_editing = -1
	queue_redraw()


## The placeholder being edited, or -1.
func editing() -> int:
	return _editing


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if not editable or press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or slide == null:
		return
	for i in 3:
		if place_of(i).has_point(press.position):
			edit(i)
			accept_event()
			return
	stop_editing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		stop_editing()


func _draw() -> void:
	if design == null or slide == null:
		return
	if editable:
		draw_rect(Rect2(Vector2(6, 6), size), Color.BLACK)  # the slide's shadow on Slide view's grey
	draw_rect(Rect2(Vector2.ZERO, size), design.background_color)
	if design.background != null:
		draw_texture_rect(design.background, Rect2(Vector2.ZERO, size), false)
	for i in (PLACES.get(slide.layout, []) as Array).size():
		if i == _editing:
			continue
		var text := _text_of(i)
		if text.strip_edges() == "":
			if editable:
				_draw_prompt(i)
		elif i == 0:
			_draw_block(text, place_of(i), design.title_font, _pixels(TITLE_POINTS), design.title_color, true, design.title_align)
		elif slide.layout == "Title Slide":
			_draw_block(text, place_of(i), design.text_font, _pixels(TEXT_POINTS[0]), design.text_color, false)
		else:
			_draw_bullets(text, place_of(i))


func _draw_prompt(index: int) -> void:
	var rect := place_of(index)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(0.5, 0.5, 0.5), 1.0, 3.0)
	var prompt := "Click to add title" if index == 0 else "Click to add sub-title" if slide.layout == "Title Slide" else "Click to add text"
	var points := TITLE_POINTS if index == 0 else TEXT_POINTS[0]
	if index == 0 or slide.layout == "Title Slide":
		_draw_block(prompt, rect, design.title_font if index == 0 else design.text_font, _pixels(points), design.text_color, index == 0, design.title_align if index == 0 else HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_draw_bullets(prompt, rect)


# Lined-up text: in the middle of [param rect] when [param middle], else from its top.
func _draw_block(text: String, rect: Rect2, font: Font, font_size: int, color: Color, middle: bool, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var block := font.get_multiline_string_size(text, align, rect.size.x, font_size)
	var top := rect.position.y + (rect.size.y - block.y) / 2.0 if middle else rect.position.y
	draw_multiline_string(font, Vector2(rect.position.x, top + font.get_ascent(font_size)), text, align, rect.size.x, font_size, -1, color)


# One bullet per paragraph, the paragraph wrapped beside it; each leading tab indents a level, with
# a smaller font and the level's bullet.
func _draw_bullets(text: String, rect: Rect2) -> void:
	var font := design.text_font
	var y := rect.position.y
	for line in text.split("\n"):
		if y > rect.end.y:
			break
		var level := 0
		while level < line.length() and line[level] == "\t":
			level += 1
		var paragraph := line.substr(level)
		var font_size := _pixels(TEXT_POINTS[mini(level, TEXT_POINTS.size() - 1)])
		var left := rect.position.x + level * _pixels(TEXT_POINTS[0]) * 1.2
		var indent := font_size * 0.85
		var ascent := font.get_ascent(font_size)
		if paragraph != "":
			draw_string(font, Vector2(left, y + ascent), BULLETS[mini(level, BULLETS.size() - 1)], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, design.bullet_color)
		draw_multiline_string(font, Vector2(left + indent, y + ascent), paragraph, HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - left - indent, font_size, -1, design.text_color)
		y += font.get_multiline_string_size(paragraph if paragraph != "" else " ", HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - left - indent, font_size).y + font_size * 0.2


func _pixels(points: float) -> int:
	return maxi(1, roundi(points * size.y / SLIDE.y))


func _store() -> void:
	if _editor == null:
		return
	match _editing:
		0:
			slide.title = _editor.text
		1:
			slide.body = _editor.text.split("\n") if _editor.text != "" else PackedStringArray()
		2:
			slide.right = _editor.text.split("\n") if _editor.text != "" else PackedStringArray()
	edited.emit()


func _text_of(index: int) -> String:
	match index:
		0:
			return slide.title
		1:
			return "\n".join(slide.body)
		2:
			return "\n".join(slide.right)
	return ""

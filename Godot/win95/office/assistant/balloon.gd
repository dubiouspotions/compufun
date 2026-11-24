extends Control
## The Office Assistant's speech balloon: a pale yellow rounded box with a tail that points at the
## assistant, holding a bold heading, text, a list of choices with blue bullets and a row of round
## buttons. Office 97 shows it above the assistant, or to its left for a tip.

## The player picked a choice or a button; [param id] is the one that [method say] gave it.
signal picked(id: StringName)

const FILL := Color("#ffffcc")
const INK := Color.BLACK
const RADIUS := 8
const TAIL := Vector2(10, 12)
const _BOLD := preload("res://win95/theme/fonts/w95fa_pixel_bold.ttf")
const _BULLET := preload("res://win95/office/assistant/bullet.png")

## Where the tail points, in this control's parent's coordinates; the balloon keeps its tail there.
var aim := Vector2.ZERO
## True puts the balloon left of [member aim], with the tail on its right side; false puts it above.
var beside := false

var _box: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 8)
	add_child(_box)


## Shows [param heading] (bold; "" for none) over [param text] (BBCode, so [img] can show a
## toolbar button), with [param icon] before it (null for none), then [param choices] and
## [param buttons], each an [id, label] pair; an empty id marks one that does nothing yet (Stub), and a
## button's third item false greys it. [param width] is the width of the text in pixels.
func say(heading: String, text: String, choices: Array = [], buttons: Array = [], width: float = 110.0,
		icon: Texture2D = null) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	if heading != "":
		var title := _label(heading, width)
		title.add_theme_font_override(&"font", _BOLD)
		_box.add_child(title)
	if text != "":
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		if icon != null:
			var picture := TextureRect.new()
			picture.texture = icon
			picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(picture)
		row.add_child(_body(text, width - (icon.get_width() + 6 if icon != null else 0)))
		_box.add_child(row)
	for choice: Array in choices:
		_box.add_child(_choice(choice[0], choice[1], width))
	if not buttons.is_empty():
		var line := ColorRect.new()
		line.color = Color(0.5, 0.5, 0.5)
		line.custom_minimum_size = Vector2(width, 1)
		_box.add_child(line)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if beside else BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 8)
		for button: Array in buttons:
			row.add_child(_button(button[0], button[1], button.size() < 3 or button[2]))
		_box.add_child(row)
	place.call_deferred()


## The labels of the choices and buttons, in order; for tests.
func options() -> Array[String]:
	var labels: Array[String] = []
	for node: Node in _box.find_children("*", "BaseButton", true, false):
		if node.has_meta(&"label"):
			labels.append(node.get_meta(&"label"))
	return labels


## Presses the choice or button labelled [param label], as a click does; for tests.
func press(label: String) -> void:
	for node: Node in _box.find_children("*", "BaseButton", true, false):
		if node.get_meta(&"label", "") == label:
			(node as BaseButton).pressed.emit()
			return
	push_error("Office Assistant balloon: no choice or button \"%s\" in %s" % [label, options()])


## The heading and text together; for tests.
func text() -> String:
	var lines: Array[String] = []
	for node: Node in _box.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	for node: Node in _box.find_children("*", "RichTextLabel", true, false):
		lines.append((node as RichTextLabel).get_parsed_text())
	return "\n".join(lines)


## Sizes the balloon to what it says and puts it by [member aim]: above, with its right edge over the
## assistant's, or left of him with its bottom at his.
func place() -> void:
	var inner := _box.get_combined_minimum_size()
	var margin := Vector2(8, 8)
	size = inner + margin * 2
	_box.position = margin
	_box.size = inner
	if beside:
		position = Vector2(aim.x - TAIL.y - size.x, aim.y + 68 - size.y)
	else:
		position = Vector2(aim.x + 76 - size.x, aim.y - TAIL.y - size.y)
	var parent := get_parent() as Control
	var room := (parent.size if parent != null else size) - size
	position = position.clamp(Vector2.ZERO, room.max(Vector2.ZERO))
	queue_redraw()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = FILL
	box.border_color = INK
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS)
	box.anti_aliasing = false
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var tip := aim - position
	var tail: PackedVector2Array
	if beside:
		var y := clampf(tip.y - 12, RADIUS, size.y - RADIUS - TAIL.x)
		tail = [Vector2(size.x - 1, y), tip, Vector2(size.x - 1, y + TAIL.x)]
	else:
		var x := clampf(tip.x - 2, RADIUS, size.x - RADIUS - TAIL.x)
		tail = [Vector2(x, size.y - 1), tip, Vector2(x + TAIL.x, size.y - 1)]
	draw_colored_polygon(tail, FILL)
	draw_line(tail[0], tail[1], INK)
	draw_line(tail[1], tail[2], INK)


func _label(words: String, width: float) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	label.add_theme_color_override(&"font_color", INK)
	return label


func _body(words: String, width: float) -> RichTextLabel:
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = words
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = width
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_color_override(&"default_color", INK)
	return body


# A choice: the blue bullet and its words beside it; both take the click.
func _choice(id: StringName, words: String, width: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	var bullet := TextureButton.new()
	bullet.texture_normal = _BULLET if id != &"" else Stub.mark(_BULLET)
	bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bullet.focus_mode = Control.FOCUS_NONE
	row.add_child(bullet)
	var button := Button.new()
	button.flat = true
	button.text = words
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.x = width - _BULLET.get_width() - 7
	button.focus_mode = Control.FOCUS_NONE
	for color: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(color, INK)
	for style: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.set_meta(&"label", words)
	row.add_child(button)
	if id != &"":
		button.pressed.connect(picked.emit.bind(id))
		bullet.pressed.connect(picked.emit.bind(id))
	return row


# A button: the bullet and its label in a round-ended outline.
func _button(id: StringName, words: String, enabled: bool) -> Button:
	var button := Button.new()
	button.disabled = not enabled
	button.icon = _BULLET if id != &"" or not enabled else Stub.mark(_BULLET)
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override(&"h_separation", 5)
	var outline := StyleBoxFlat.new()
	outline.bg_color = FILL
	outline.border_color = Color(0.75, 0.75, 0.75)
	outline.set_border_width_all(1)
	outline.set_corner_radius_all(9)
	outline.anti_aliasing = false
	outline.content_margin_left = 8
	outline.content_margin_right = 12
	outline.content_margin_top = 2
	outline.content_margin_bottom = 2
	var down := outline.duplicate() as StyleBoxFlat
	down.border_color = INK
	for style: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(style, outline)
	button.add_theme_stylebox_override(&"pressed", down)
	for color: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(color, INK)
	button.add_theme_color_override(&"font_disabled_color", Color(0.6, 0.6, 0.6))
	button.add_theme_color_override(&"icon_disabled_color", Color(1, 1, 1, 0.4))
	button.set_meta(&"label", words)
	if id != &"":
		button.pressed.connect(picked.emit.bind(id))
	return button

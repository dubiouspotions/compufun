extends VBoxContainer
## The Signs tab of the debug menu: one switch per corruption sign, grouped Early, Mid and Late as
## the wiki page groups them. ON starts the sign (stage 1) and allows it; OFF takes it back (stage
## 0). A sign with more stages also shows its stage buttons. Changes last until the game quits.

const ON_COLOR: Color = Color(0.55, 1.0, 0.55)
const OFF_COLOR: Color = Color(0.62, 0.62, 0.66)
const HINT_COLOR: Color = Color(0.62, 0.62, 0.7)
const BUTTON_COLOR: Color = Color(0.24, 0.24, 0.3)
const ON_BUTTON_COLOR: Color = Color(0.2, 0.56, 0.26)
const STAGE_COLOR: Color = Color(0.72, 0.52, 0.1)
const TIMING_NAMES: Array[String] = ["EARLY  (day 1 to 3)", "MID  (day 3 to 5)", "LATE  (day 5 to 7)"]

var _rows: VBoxContainer
var _count: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	var bar := HBoxContainer.new()
	var all_on := Button.new()
	all_on.text = "All on"
	_style(all_on, BUTTON_COLOR, BUTTON_COLOR)
	all_on.pressed.connect(_set_all.bind(true))
	bar.add_child(all_on)
	var all_off := Button.new()
	all_off.text = "All off"
	_style(all_off, BUTTON_COLOR, BUTTON_COLOR)
	all_off.pressed.connect(_set_all.bind(false))
	bar.add_child(all_off)
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_count)
	add_child(bar)
	var note := Label.new()
	note.text = "ON shows a sign; the numbers choose its stage. Lasts until the game quits; the build's default is each sign's Enabled box."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override(&"font_color", HINT_COLOR)
	note.add_theme_font_size_override(&"font_size", 13)
	add_child(note)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	add_child(_rows)
	Game.changed.connect(_refresh)
	visibility_changed.connect(_refresh)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var signs := _signs()
	if signs.is_empty():
		var none := Label.new()
		none.text = "No corruption signs in this scene."
		_rows.add_child(none)
	var shown := 0
	for timing: int in TIMING_NAMES.size():
		var header := Label.new()
		header.text = TIMING_NAMES[timing]
		header.add_theme_font_size_override(&"font_size", 15)
		header.add_theme_color_override(&"font_color", Color(1.0, 0.84, 0.35))
		_rows.add_child(header)
		for each: CorruptionSign in signs:
			if each.timing != timing:
				continue
			if each.stage() > 0:
				shown += 1
			_rows.add_child(_row(each))
	_count.text = "%d of %d on" % [shown, signs.size()]


func _row(each: CorruptionSign) -> Control:
	var on := each.stage() > 0
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 4)
	var title := Label.new()
	title.text = each.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override(&"font_color", ON_COLOR if on else OFF_COLOR)
	title.tooltip_text = "%s (flag %s)" % [each.id(), each.flag()]
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(title)
	if each.stages > 1:
		for value: int in range(1, each.stages + 1):
			var stage_button := Button.new()
			stage_button.text = str(value)
			stage_button.toggle_mode = true
			stage_button.button_pressed = on and Game.flag(each.flag()) == value
			stage_button.tooltip_text = "Stage %d of %d" % [value, each.stages]
			_style(stage_button, BUTTON_COLOR, STAGE_COLOR)
			stage_button.pressed.connect(func() -> void:
				each.enabled = true
				each.set_stage(value))
			line.add_child(stage_button)
	var switch := Button.new()
	switch.toggle_mode = true
	switch.button_pressed = on
	switch.text = "ON" if on else "OFF"
	switch.custom_minimum_size = Vector2(56, 0)
	_style(switch, BUTTON_COLOR, ON_BUTTON_COLOR)
	switch.toggled.connect(_switch.bind(each))
	line.add_child(switch)
	box.add_child(line)
	if not each.hint.is_empty():
		var hint := Label.new()
		hint.text = each.hint
		hint.add_theme_color_override(&"font_color", HINT_COLOR)
		hint.add_theme_font_size_override(&"font_size", 12)
		box.add_child(hint)
	return box


# A button with a visible shape: [param normal] while up, [param pressed] while down or toggled on.
func _style(button: Button, normal: Color, pressed: Color) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		var shape := StyleBoxFlat.new()
		shape.bg_color = pressed if state in [&"pressed", &"hover_pressed"] else normal
		if state in [&"hover", &"hover_pressed"]:
			shape.bg_color = shape.bg_color.lightened(0.15)
		if state == &"focus":
			shape.draw_center = false
		shape.set_corner_radius_all(4)
		shape.content_margin_left = 8.0
		shape.content_margin_right = 8.0
		shape.content_margin_top = 2.0
		shape.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(state, shape)
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	button.add_theme_color_override(&"font_hover_pressed_color", Color.WHITE)


# ON allows the sign and starts it at stage 1, or keeps a later stage; OFF takes it back to 0.
func _switch(on: bool, each: CorruptionSign) -> void:
	if on:
		each.enabled = true
		each.set_stage(maxi(Game.flag(each.flag()), 1))
	else:
		each.set_stage(0)


func _set_all(on: bool) -> void:
	for each: CorruptionSign in _signs():
		_switch(on, each)


func _signs() -> Array[CorruptionSign]:
	var signs: Array[CorruptionSign] = []
	for node: Node in get_tree().get_nodes_in_group(CorruptionSign.GROUP):
		signs.append(node as CorruptionSign)
	return signs

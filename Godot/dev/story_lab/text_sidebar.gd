class_name StoryTextSidebar
extends VBoxContainer
## The panel beside the Story Lab's text view. Top to bottom: the portrait of the customer line under
## the cursor (or of the nearest one above it, dimmed) with its mood, voice mood and Play; every
## portrait of the customer's person, a click on one giving the line that mood; a short reference of
## the format ([constant REFERENCE]); and the week's facts, a click on one inserting it. A toggle
## folds it away, and it stays folded while the game runs.

## The writer clicked the portrait of [param mood].
signal mood_picked(mood: StringName)
## The writer clicked the fact [param flag].
signal flag_picked(flag: String)
## The writer pressed Play: the owner plays the conversation from the line in the game's dialogue box.
signal play_pressed

## The short reference under "How to write it", in plain words. A line that starts with a tab is an
## example of the format, shown as written; the others say what it means. It says what
## docs/dialogue.md says, in short, and changes with it.
const REFERENCE: String = "res://dev/story_lab/how_to_write.txt"
## The width of the unfolded sidebar, in pixels.
const WIDTH: float = 280.0
const THUMB: Vector2 = Vector2(58, 54)
## The height of the line's portrait as a share of the sidebar's width: low enough that the
## reference below it fits at 1080p.
const PORTRAIT_RATIO: float = 0.62

## True while the sidebar is folded away; it holds for every text view until the game quits.
static var folded: bool = false

var _title: Label
var _fold: Button
var _body: ScrollContainer
var _frame: Control
var _portrait: TextureRect
var _mood: Label
var _above: Label
var _play: Button
var _faces: GridContainer
var _reference: VBoxContainer
var _facts: HFlowContainer
var _person: Person
var _shown_mood: StringName = &""


func _init() -> void:
	_build()
	_show_folded()
	show_line(null, false)


## Shows the portraits of [param customer]'s person as the faces to pick from; null shows none.
func show_person(customer: Customer) -> void:
	_person = customer.person if customer != null else null
	for child: Node in _faces.get_children():
		_faces.remove_child(child)
		child.queue_free()
	if _person == null:
		_faces.add_child(LabUI.label("This customer has no portraits.", 13, LabUI.DIM))
		return
	for mood: StringName in _person.moods():
		var portrait: Texture2D = _person.portraits[mood]
		var face := Button.new()
		face.name = String(mood)
		face.custom_minimum_size = THUMB
		face.icon = portrait
		face.expand_icon = true
		face.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		face.text = String(mood)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.focus_mode = Control.FOCUS_NONE
		face.add_theme_font_size_override("font_size", 10)
		face.tooltip_text = "Give the line under the cursor the mood %s" % mood
		face.pressed.connect(func() -> void: mood_picked.emit(mood))
		_faces.add_child(face)
	_outline(_shown_mood)


## Shows [param line], a customer line, or null for none. With [param own] false it is the nearest
## line above the cursor, which the player answers, and shows dimmed.
func show_line(line: DialogueLine, own: bool) -> void:
	_shown_mood = line.mood if line != null else &""
	var portrait: Texture2D = _person.portraits.get(_shown_mood) if line != null and _person != null else null
	_portrait.texture = portrait
	_place_portrait()
	var dim := 1.0 if own or line == null else 0.45
	_frame.modulate.a = dim
	_mood.modulate.a = dim
	_above.text = "The line above, which the player answers" if line != null and not own else ""
	_play.disabled = line == null
	if line == null:
		_mood.text = "Put the cursor on a customer line to see its face."
		_mood.add_theme_color_override("font_color", LabUI.DIM)
	else:
		var has_face := portrait != null or _person == null
		_mood.text = String(line.mood) if has_face else "%s: the person has no portrait for this mood" % line.mood
		if line.voice_mood != &"":
			_mood.text += ", voice %s" % line.voice_mood
		_mood.add_theme_color_override("font_color", LabUI.TEXT if has_face else LabUI.BAD)
	_outline(_shown_mood)


## Lists [param flags] as the facts to insert.
func show_facts(flags: PackedStringArray) -> void:
	for child: Node in _facts.get_children():
		_facts.remove_child(child)
		child.queue_free()
	for flag: String in flags:
		var chip := LabUI.button(flag, func() -> void: flag_picked.emit(flag), &"ChipButton")
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_size_override("font_size", 12)
		chip.tooltip_text = "Insert this fact at the cursor"
		_facts.add_child(chip)


func _outline(mood: StringName) -> void:
	for face: Node in _faces.get_children():
		var button := face as Button
		if button == null:
			continue
		var on := StringName(button.name) == mood
		var frame := LabUI.box(LabUI.HOVER if on else LabUI.RAISED, 6, 2)
		frame.content_margin_left = 2
		frame.content_margin_right = 2
		if on:
			frame.border_color = LabUI.ACCENT
			frame.set_border_width_all(2)
		for state: String in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, frame if state != "hover" or on else LabUI.box(LabUI.HOVER, 6, 2))


# Scales the portrait to fit the frame, standing on its bottom edge, as in the dialogue box.
func _place_portrait() -> void:
	var texture := _portrait.texture
	if texture == null or _frame.size.x <= 0.0:
		return
	var scale := minf(_frame.size.x / texture.get_width(), _frame.size.y / texture.get_height())
	_portrait.size = texture.get_size() * scale
	_portrait.position = Vector2((_frame.size.x - _portrait.size.x) * 0.5, _frame.size.y - _portrait.size.y)


func _show_folded() -> void:
	_body.visible = not folded
	_title.visible = not folded
	custom_minimum_size.x = 0.0 if folded else WIDTH
	_fold.text = "<" if folded else ">"
	_fold.tooltip_text = "Show the faces, the reference and the facts" if folded else "Fold the sidebar away"


func _fill_reference() -> void:
	var file := FileAccess.open(REFERENCE, FileAccess.READ)
	if file == null:
		var why := "%s doesn't read: %s" % [REFERENCE, error_string(FileAccess.get_open_error())]
		push_error("Story Lab: " + why)
		var error := LabUI.label(why, 12, LabUI.BAD)
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reference.add_child(error)
		return
	for line: String in file.get_as_text().strip_edges(false, true).split("\n"):
		var example := line.begins_with("\t")
		var label := LabUI.label(line.substr(1).replace("\t", "    ") if example else line, 12, LabUI.TEXT if example else LabUI.DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF if example else TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = example
		if example:
			label.add_theme_color_override("font_color", LabUI.PLAYER if line.substr(1).begins_with("-") or line.substr(1).begins_with("+") else LabUI.TEXT)
		_reference.add_child(label)


func _heading(text: String) -> Label:
	var heading := LabUI.label(text, 13, LabUI.DIM)
	heading.uppercase = true
	return heading


func _build() -> void:
	add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	add_child(top)
	_title = _heading("This line")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_fold = LabUI.button("", func() -> void:
		folded = not folded
		_show_folded(), &"FlatButton")
	_fold.focus_mode = Control.FOCUS_NONE
	top.add_child(_fold)
	_body = ScrollContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_body)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_body.add_child(box)
	_frame = Control.new()
	_frame.custom_minimum_size.y = roundf(WIDTH * PORTRAIT_RATIO)
	_frame.clip_contents = true
	_frame.resized.connect(_place_portrait)
	box.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_portrait)
	var row := HBoxContainer.new()
	box.add_child(row)
	_mood = LabUI.label("", 15)
	_mood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mood.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_mood)
	_play = LabUI.button("Play", func() -> void: play_pressed.emit(), &"AccentButton")
	_play.focus_mode = Control.FOCUS_NONE
	_play.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_play.tooltip_text = "Play the conversation from this line in the game's dialogue box, choices and all (Shift+Enter)"
	row.add_child(_play)
	_above = LabUI.label("", 12, LabUI.DIM)
	_above.custom_minimum_size.y = 18
	box.add_child(_above)
	box.add_child(_heading("Faces"))
	_faces = GridContainer.new()
	_faces.columns = 4
	_faces.add_theme_constant_override("h_separation", 4)
	_faces.add_theme_constant_override("v_separation", 4)
	box.add_child(_faces)
	box.add_child(_heading("How to write it"))
	_reference = VBoxContainer.new()
	_reference.add_theme_constant_override("separation", 0)
	box.add_child(_reference)
	_fill_reference()
	box.add_child(_heading("Facts"))
	_facts = HFlowContainer.new()
	_facts.add_theme_constant_override("h_separation", 4)
	_facts.add_theme_constant_override("v_separation", 4)
	box.add_child(_facts)

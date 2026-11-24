class_name StorySignPanel
extends ScrollContainer
## The Story Lab's Signs, read-only: every corruption sign scene (corruption/<id>.tscn), grouped Early,
## Mid and Late, with how it looks, what the player must do to see it, its stages, whether it is
## switched off, and every place in the week that starts it. The scenes say how a sign looks; the
## story files say when it comes.

## The writer clicked a start on day [param day], 1 to 7.
signal day_picked(day: int)
## The writer clicked a start in the errand file [param path].
signal errand_picked(path: String)
## The writer clicked a start in the problem [param id].
signal problem_picked(id: StringName)

const TIMINGS: PackedStringArray = ["Early: days 1 to 3", "Mid: days 3 to 5", "Late: days 5 to 7"]

var _box: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)


## Every corruption sign scene, in the order of its files, as {"id", "title", "description",
## "hint", "stages", "enabled", "timing"}. A scene whose root isn't a CorruptionSign is left out
## with an error, as the shop leaves it out.
static func signs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for file: String in ResourceLoader.list_directory(CorruptionSigns.FOLDER):
		if file.get_extension() != "tscn":
			continue
		var scene := load(CorruptionSigns.FOLDER + file) as PackedScene
		var node := scene.instantiate() if scene != null else null
		var sign_node := node as CorruptionSign
		if sign_node == null:
			push_error("Story Lab: %s%s is not a CorruptionSign scene" % [CorruptionSigns.FOLDER, file])
		else:
			found.append({"id": StringName(file.get_basename()), "title": sign_node.title, "description": sign_node.description,
				"hint": sign_node.hint, "stages": sign_node.stages, "enabled": sign_node.enabled, "timing": sign_node.timing})
		if node != null:
			node.free()
	return found


## Shows every sign with its starts in [param week].
func show_signs(week: StoryFiles.Week) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var index := StoryCheck.flag_index(week)
	var all := signs()
	for timing: int in TIMINGS.size():
		_box.add_child(LabUI.label(TIMINGS[timing], 20))
		for shown: Dictionary in all:
			if shown["timing"] == timing:
				_box.add_child(_card(shown, StoryCheck.sign_starts(week, index, shown["id"])))


## Scrolls to the sign [param id] once [method show_signs] has shown it; an unknown id is an error.
func open_sign(id: StringName) -> void:
	var card := _box.get_node_or_null(NodePath(String(id))) as Control
	if card == null:
		push_error("Story Lab: no corruption sign %s in the Signs section" % id)
		return
	await get_tree().process_frame
	ensure_control_visible(card)


func _card(shown: Dictionary, found: Array[Dictionary]) -> Control:
	var card := PanelContainer.new()
	card.name = String(shown["id"])
	var style := LabUI.box(LabUI.RAISED, 10, 5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := LabUI.label(shown["title"], 17)
	head.add_child(title)
	var stages: int = shown["stages"]
	head.add_child(LabUI.chip("on or off" if stages <= 1 else "%d stages" % stages, LabUI.DIM, 11))
	if not shown["enabled"]:
		head.add_child(LabUI.chip("switched off", LabUI.BAD, 11))
		card.modulate = Color(1, 1, 1, 0.5)
		card.tooltip_text = "Switched off: it never shows, whatever starts it."
	if shown["description"] != "":
		box.add_child(_wrapped(shown["description"], 14, LabUI.TEXT))
	if shown["hint"] != "":
		box.add_child(_wrapped("To see it: " + shown["hint"], 13, LabUI.DIM))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	box.add_child(row)
	row.add_child(LabUI.label("Starts:", 13, LabUI.DIM))
	if found.is_empty():
		row.add_child(LabUI.label("Not started anywhere yet", 13, LabUI.CHANGED))
	for start: Dictionary in found:
		var link := LabUI.button(start["text"], _open.bind(start), &"FlatButton")
		link.add_theme_color_override("font_color", LabUI.PLAYER)
		link.add_theme_font_size_override("font_size", 13)
		link.tooltip_text = "Open it"
		row.add_child(link)
	return card


func _open(start: Dictionary) -> void:
	if start["day"] > 0:
		day_picked.emit(start["day"])
	elif start["errand"] != "":
		errand_picked.emit(start["errand"])
	elif start["problem"] != &"":
		problem_picked.emit(start["problem"])


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var made := LabUI.label(text, font_size, color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made

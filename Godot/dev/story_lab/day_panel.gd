class_name StoryDayPanel
extends PanelContainer
## The Story Lab's picked day: its weather, warp, the facts it remembers as it starts and at closing,
## the corruption signs that start at closing, the waits between customers, and the notes. Each
## edit that parses is a new text of the day file, which [signal saved] hands up.

## [param text], which parses, is the new text of the day file [param path].
signal saved(path: String, text: String)

const SIGNS_DIR: String = "res://corruption/"
const SETTLE_SECONDS: float = 0.4

## The known facts that the "remember" editors offer, as flag names; the Lab sets it from the week.
var facts: PackedStringArray = []

var _path: String = ""
var _filling: bool = false
var _title: Label
var _weather: ButtonGroup
var _warp: HSlider
var _warp_label: Label
var _on_start: StoryFlagsEditor
var _on_close: StoryFlagsEditor
var _signs: Dictionary[StringName, Button] = {}
var _waits: Array[SpinBox] = []
var _notes: TextEdit
var _errors: Label
var _settle: Timer


func _ready() -> void:
	_build()


## Saves at once the edit that waits for the typing to settle.
func save_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_apply()


## Opens day [param number]'s file [param path] with [param text].
func show_day(path: String, day_text: String) -> void:
	save_now()
	_path = path
	var parsed := StoryFormat.parse_day(day_text, path)
	var day := parsed.value as Day
	_filling = true
	_title.text = "Day %d" % day.number
	(_weather.get_buttons()[1 if day.rain else 0] as BaseButton).set_pressed_no_signal(true)
	_warp.set_value_no_signal(day.warp)
	_warp_label.text = str(snappedf(day.warp, 0.01))
	_on_start.facts = facts
	_on_start.edit(day.set_flags)
	_on_close.facts = facts
	_on_close.edit(day.close_flags)
	for id: StringName in _signs:
		_signs[id].set_pressed_no_signal(id in day.close_signs)
	_waits[0].set_value_no_signal(day.first_wait_seconds.x)
	_waits[1].set_value_no_signal(day.first_wait_seconds.y)
	_waits[2].set_value_no_signal(day.gap_seconds.x)
	_waits[3].set_value_no_signal(day.gap_seconds.y)
	_notes.text = day.notes
	_errors.text = "" if parsed.errors.is_empty() else "This file doesn't parse:\n" + "\n".join(parsed.errors)
	_filling = false


## The text of the day file as the fields write it, before it is checked.
func text() -> String:
	var lines := PackedStringArray()
	lines.append("weather: " + ("rain" if _weather.get_pressed_button().get_index() == 1 else "clear"))
	lines.append("warp: " + str(snappedf(_warp.value, 0.01)))
	if not _on_start.flags().is_empty():
		lines.append("on start: " + StoryFormat.write_flags(_on_start.flags()))
	if not _on_close.flags().is_empty():
		lines.append("on close: " + StoryFormat.write_flags(_on_close.flags()))
	var picked := PackedStringArray()
	for id: StringName in _signs:
		if _signs[id].button_pressed:
			picked.append(id)
	if not picked.is_empty():
		lines.append("close signs: " + ", ".join(picked))
	lines.append("first customer: %s-%s" % [_waits[0].value, _waits[1].value])
	lines.append("between customers: %s-%s" % [_waits[2].value, _waits[3].value])
	var notes := _notes.text.strip_edges(false, true)
	if notes != "":
		lines.append("notes:")
		for line: String in notes.split("\n"):
			lines.append("\t" + line)
	return "\n".join(lines) + "\n"


func _apply() -> void:
	if _filling or _path == "":
		return
	_warp_label.text = str(snappedf(_warp.value, 0.01))
	var parsed := StoryFormat.parse_day(text(), _path)
	if not parsed.errors.is_empty():
		_errors.text = "\n".join(Array(parsed.errors).map(func(e: String) -> String: return e.trim_prefix(_path + ":")))
		return
	_errors.text = ""
	saved.emit(_path, StoryFormat.write_day(parsed.value as Day))


## The corruption signs by id (their scene's file name), with their titles, read without instancing.
static func signs() -> Dictionary[StringName, String]:
	var found: Dictionary[StringName, String] = {}
	for file: String in DirAccess.get_files_at(SIGNS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var scene := load(SIGNS_DIR + file) as PackedScene
		if scene == null:
			push_error("Story Lab: %s doesn't load" % (SIGNS_DIR + file))
			continue
		var state := scene.get_state()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"title":
				found[StringName(file.get_basename())] = String(state.get_node_property_value(0, i))
	return found


func _build() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_apply)
	add_child(_settle)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 620
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_title = LabUI.label("", 24)
	left.add_child(_title)
	left.add_child(LabUI.label("Weather", 14, LabUI.DIM))
	_weather = ButtonGroup.new()
	left.add_child(LabUI.segmented(PackedStringArray(["Clear", "Rain"]), _weather))
	for button: BaseButton in _weather.get_buttons():
		button.custom_minimum_size.x = 110
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_apply())
	left.add_child(LabUI.label("Warp: how far Cambion has changed the shop", 14, LabUI.DIM))
	var warp_row := HBoxContainer.new()
	left.add_child(warp_row)
	_warp = HSlider.new()
	_warp.max_value = 1.0
	_warp.step = 0.01
	_warp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_warp.value_changed.connect(func(_v: float) -> void:
		_warp_label.text = str(snappedf(_warp.value, 0.01))
		_settle.start())
	warp_row.add_child(_warp)
	_warp_label = LabUI.label("0", 15)
	_warp_label.custom_minimum_size.x = 48
	warp_row.add_child(_warp_label)
	_on_start = _facts_field(left, "When the day starts, remember...", "Facts that become true or false as the shop opens this day")
	_on_close = _facts_field(left, "When the shop closes, remember (for the rest of the week)...", "Facts that become true or false at closing, and stay so on the next days")
	left.add_child(LabUI.label("Waits, in seconds: from the opening to the first customer, and between customers", 14, LabUI.DIM))
	var waits := HBoxContainer.new()
	waits.add_theme_constant_override("separation", 8)
	left.add_child(waits)
	for i: int in 4:
		if i == 2:
			waits.add_child(LabUI.label("   between", 14, LabUI.DIM))
		elif i == 0:
			waits.add_child(LabUI.label("first", 14, LabUI.DIM))
		var spin := SpinBox.new()
		spin.max_value = 600.0
		spin.step = 1.0
		spin.value_changed.connect(func(_v: float) -> void: _settle.start())
		waits.add_child(spin)
		_waits.append(spin)
	_errors = LabUI.label("", 13, LabUI.BAD)
	_errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_errors)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(LabUI.label("Close signs: corruption signs that start at closing and stop the next morning", 14, LabUI.DIM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	right.add_child(flow)
	var titles := signs()
	var ids := titles.keys()
	ids.sort()
	for id: StringName in ids:
		var box := Button.new()
		box.toggle_mode = true
		box.theme_type_variation = &"ChipButton"
		box.text = titles[id] if titles[id] != "" else StoryFactPicker.humanize(id)
		box.tooltip_text = "Starts at closing and stops the next morning"
		box.toggled.connect(func(_on: bool) -> void: _apply())
		flow.add_child(box)
		_signs[id] = box
	right.add_child(LabUI.label("Notes: what the day is about, for people", 14, LabUI.DIM))
	_notes = TextEdit.new()
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes.text_changed.connect(func() -> void: _settle.start())
	right.add_child(_notes)


func _facts_field(into: Control, title: String, tip: String) -> StoryFlagsEditor:
	var heading := LabUI.label(title, 14, LabUI.DIM)
	heading.tooltip_text = tip
	heading.mouse_filter = Control.MOUSE_FILTER_PASS
	into.add_child(heading)
	var field := StoryFlagsEditor.make(facts)
	field.changed.connect(func(_flags: Dictionary[StringName, int]) -> void:
		if not _filling:
			_apply())
	into.add_child(field)
	return field

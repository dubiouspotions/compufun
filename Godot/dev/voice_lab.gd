class_name VoiceLab
extends Control
## The Voice Lab, a dev tool for making voice types (VoiceType): a base voice, an alternate voice
## and a curve over the line that says where the alternate plays. The curve is drawn over the
## line's waveform, so you see which words it lands on. Each side has the four character macros
## and the most-used levers; "All levers" opens the rest. Save writes voices/types/<name>.tres,
## which the Dialogue tab gives to a conversation or a line. It speaks through ChimeraVoice, the
## engine the game uses. Open it from the Dev menu (F3 or Cmd+3), or run dev/voice_lab.tscn.
## While it is open the game is paused and its sounds are held.

const MIX_RATE: float = 22050.0
const BODIES: PackedStringArray = ["Male", "Female", "Child"]
const INTONATIONS: PackedStringArray = ["Line", "Statement", "Question", "Flat"]
const SIDES: PackedStringArray = ["Base", "Alternate"]
const CUSTOMERS: String = "res://customers"
const TYPES: String = "res://voices/types"
## The curve presets: name and points.
const CURVES: Array = [
	["Full", [Vector2(0, 1), Vector2(1, 1)]],
	["Ramp up", [Vector2(0, 0), Vector2(1, 1)]],
	["Ramp down", [Vector2(0, 1), Vector2(1, 0)]],
	["Bursts", [Vector2(0, 0), Vector2(0.18, 0), Vector2(0.22, 1), Vector2(0.34, 1), Vector2(0.38, 0), Vector2(0.6, 0), Vector2(0.64, 1), Vector2(0.76, 1), Vector2(0.8, 0), Vector2(1, 0)]],
	["End", [Vector2(0, 0), Vector2(0.7, 0), Vector2(0.8, 1), Vector2(1, 1)]],
	["Off", [Vector2(0, 0), Vector2(1, 0)]],
]
## The levers each side shows; the rest are under "All levers".
const COMMON: PackedStringArray = ["pitch", "rate", "accent", "breathiness", "roughness", "fry", "ring_mix", "metal_ms", "bits", "stutter", "static", "reverb"]

## Each lever: [key, label, min, max, step, default]. The key is the voice type's (see
## native/chimera_voice/src/voice_type.rs); a lever at its default is left out of the voice.
const GROUPS: Array = [
	["Robotic", "Flatten the human out of it", [
		["accent", "Melody", 0.0, 1.5, 0.01, 0.14],
		["drift", "Wander", 0.0, 400.0, 1.0, 5.0],
		["glide", "Glide", 0.0, 1.0, 0.005, 0.06],
		["vibrato_depth", "Warble", 0.0, 2.0, 0.01, 0.0],
		["vibrato_rate", "Warble rate", 0.0, 40.0, 0.1, 6.0],
		["tension", "Strain", 0.0, 1.0, 0.01, 0.5],
		["breathiness", "Breath", 0.0, 1.0, 0.01, 0.15],
		["ring_hz", "Ring mod", 0.0, 3000.0, 1.0, 0.0],
		["ring_mix", "Ring mod mix", 0.0, 1.0, 0.01, 0.0],
		["metal_ms", "Metal", 0.0, 20.0, 0.1, 0.0],
		["metal_fb", "Metal ring", 0.0, 0.97, 0.01, 0.6],
	]],
	["Digital", "Too few bits, the wrong clock", [
		["bits", "Bit depth", 1.0, 16.0, 1.0, 16.0],
		["hold", "Sample crush", 1.0, 64.0, 1.0, 1.0],
		["fs", "Clock mismatch", 2000.0, 60000.0, 50.0, 22050.0],
		["drive", "Clip", 1.0, 40.0, 0.1, 1.0],
	]],
	["Corrupted", "Damaged on the way", [
		["stutter", "Stutter", 0.0, 1.0, 0.01, 0.0],
		["stutter_ms", "Stutter length", 10.0, 400.0, 1.0, 80.0],
		["stutter_repeats", "Stutter repeats", 1.0, 12.0, 1.0, 3.0],
		["reverse", "Reverse", 0.0, 1.0, 0.01, 0.0],
		["dropout", "Dropouts", 0.0, 1.0, 0.01, 0.0],
		["chunk_ms", "Chunk size", 20.0, 500.0, 1.0, 120.0],
		["wobble", "Tape wobble", 0.0, 0.8, 0.01, 0.0],
		["wobble_hz", "Wobble rate", 0.1, 20.0, 0.1, 3.0],
	]],
	["Hacked", "Something else is speaking", [
		["static", "Static bursts", 0.0, 1.0, 0.01, 0.0],
		["static_level", "Static level", 0.0, 1.0, 0.01, 0.4],
		["roughness", "Grit", 0.0, 1.0, 0.01, 0.1],
		["fry", "Crackle", 0.0, 1.0, 0.01, 0.0],
		["distortion", "Distortion", 0.0, 1.0, 0.01, 0.0],
		["phaser", "Phaser", 0.0, 4.0, 0.01, 0.0],
		["chorus", "Double voice", 0.0, 1.0, 0.01, 0.0],
		["delay", "Echo", 0.0, 0.95, 0.01, 0.0],
		["reverb", "Reverb", 0.0, 1.0, 0.01, 0.0],
	]],
	["Human voice", "Chimera's body and breath", [
		["rate", "Rate", 0.2, 3.0, 0.01, 1.0],
		["pitch", "Pitch", 0.2, 3.0, 0.01, 1.0],
		["female", "Female blend", 0.0, 1.0, 0.01, 0.0],
		["child", "Child blend", 0.0, 1.0, 0.01, 0.0],
		["scale", "Size", 0.2, 3.0, 0.01, 1.0],
		["pharynx", "Pharynx", 0.2, 3.0, 0.01, 1.0],
		["tongue", "Tongue", 0.2, 3.0, 0.01, 1.0],
		["lips", "Lips", 0.2, 3.0, 0.01, 1.0],
		["folds", "Vocal folds", 0.05, 3.0, 0.01, 1.0],
		["open_phase", "Open phase", -0.3, 0.8, 0.01, 0.0],
		["pressure", "Lung pressure", -10.0, 30.0, 0.1, 7.2],
		["brightness", "Brightness", 0.0, 1.0, 0.01, 0.25],
	]],
]

const MACROS: Dictionary = {
	"Robotic": {"accent": 0.0, "drift": 0.0, "glide": 0.0, "tension": 0.9, "breathiness": 0.0, "ring_hz": 90.0, "ring_mix": 0.55, "metal_ms": 4.0, "metal_fb": 0.75},
	"Digital": {"bits": 4.0, "hold": 8.0, "fs": 16000.0, "drive": 2.5},
	"Corrupted": {"stutter": 0.4, "reverse": 0.25, "dropout": 0.15, "wobble": 0.3},
	"Hacked": {"static": 0.35, "roughness": 0.9, "fry": 0.6, "distortion": 0.6, "chorus": 0.5},
}
const UNITS: Dictionary = {"fs": " Hz", "glide": " s", "pressure": " cmH2O", "vibrato_rate": " Hz", "drift": " ct",
	"stutter_ms": " ms", "chunk_ms": " ms", "metal_ms": " ms", "ring_hz": " Hz", "wobble_hz": " Hz", "bits": " bit", "rate": "x", "pitch": "x", "shift": "x"}

const BG := Color("12141a")
const CARD := Color("1b1e26")
const RAISED := Color("262a35")
const HOVER := Color("30354a")
const LINE := Color("2f3443")
const TEXT := Color("e8eaf0")
const DIM := Color("8b92a6")
const ACCENT := Color("7c8cff")
const CHANGED := Color("ffb454")

var _engine: Object
var _type: VoiceType
## Per side (0 base, 1 alternate): every lever, by key. A lever can show twice (common and all),
## so each key holds a list of sliders.
var _sliders: Array[Dictionary] = [{}, {}]
var _macros: Array[Dictionary] = [{}, {}]
var _switches: Array[Dictionary] = [{}, {}]  # "voiced" -> CheckButton, "intonation" -> ButtonGroup
var _lines: Array = []  # [label, DialogueLine, voice]
var _pose: StringName = &"neutral"
var _samples: PackedFloat32Array = PackedFloat32Array()
var _was_paused: bool = false
var _held: Array[Node] = []
var _dragging: int = -1

var _type_picker: OptionButton
var _type_name: LineEdit
var _timeline: Control
var _text: LineEdit
var _voice: ButtonGroup
var _auto: CheckButton
var _loop: CheckButton
var _status: Label
var _all_levers: Control
var _player: AudioStreamPlayer
var _respeak: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_game()
	_type = _new_type()
	_build()
	_show_type()
	_engine = _make_engine()
	if _engine == null:
		_status.text = "No ChimeraVoice extension with voice types in this build. Run tools/build-voice.sh, then reopen."
		return
	_status.text = "Shape the base and the alternate, draw where the alternate plays, then Save."
	speak()


func _exit_tree() -> void:
	_release_game()


func _process(_delta: float) -> void:
	if _player != null and _player.playing:
		_timeline.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		speak()
	elif key.keycode == KEY_ESCAPE:
		if _all_levers.visible:
			_all_levers.hide()
		else:
			queue_free()
	else:
		return
	get_viewport().set_input_as_handled()


## Says the text through the voice type being edited, the whole line at once, and plays it.
func speak() -> void:
	if _engine == null:
		return
	var text := _text.text.strip_edges()
	if text.is_empty():
		_status.text = "Nothing to say: the line is empty."
		return
	var mood := Voices.mood(_pose)
	var started := Time.get_ticks_usec()
	_engine.set_voice_type(_type.encode())
	if _engine.start(text, _voice.get_pressed_button().get_index(), MIX_RATE, mood.rate, mood.pitch, mood.swing) <= 0:
		_status.text = "Chimera said nothing for \"%s\"." % text
		return
	_samples = PackedFloat32Array()
	while true:
		var chunk: PackedFloat32Array = _engine.render(4096)
		if chunk.is_empty():
			break
		_samples.append_array(chunk)
	_player.stream = _to_wav(_samples)
	_player.play()
	_timeline.queue_redraw()
	_status.text = "%.2f s, rendered in %.0f ms. Base %d settings, alternate %d." % [_samples.size() / MIX_RATE,
		(Time.get_ticks_usec() - started) / 1000.0, _type.base.size(), _type.alternate.size()]


# The game stops while the lab is open: the tree pauses, and every playing sound of the game is
# held, even one that runs while paused. Closing gives back exactly what was taken.
func _hold_game() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	for node in get_tree().root.find_children("*", "", true, false):
		if is_ancestor_of(node) or not node.has_method(&"get_playback_position"):
			continue
		if node.get(&"playing") and not node.get(&"stream_paused"):
			node.set(&"stream_paused", true)
			_held.append(node)


func _release_game() -> void:
	for node in _held:
		if is_instance_valid(node):
			node.set(&"stream_paused", false)
	_held.clear()
	if is_inside_tree():
		get_tree().paused = _was_paused


func _new_type() -> VoiceType:
	var t := VoiceType.new()
	t.curve = _curve_from(CURVES[3][1])
	return t


func _curve_from(points: Array) -> Curve:
	var curve := Curve.new()
	for p: Vector2 in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


func _settings(side: int) -> Dictionary:
	return _type.base if side == 0 else _type.alternate


func _value(side: int, key: String) -> float:
	return float(_settings(side).get(key, _spec(key)[5]))


func _spec(key: String) -> Array:
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			if spec[0] == key:
				return spec
	assert(false, "VoiceLab: no lever %s" % key)
	return []


# Writes a lever into a side, left out at its default so the voice stays sparse, and shows it on
# every slider of that lever.
func _set_lever(side: int, key: String, value: float) -> void:
	if is_equal_approx(value, _spec(key)[5]):
		_settings(side).erase(key)
	else:
		_settings(side)[key] = value
	for slider: HSlider in _sliders[side].get(key, []):
		slider.set_value_no_signal(value)
		_describe(slider, key)


func _store_switches(side: int) -> void:
	var voiced: CheckButton = _switches[side]["voiced"]
	if voiced.button_pressed:
		_settings(side).erase("voiced")
	else:
		_settings(side)["voiced"] = 0.0
	var tune: int = (_switches[side]["intonation"] as ButtonGroup).get_pressed_button().get_index()
	if tune == 0:
		_settings(side).erase("intonation")
	else:
		_settings(side)["intonation"] = float(tune)
	_on_changed()


# Shows the whole type on every lever, switch and macro, storing nothing.
func _show_type() -> void:
	for side in 2:
		for key: String in _sliders[side]:
			for slider: HSlider in _sliders[side][key]:
				slider.set_value_no_signal(_value(side, key))
				_describe(slider, key)
		(_switches[side]["voiced"] as CheckButton).set_pressed_no_signal(_value(side, "voiced") >= 0.5 if _settings(side).has("voiced") else true)
		var tune := int(_settings(side).get("intonation", 0.0))
		(_switches[side]["intonation"] as ButtonGroup).get_buttons()[tune].set_pressed_no_signal(true)
		for macro: String in _macros[side]:
			(_macros[side][macro] as HSlider).set_value_no_signal(0.0)
		_refresh_macros(side)
	_timeline.queue_redraw()


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
	if _loop != null and _loop.button_pressed:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


func _make_engine() -> Object:
	if not ClassDB.class_exists(&"ChimeraVoice"):
		return null
	var path := "res://voices/live/cmudict.txt.gz"
	var gz := FileAccess.get_file_as_bytes(path)
	if gz.is_empty():
		push_error("VoiceLab: can't read %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	var engine: Object = ClassDB.instantiate(&"ChimeraVoice")
	if not engine.has_method(&"set_voice_type"):
		push_error("VoiceLab: this ChimeraVoice has no set_voice_type; rebuild it with tools/build-voice.sh")
		return null
	engine.load_dict(gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	return engine if engine.is_ready() else null


func _save_type() -> void:
	var name_text := _type_name.text.strip_edges().to_snake_case().validate_filename()
	if name_text.is_empty():
		_status.text = "Name the voice type first."
		return
	var err := DirAccess.make_dir_recursive_absolute(TYPES)
	if err != OK:
		_status.text = "Can't make %s: %s" % [TYPES, error_string(err)]
		return
	var path := "%s/%s.tres" % [TYPES, name_text]
	err = ResourceSaver.save(_type, path)
	if err != OK:
		_status.text = "Can't save %s: %s" % [path, error_string(err)]
		return
	_status.text = "Saved %s. Pick it in the Dialogue tab." % path
	_fill_types(path)


func _fill_types(selected := "") -> void:
	_type_picker.clear()
	_type_picker.add_item("New voice type")
	_type_picker.set_item_metadata(0, "")
	var files := DirAccess.get_files_at(TYPES) if DirAccess.dir_exists_absolute(TYPES) else PackedStringArray()
	for file_name in files:
		if file_name.ends_with(".tres"):
			var path := TYPES.path_join(file_name)
			_type_picker.add_item(file_name.get_basename().capitalize())
			_type_picker.set_item_metadata(_type_picker.item_count - 1, path)
			if path == selected:
				_type_picker.select(_type_picker.item_count - 1)


func _pick_type(index: int) -> void:
	var path: String = _type_picker.get_item_metadata(index)
	if path.is_empty():
		_type = _new_type()
		_type_name.text = ""
	else:
		var loaded := load(path) as VoiceType
		if loaded == null:
			_status.text = "%s is not a VoiceType." % path
			return
		_type = loaded.duplicate(true) as VoiceType
		if _type.curve == null:
			_type.curve = _curve_from(CURVES[5][1])
		_type_name.text = path.get_file().get_basename()
	_show_type()
	_on_changed()


func _find_lines() -> void:
	for path: String in _resources(CUSTOMERS):
		var resource := load(path)
		var customer := resource as Customer
		if customer != null:
			for conversation: Conversation in customer.conversations:
				if conversation != null:
					for line: DialogueLine in conversation.lines:
						_lines.append(["%s · %s" % [customer.spoken_name(), line.text.left(50)], line, customer.voice])
		elif resource is Conversation:
			for line: DialogueLine in resource.lines:
				_lines.append(["Everyone · %s" % line.text.left(50), line, ""])


func _resources(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".tres"):
			found.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_resources(dir.path_join(sub)))
	return found


func _pick_line(index: int) -> void:
	if index <= 0:
		return
	var picked: Array = _lines[index - 1]
	var line: DialogueLine = picked[1]
	_text.text = line.text
	_pose = line.pose
	if picked[2] != "":
		_voice.get_buttons()[BODIES.find(String(picked[2]).capitalize())].set_pressed_no_signal(true)
	speak()


func _on_changed(_value_unused: Variant = null) -> void:
	if _auto != null and _auto.button_pressed:
		_respeak.start()


# --- The UI -----------------------------------------------------------------------------------

func _build() -> void:
	theme = _make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(BG, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	page.add_child(_top_bar())
	var line_card := _line_card()
	line_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(line_card)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	page.add_child(sides)
	for side in 2:
		sides.add_child(_side_card(side))
	_all_levers = _all_levers_panel()
	add_child(_all_levers)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_respeak = Timer.new()
	_respeak.one_shot = true
	_respeak.wait_time = 0.25
	_respeak.timeout.connect(speak)
	add_child(_respeak)
	_fill_types()


func _top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_label("Voice Lab", 28, TEXT))
	var paused := _label("  Game paused  ", 13, ACCENT)
	paused.add_theme_stylebox_override("normal", _box(Color(ACCENT, 0.14), 12, 3))
	paused.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(paused)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_type_picker = OptionButton.new()
	_type_picker.custom_minimum_size.x = 260
	_type_picker.fit_to_longest_item = false
	_type_picker.item_selected.connect(_pick_type)
	row.add_child(_type_picker)
	_type_name = LineEdit.new()
	_type_name.placeholder_text = "Name, e.g. Cambion rasp"
	_type_name.custom_minimum_size.x = 260
	row.add_child(_type_name)
	var save := Button.new()
	save.text = "Save type"
	save.theme_type_variation = &"AccentButton"
	save.pressed.connect(_save_type)
	row.add_child(save)
	var copy := Button.new()
	copy.text = "Copy"
	copy.tooltip_text = "Copy the voice type's text form"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_type.encode())
		_status.text = "Copied the voice type's text form.")
	row.add_child(copy)
	var close := Button.new()
	close.text = "Close  Esc"
	close.pressed.connect(queue_free)
	row.add_child(close)
	return row


# The line, the voice that says it, and the timeline: its waveform with the curve over it.
func _line_card() -> Control:
	var card := _card("Line", "Drag the points where the alternate should play · double-click adds one · right-click removes one")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card[1].add_child(row)
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 340
	picker.fit_to_longest_item = false
	picker.add_item("Pick a line from the game")
	_find_lines()
	for entry: Array in _lines:
		picker.add_item(entry[0])
	picker.item_selected.connect(_pick_line)
	row.add_child(picker)
	_text = LineEdit.new()
	_text.text = "Are you busy? I can go somewhere else."
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.text_submitted.connect(func(_t: String) -> void: speak())
	row.add_child(_text)
	_voice = ButtonGroup.new()
	var bodies := _segmented(BODIES, _voice)
	bodies.custom_minimum_size.x = 260
	row.add_child(bodies)
	for button in _voice.get_buttons():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_on_changed())
	_timeline = Control.new()
	_timeline.custom_minimum_size.y = 220
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_on_timeline_input)
	card[1].add_child(_timeline)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	card[1].add_child(bottom)
	var speak_button := Button.new()
	speak_button.text = "Speak  Space"
	speak_button.theme_type_variation = &"AccentButton"
	speak_button.custom_minimum_size.x = 160
	speak_button.pressed.connect(speak)
	bottom.add_child(speak_button)
	var stop := Button.new()
	stop.text = "Stop"
	stop.pressed.connect(func() -> void: _player.stop())
	bottom.add_child(stop)
	_loop = CheckButton.new()
	_loop.text = "Loop"
	_loop.toggled.connect(func(_on: bool) -> void: speak())
	bottom.add_child(_loop)
	_auto = CheckButton.new()
	_auto.text = "Speak on change"
	_auto.button_pressed = true
	bottom.add_child(_auto)
	_status = _label("", 14, DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	bottom.add_child(_status)
	bottom.add_child(_label("Curve", 14, DIM))
	for preset: Array in CURVES:
		var button := Button.new()
		button.text = preset[0]
		button.pressed.connect(func() -> void:
			_type.curve = _curve_from(preset[1])
			_timeline.queue_redraw()
			_on_changed())
		bottom.add_child(button)
	return card[0]


# One side of the type: its four macros and the common levers, two columns.
func _side_card(side: int) -> Control:
	var card := _card(SIDES[side], "Plays where the curve is low" if side == 0 else "Plays where the curve is high")
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = card[1].get_child(0)
	var all := Button.new()
	all.text = "All levers"
	all.pressed.connect(func() -> void: _open_all_levers(side))
	head.add_child(all)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func() -> void:
		_settings(side).clear()
		_show_type()
		_on_changed())
	head.add_child(reset)
	var macros := GridContainer.new()
	macros.columns = 2
	macros.add_theme_constant_override("h_separation", 24)
	macros.add_theme_constant_override("v_separation", 6)
	card[1].add_child(macros)
	for macro: String in MACROS:
		macros.add_child(_macro_row(side, macro))
	card[1].add_child(HSeparator.new())
	var levers := GridContainer.new()
	levers.columns = 2
	levers.add_theme_constant_override("h_separation", 24)
	levers.add_theme_constant_override("v_separation", 4)
	card[1].add_child(levers)
	for key in COMMON:
		levers.add_child(_slider_row(side, _spec(key)))
	return card[0]


# Every lever of one side, in columns that fit the screen; it covers the lab until closed.
func _all_levers_panel() -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side_name in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side_name, 48)
	veil.add_child(margin)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	for side in 2:
		var page := VBoxContainer.new()
		page.name = "Side%d" % side
		page.add_theme_constant_override("separation", 12)
		box.add_child(page)
		var head := HBoxContainer.new()
		page.add_child(head)
		var title := _label("All levers · %s" % SIDES[side], 22, TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var voiced := CheckButton.new()
		voiced.text = "Voiced (off whispers)"
		voiced.button_pressed = true
		voiced.toggled.connect(func(_on: bool) -> void: _store_switches(side))
		head.add_child(voiced)
		var tune := ButtonGroup.new()
		var tunes := _segmented(INTONATIONS, tune)
		tunes.custom_minimum_size.x = 380
		head.add_child(tunes)
		for button in tune.get_buttons():
			button.toggled.connect(func(on: bool) -> void:
				if on:
					_store_switches(side))
		_switches[side] = {"voiced": voiced, "intonation": tune}
		var done := Button.new()
		done.text = "Done  Esc"
		done.theme_type_variation = &"AccentButton"
		done.pressed.connect(veil.hide)
		head.add_child(done)
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 28)
		page.add_child(columns)
		for group: Array in GROUPS:
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation", 2)
			columns.add_child(column)
			column.add_child(_label(group[0], 17, TEXT))
			column.add_child(_label(group[1], 12, DIM))
			for spec: Array in group[2]:
				column.add_child(_slider_row(side, spec, true))
	return veil


func _open_all_levers(side: int) -> void:
	for page_side in 2:
		var page: Control = _all_levers.find_child("Side%d" % page_side, true, false)
		page.visible = page_side == side
	_all_levers.show()


func _macro_row(side: int, macro: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _label(macro, 16, TEXT)
	label.custom_minimum_size.x = 96
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var chip := _label("0%", 13, TEXT)
	chip.name = "Chip"
	chip.custom_minimum_size.x = 56
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(chip)
	var reset := _reset_button(func() -> void: slider.value = 0.0)
	reset.name = "Reset"
	row.add_child(reset)
	_macros[side][macro] = slider
	slider.value_changed.connect(func(_value: float) -> void:
		_refresh_macros(side)
		_apply_macro(side, macro)
		_on_changed())
	return row


func _refresh_macros(side: int) -> void:
	for macro: String in _macros[side]:
		var slider: HSlider = _macros[side][macro]
		var row := slider.get_parent()
		var chip: Label = row.get_node("Chip")
		chip.text = "%d%%" % roundi(slider.value * 100.0)
		chip.add_theme_color_override("font_color", BG if slider.value > 0.0 else TEXT)
		chip.add_theme_stylebox_override("normal", _box(ACCENT if slider.value > 0.0 else RAISED, 8, 3))
		_show_reset(row.get_node("Reset"), slider.value > 0.0)


# Sets the levers that [param moved] pulls on [param side], and only those, so a lever set by hand
# stays: each is its default plus every macro's pull toward its target.
func _apply_macro(side: int, moved: String) -> void:
	for key: String in MACROS[moved]:
		var spec := _spec(key)
		var value: float = spec[5]
		for macro: String in MACROS:
			if MACROS[macro].has(key):
				value += (_macros[side][macro] as HSlider).value * (MACROS[macro][key] - spec[5])
		_set_lever(side, key, clampf(value, spec[2], spec[3]))


## A card: a rounded panel with a title and a hint. Returns [panel, the box for its content].
func _card(title: String, hint: String) -> Array:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := _label(title, 18, TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(_label(hint, 13, DIM))
	return [panel, box]


func _segmented(options: PackedStringArray, group: ButtonGroup) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == 0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"SegmentButton"
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_on_changed())
		row.add_child(button)
	return row


func _slider_row(side: int, spec: Array, compact := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := _label(spec[1], 13 if compact else 15, TEXT)
	label.name = "Name"
	label.custom_minimum_size.x = 104 if compact else 128
	label.clip_text = true
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.value = spec[5]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var chip := _label("", 12 if compact else 13, TEXT)
	chip.name = "Value"
	chip.custom_minimum_size.x = 64 if compact else 76
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(chip)
	var reset := _reset_button(func() -> void: _set_lever(side, spec[0], spec[5]))
	reset.name = "Reset"
	reset.pressed.connect(_on_changed)
	row.add_child(reset)
	if not _sliders[side].has(spec[0]):
		_sliders[side][spec[0]] = []
	_sliders[side][spec[0]].append(slider)
	slider.value_changed.connect(func(value: float) -> void:
		_set_lever(side, spec[0], value)
		_on_changed())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.double_click:
			_set_lever(side, spec[0], spec[5])
			_on_changed())
	_describe(slider, spec[0])
	return row


# Shows a slider's value, and marks its row when it differs from the default.
func _describe(slider: HSlider, key: String) -> void:
	var spec := _spec(key)
	var row := slider.get_parent()
	var changed := not is_equal_approx(slider.value, spec[5])
	var chip: Label = row.get_node("Value")
	var shown := snappedf(slider.value, spec[4])
	chip.text = (str(int(shown)) if spec[4] >= 1.0 else str(shown)) + UNITS.get(key, "")
	chip.add_theme_color_override("font_color", BG if changed else TEXT)
	chip.add_theme_stylebox_override("normal", _box(CHANGED if changed else RAISED, 8, 3))
	(row.get_node("Name") as Label).add_theme_color_override("font_color", CHANGED if changed else TEXT)
	_show_reset(row.get_node("Reset"), changed)


## A small round button with a counter-clockwise arrow that calls [param reset]. It keeps its place
## while hidden, so rows don't shift when it shows.
func _reset_button(reset: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(28, 28)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Reset to the default"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, 14))
	button.add_theme_stylebox_override("hover", _box(HOVER, 14))
	button.add_theme_stylebox_override("pressed", _box(ACCENT, 14))
	button.add_theme_stylebox_override("disabled", _box(Color.TRANSPARENT, 14))
	button.pressed.connect(reset)
	button.draw.connect(func() -> void:
		var center := button.size / 2.0
		var color := CHANGED if not button.is_hovered() else TEXT
		button.draw_arc(center, 7.0, deg_to_rad(-60.0), deg_to_rad(230.0), 24, color, 2.0, true)
		var tip := center + Vector2.from_angle(deg_to_rad(-60.0)) * 7.0
		button.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -3), tip + Vector2(3, -4), tip + Vector2(0, 4)]), color))
	return button


func _show_reset(button: Button, changed: bool) -> void:
	button.modulate.a = 1.0 if changed else 0.0
	button.disabled = not changed
	button.mouse_filter = Control.MOUSE_FILTER_STOP if changed else Control.MOUSE_FILTER_IGNORE


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(color: Color, radius: int, pad: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad * 3
	box.content_margin_right = pad * 3
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	return box


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	var card := _box(CARD, 14, 6)
	card.content_margin_left = 20
	card.content_margin_right = 20
	card.content_margin_top = 16
	card.content_margin_bottom = 18
	card.border_color = LINE
	card.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", card)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, _box(RAISED, 10, 8))
		t.set_stylebox("hover", type, _box(HOVER, 10, 8))
		t.set_stylebox("pressed", type, _box(ACCENT.darkened(0.2), 10, 8))
		t.set_stylebox("hover_pressed", type, _box(ACCENT.darkened(0.1), 10, 8))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(state, type, TEXT)
	t.add_type(&"AccentButton")
	t.set_type_variation(&"AccentButton", &"Button")
	t.set_stylebox("normal", "AccentButton", _box(ACCENT, 10, 8))
	t.set_stylebox("hover", "AccentButton", _box(ACCENT.lightened(0.12), 10, 8))
	t.set_stylebox("pressed", "AccentButton", _box(ACCENT.darkened(0.15), 10, 8))
	t.set_color("font_color", "AccentButton", BG)
	t.set_color("font_hover_color", "AccentButton", BG)
	t.set_color("font_pressed_color", "AccentButton", BG)
	t.add_type(&"SegmentButton")
	t.set_type_variation(&"SegmentButton", &"Button")
	t.set_stylebox("normal", "SegmentButton", _box(RAISED, 0, 6))
	t.set_stylebox("hover", "SegmentButton", _box(HOVER, 0, 6))
	t.set_stylebox("pressed", "SegmentButton", _box(ACCENT, 0, 6))
	t.set_stylebox("hover_pressed", "SegmentButton", _box(ACCENT, 0, 6))
	t.set_color("font_pressed_color", "SegmentButton", BG)
	t.set_color("font_hover_pressed_color", "SegmentButton", BG)
	var field := _box(Color("0f1116"), 10, 8)
	field.border_color = LINE
	field.set_border_width_all(1)
	t.set_stylebox("normal", "TextEdit", field)
	t.set_stylebox("focus", "TextEdit", field)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	var track := _box(RAISED, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := _box(ACCENT, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(16, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _dot(18, Color.WHITE))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", _box(CARD, 10, 6))
	return t


# A round, anti-aliased dot, for slider grabbers.
func _dot(diameter: int, color: Color) -> ImageTexture:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r))
			image.set_pixel(x, y, Color(color, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


# --- The timeline: the line's waveform, and over it the curve that says where the alternate plays.

func _area() -> Rect2:
	return Rect2(Vector2(12, 12), _timeline.size - Vector2(24, 24))


func _to_screen(p: Vector2) -> Vector2:
	var r := _area()
	return Vector2(r.position.x + p.x * r.size.x, r.position.y + (1.0 - p.y) * r.size.y)


func _to_curve(at: Vector2) -> Vector2:
	var r := _area()
	return Vector2(clampf((at.x - r.position.x) / r.size.x, 0.0, 1.0), clampf(1.0 - (at.y - r.position.y) / r.size.y, 0.0, 1.0))


func _point_near(at: Vector2) -> int:
	for i in _type.curve.point_count:
		if _to_screen(_type.curve.get_point_position(i)).distance_to(at) < 12.0:
			return i
	return -1


func _on_timeline_input(event: InputEvent) -> void:
	var curve := _type.curve
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var near := _point_near(click.position)
		if click.double_click and near < 0:
			curve.add_point(_to_curve(click.position), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
			_on_changed()
		else:
			_dragging = near
	elif click and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if _dragging >= 0:
			_on_changed()
		_dragging = -1
	elif click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var near := _point_near(click.position)
		if near >= 0 and curve.point_count > 2:
			curve.remove_point(near)
			_on_changed()
	var motion := event as InputEventMouseMotion
	if motion and _dragging >= 0:
		var p := _to_curve(motion.position)
		# A point keeps its order between its neighbours.
		var low := curve.get_point_position(_dragging - 1).x if _dragging > 0 else 0.0
		var high := curve.get_point_position(_dragging + 1).x if _dragging < curve.point_count - 1 else 1.0
		curve.set_point_offset(_dragging, clampf(p.x, low, high))
		curve.set_point_value(_dragging, p.y)
	_timeline.queue_redraw()


func _draw_timeline() -> void:
	var r := _area()
	_timeline.draw_style_box(_box(Color("0f1116"), 12), Rect2(Vector2.ZERO, _timeline.size))
	var curve := _type.curve
	# Where the alternate plays: shaded from the bottom up to the curve.
	if curve != null:
		var fill := PackedVector2Array([_to_screen(Vector2(0, 0))])
		for i in 129:
			var x := i / 128.0
			fill.append(_to_screen(Vector2(x, clampf(curve.sample(x), 0.0, 1.0))))
		fill.append(_to_screen(Vector2(1, 0)))
		_timeline.draw_colored_polygon(fill, Color(CHANGED, 0.14))
	# The waveform, coloured by which voice plays there.
	if not _samples.is_empty():
		var mid := r.position.y + r.size.y * 0.5
		var played := -1.0
		if _player.playing:
			played = r.position.x + _player.get_playback_position() * MIX_RATE / _samples.size() * r.size.x
		var columns := int(r.size.x / 2.0)
		for c in columns:
			var from := int(float(c) / columns * _samples.size())
			var to := int(float(c + 1) / columns * _samples.size())
			var peak := 0.0
			for i in range(from, to):
				peak = maxf(peak, absf(_samples[i]))
			var x := r.position.x + c * 2.0
			var amount := clampf(curve.sample(float(c) / columns), 0.0, 1.0) if curve != null else 0.0
			var color := ACCENT.lerp(CHANGED, amount)
			if played >= 0.0 and x > played:
				color.a = 0.45
			var height := maxf(1.0, peak * r.size.y * 0.48)
			_timeline.draw_line(Vector2(x, mid - height), Vector2(x, mid + height), color, 1.5)
		if played >= 0.0:
			_timeline.draw_line(Vector2(played, r.position.y), Vector2(played, r.end.y), TEXT, 2.0)
	if curve == null:
		return
	var line := PackedVector2Array()
	for i in 129:
		var x := i / 128.0
		line.append(_to_screen(Vector2(x, clampf(curve.sample(x), 0.0, 1.0))))
	_timeline.draw_polyline(line, CHANGED, 2.5, true)
	for i in curve.point_count:
		var at := _to_screen(curve.get_point_position(i))
		_timeline.draw_circle(at, 7.0, TEXT)
		_timeline.draw_circle(at, 5.0, CHANGED)
	var font := get_theme_default_font()
	_timeline.draw_string(font, r.position + Vector2(6, 16), "Alternate", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CHANGED)
	_timeline.draw_string(font, Vector2(r.position.x + 6, r.end.y - 6), "Base", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENT)

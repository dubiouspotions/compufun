class_name VoiceLab
extends Control
## The Voice Lab, a dev tool for making voice types (VoiceType): a base voice, an alternate voice
## and a curve that says how much of the alternate plays across the line. The levers edit the side
## picked under Voice type; Save writes voices/types/<name>.tres, which the Dialogue tab gives to a
## conversation or a line. It speaks through ChimeraVoice, the engine the game uses, so what it
## plays is what the game plays. Open it from the Dev menu (F3 or Cmd+3), or run dev/voice_lab.tscn.
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
	["Off", [Vector2(0, 0), Vector2(1, 0)]],
]

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
## 0 edits the base voice, 1 the alternate.
var _side: int = 0
var _sliders: Dictionary = {}  # key -> HSlider
var _lines: Array = []  # [label, DialogueLine, voice]
var _pose: StringName = &"neutral"
var _samples: PackedFloat32Array = PackedFloat32Array()
var _was_paused: bool = false
var _held: Array[Node] = []

var _type_picker: OptionButton
var _type_name: LineEdit
var _sides: ButtonGroup
var _curve_edit: Control
var _dragging: int = -1
var _text: TextEdit
var _voice: ButtonGroup
var _intonation: ButtonGroup
var _voiced: CheckButton
var _auto: CheckButton
var _loop: CheckButton
var _macros: Dictionary = {}  # name -> HSlider
var _status: Label
var _wave: Control
var _player: AudioStreamPlayer
var _respeak: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_game()
	_type = _new_type()
	_build()
	_show_side()
	_engine = _make_engine()
	if _engine == null:
		_status.text = "No ChimeraVoice extension with voice types in this build. Run tools/build-voice.sh, then reopen."
		return
	_status.text = "Game paused. Shape the base, then the alternate, draw the curve, then Save."


func _exit_tree() -> void:
	_release_game()


func _process(_delta: float) -> void:
	if _player != null and _player.playing:
		_wave.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		speak()
	elif key.keycode == KEY_ESCAPE:
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
		_status.text = "Nothing to say: the text is empty."
		return
	var mood := Voices.mood(_pose)
	var started := Time.get_ticks_usec()
	_engine.set_voice_type(_type.encode())
	var count: int = _engine.start(text, _voice_index(), MIX_RATE, mood.rate, mood.pitch, mood.swing)
	if count <= 0:
		_status.text = "Chimera said nothing for \"%s\"." % text
		return
	_samples = PackedFloat32Array()
	while true:
		var chunk: PackedFloat32Array = _engine.render(4096)
		if chunk.is_empty():
			break
		_samples.append_array(chunk)
	var render_ms := (Time.get_ticks_usec() - started) / 1000.0
	_player.stream = _to_wav(_samples)
	_player.play()
	_wave.queue_redraw()
	_status.text = "%.2f s  ·  rendered in %.0f ms  ·  base %d, alternate %d settings" % [_samples.size() / MIX_RATE, render_ms, _type.base.size(), _type.alternate.size()]


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
	t.curve = _curve_from(CURVES[0][1])
	return t


func _curve_from(points: Array) -> Curve:
	var curve := Curve.new()
	for p: Vector2 in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


## The settings of the side being edited.
func _settings() -> Dictionary:
	return _type.base if _side == 0 else _type.alternate


func _voice_index() -> int:
	return _voice.get_pressed_button().get_index()


func _value(key: String) -> float:
	return (_sliders[key] as HSlider).value


func _spec(key: String) -> Array:
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			if spec[0] == key:
				return spec
	assert(false, "VoiceLab: no lever %s" % key)
	return []


# Writes a lever into the side being edited: left out at its default, so the voice stays sparse.
func _store(key: String, value: float) -> void:
	if is_equal_approx(value, _spec(key)[5]):
		_settings().erase(key)
	else:
		_settings()[key] = value


func _store_switches() -> void:
	if _voiced.button_pressed:
		_settings().erase("voiced")
	else:
		_settings()["voiced"] = 0.0
	var tune := _intonation.get_pressed_button().get_index()
	if tune == 0:
		_settings().erase("intonation")
	else:
		_settings()["intonation"] = float(tune)


# Shows the side being edited on every lever and switch, storing nothing.
func _show_side() -> void:
	var settings := _settings()
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			var slider: HSlider = _sliders[spec[0]]
			slider.set_value_no_signal(settings.get(spec[0], spec[5]))
			_describe(spec[0])
	_voiced.set_pressed_no_signal(settings.get("voiced", 1.0) >= 0.5)
	_intonation.get_buttons()[int(settings.get("intonation", 0.0))].set_pressed_no_signal(true)
	for macro: String in _macros:
		(_macros[macro] as HSlider).set_value_no_signal(0.0)
	_refresh_macro_chips()


func _set_lever(key: String, value: float) -> void:
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)
	_store(key, value)
	_describe(key)


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


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			if spec[0] in ["rate", "pitch", "fs"]:
				continue
			# Mostly leave a lever alone, so a random voice stays a voice.
			_set_lever(spec[0], rng.randf_range(spec[2], spec[3]) if rng.randf() < 0.3 else spec[5])
	speak()


func _reset() -> void:
	_settings().clear()
	_show_side()
	_on_changed()


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
			_type.curve = _curve_from(CURVES[4][1])
		_type_name.text = path.get_file().get_basename()
	_show_side()
	_curve_edit.queue_redraw()
	_on_changed()


func _find_lines() -> void:
	for path: String in _resources(CUSTOMERS):
		var resource := load(path)
		var customer := resource as Customer
		if customer != null:
			for conversation: Conversation in customer.conversations:
				if conversation != null:
					for line: DialogueLine in conversation.lines:
						_lines.append(["%s · %s · %s" % [customer.display_name, conversation.id, line.text.left(44)], line, customer.voice])
		elif resource is Conversation:
			for line: DialogueLine in resource.lines:
				_lines.append(["Everyone · %s · %s" % [resource.id, line.text.left(44)], line, ""])


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
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)
	page.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)
	body.add_child(_sidebar())
	body.add_child(_controls())
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_respeak = Timer.new()
	_respeak.one_shot = true
	_respeak.wait_time = 0.25
	_respeak.timeout.connect(speak)
	add_child(_respeak)


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(_label("Voice Lab", 30, TEXT))
	titles.add_child(_label("Make voice types: a base voice, an alternate, and when the alternate takes over.", 15, DIM))
	var paused := _label("  Game paused  ", 14, ACCENT)
	paused.add_theme_stylebox_override("normal", _box(Color(ACCENT, 0.14), 14, 4))
	paused.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(paused)
	var close := Button.new()
	close.text = "Close  Esc"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	row.add_child(close)
	return row


func _sidebar() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 452
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 16)
	scroll.add_child(side)

	var type := _card("Voice type", "Saved in voices/types/")
	side.add_child(type[0])
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	type[1].add_child(pick_row)
	_type_picker = OptionButton.new()
	_type_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_picker.fit_to_longest_item = false
	_type_picker.item_selected.connect(_pick_type)
	pick_row.add_child(_type_picker)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	type[1].add_child(name_row)
	_type_name = LineEdit.new()
	_type_name.placeholder_text = "Name, e.g. Cambion rasp"
	_type_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_type_name)
	var save := Button.new()
	save.text = "Save"
	save.theme_type_variation = &"AccentButton"
	save.pressed.connect(_save_type)
	name_row.add_child(save)
	_sides = ButtonGroup.new()
	type[1].add_child(_segmented(SIDES, _sides))
	for button in _sides.get_buttons():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_side = button.get_index()
				_show_side())
	type[1].add_child(_label("When the alternate plays, across the line", 13, DIM))
	_curve_edit = Control.new()
	_curve_edit.custom_minimum_size.y = 96
	_curve_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	_curve_edit.draw.connect(_draw_curve)
	_curve_edit.gui_input.connect(_on_curve_input)
	_curve_edit.tooltip_text = "Drag a point; double-click to add one; right-click to remove one"
	type[1].add_child(_curve_edit)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	type[1].add_child(presets)
	for preset: Array in CURVES:
		var button := Button.new()
		button.text = preset[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_type.curve = _curve_from(preset[1])
			_curve_edit.queue_redraw()
			_on_changed())
		presets.add_child(button)

	var character := _card("Character", "Moves many levers of the side")
	side.add_child(character[0])
	for macro: String in MACROS:
		character[1].add_child(_macro_row(macro))

	var say := _card("Line", "What to say")
	side.add_child(say[0])
	var picker := OptionButton.new()
	picker.add_item("Pick a line from the game")
	_find_lines()
	for entry: Array in _lines:
		picker.add_item(entry[0])
	picker.item_selected.connect(_pick_line)
	picker.fit_to_longest_item = false
	say[1].add_child(picker)
	_text = TextEdit.new()
	_text.text = "Are you busy? I can go somewhere else."
	_text.custom_minimum_size.y = 64
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.text_changed.connect(_on_changed)
	say[1].add_child(_text)
	_voice = ButtonGroup.new()
	say[1].add_child(_segmented(BODIES, _voice))
	_intonation = ButtonGroup.new()
	say[1].add_child(_segmented(INTONATIONS, _intonation))
	for button in _intonation.get_buttons():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_store_switches())
	_voiced = CheckButton.new()
	_voiced.text = "Voiced (off whispers)"
	_voiced.button_pressed = true
	_voiced.toggled.connect(func(_on: bool) -> void:
		_store_switches()
		_on_changed())
	say[1].add_child(_voiced)

	var play := _card("Play", "Space speaks")
	side.add_child(play[0])
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	play[1].add_child(transport)
	var speak_button := Button.new()
	speak_button.text = "Speak"
	speak_button.theme_type_variation = &"AccentButton"
	speak_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speak_button.pressed.connect(speak)
	transport.add_child(speak_button)
	for entry: Array in [["Stop", func() -> void: _player.stop()], ["Random", _randomize], ["Reset side", _reset]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		transport.add_child(button)
	_wave = Control.new()
	_wave.custom_minimum_size.y = 80
	_wave.draw.connect(_draw_wave)
	play[1].add_child(_wave)
	_status = _label("", 14, DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	play[1].add_child(_status)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	play[1].add_child(options)
	_auto = CheckButton.new()
	_auto.text = "Speak on change"
	_auto.button_pressed = true
	options.add_child(_auto)
	_loop = CheckButton.new()
	_loop.text = "Loop"
	_loop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loop.toggled.connect(func(_on: bool) -> void: speak())
	options.add_child(_loop)
	var copy := Button.new()
	copy.text = "Copy as text"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_type.encode())
		_status.text = "Copied the voice type's text form.")
	play[1].add_child(copy)
	_fill_types()
	return scroll


func _macro_row(macro: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(macro, 18, TEXT)
	label.custom_minimum_size.x = 110
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var chip := _label("0%", 14, TEXT)
	chip.name = "Chip"
	chip.custom_minimum_size.x = 64
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_theme_stylebox_override("normal", _box(RAISED, 8, 3))
	row.add_child(chip)
	var reset := _reset_button(func() -> void: slider.value = 0.0)
	reset.name = "Reset"
	_show_reset(reset, false)
	row.add_child(reset)
	_macros[macro] = slider
	slider.value_changed.connect(func(_value: float) -> void:
		_refresh_macro_chips()
		_apply_macro(macro)
		_on_changed())
	return row


func _refresh_macro_chips() -> void:
	for macro: String in _macros:
		var slider: HSlider = _macros[macro]
		var row := slider.get_parent()
		var chip: Label = row.get_node("Chip")
		chip.text = "%d%%" % roundi(slider.value * 100.0)
		chip.add_theme_color_override("font_color", BG if slider.value > 0.0 else TEXT)
		chip.add_theme_stylebox_override("normal", _box(ACCENT if slider.value > 0.0 else RAISED, 8, 3))
		_show_reset(row.get_node("Reset"), slider.value > 0.0)


# Sets the levers that [param moved] pulls, and only those, so a lever set by hand stays: each is its
# default plus every macro's pull toward its target.
func _apply_macro(moved: String) -> void:
	for key: String in MACROS[moved]:
		var spec := _spec(key)
		var value: float = spec[5]
		for macro: String in MACROS:
			if MACROS[macro].has(key):
				value += (_macros[macro] as HSlider).value * (MACROS[macro][key] - spec[5])
		_set_lever(key, clampf(value, spec[2], spec[3]))


func _controls() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Two columns that each stack their cards, so a short card leaves no gap beside a tall one.
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	scroll.add_child(columns)
	for i in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 20)
		columns.add_child(column)
	for g in GROUPS.size():
		var group: Array = GROUPS[g]
		var card := _card(group[0], group[1])
		columns.get_child(g % 2).add_child(card[0])
		for spec: Array in group[2]:
			card[1].add_child(_slider_row(spec))
	return scroll


## A card: a rounded panel with a title and a hint. Returns [panel, the box for its content].
func _card(title: String, hint: String) -> Array:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := _label(title, 19, TEXT)
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


func _slider_row(spec: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := _label(spec[1], 15, TEXT)
	label.name = "Name"
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.value = spec[5]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var chip := _label("", 14, TEXT)
	chip.name = "Value"
	chip.custom_minimum_size.x = 84
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(chip)
	var reset := _reset_button(func() -> void: slider.value = spec[5])
	reset.name = "Reset"
	row.add_child(reset)
	_sliders[spec[0]] = slider
	slider.value_changed.connect(func(value: float) -> void:
		_store(spec[0], value)
		_describe(spec[0])
		_on_changed())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.double_click:
			slider.value = spec[5])
	_describe(spec[0])
	return row


# Shows a lever's value, and marks it when it differs from the default.
func _describe(key: String) -> void:
	var spec := _spec(key)
	var slider: HSlider = _sliders[key]
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


# The curve editor: x is the line from start to end, y how much of the alternate plays.
func _curve_rect() -> Rect2:
	return Rect2(Vector2(8, 8), _curve_edit.size - Vector2(16, 16))


func _to_screen(p: Vector2) -> Vector2:
	var r := _curve_rect()
	return Vector2(r.position.x + p.x * r.size.x, r.position.y + (1.0 - p.y) * r.size.y)


func _to_curve(at: Vector2) -> Vector2:
	var r := _curve_rect()
	return Vector2(clampf((at.x - r.position.x) / r.size.x, 0.0, 1.0), clampf(1.0 - (at.y - r.position.y) / r.size.y, 0.0, 1.0))


func _point_near(at: Vector2) -> int:
	for i in _type.curve.point_count:
		if _to_screen(_type.curve.get_point_position(i)).distance_to(at) < 10.0:
			return i
	return -1


func _on_curve_input(event: InputEvent) -> void:
	var curve := _type.curve
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var near := _point_near(click.position)
		if click.double_click and near < 0:
			var p := _to_curve(click.position)
			curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
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
	_curve_edit.queue_redraw()


func _draw_curve() -> void:
	var r := _curve_rect()
	_curve_edit.draw_style_box(_box(Color("0f1116"), 10), Rect2(Vector2.ZERO, _curve_edit.size))
	for y in [0.0, 0.5, 1.0]:
		_curve_edit.draw_line(_to_screen(Vector2(0, y)), _to_screen(Vector2(1, y)), LINE, 1.0)
	var curve := _type.curve
	if curve == null:
		return
	var fill := PackedVector2Array([_to_screen(Vector2(0, 0))])
	for i in 65:
		var x := i / 64.0
		fill.append(_to_screen(Vector2(x, clampf(curve.sample(x), 0.0, 1.0))))
	fill.append(_to_screen(Vector2(1, 0)))
	_curve_edit.draw_colored_polygon(fill, Color(CHANGED, 0.18))
	_curve_edit.draw_polyline(fill.slice(1, fill.size() - 1), CHANGED, 2.0, true)
	for i in curve.point_count:
		var at := _to_screen(curve.get_point_position(i))
		_curve_edit.draw_circle(at, 6.0, TEXT)
		_curve_edit.draw_circle(at, 4.0, CHANGED)
	_curve_edit.draw_string(get_theme_default_font(), r.position + Vector2(4, 14), "Alternate", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
	_curve_edit.draw_string(get_theme_default_font(), Vector2(r.position.x + 4, r.end.y - 4), "Base", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)


func _draw_wave() -> void:
	var rect := Rect2(Vector2.ZERO, _wave.size)
	_wave.draw_style_box(_box(Color("0f1116"), 10), rect)
	# Behind the waveform: how much of the alternate plays at each moment.
	if _type != null and _type.curve != null:
		for x in range(4, int(rect.size.x) - 4, 4):
			var amount := clampf(_type.curve.sample(x / rect.size.x), 0.0, 1.0)
			if amount > 0.0:
				_wave.draw_rect(Rect2(x, rect.size.y * (1.0 - amount), 4, rect.size.y * amount), Color(CHANGED, 0.12))
	if _samples.is_empty():
		return
	var mid := rect.size.y * 0.5
	var played := -1.0
	if _player.playing:
		played = _player.get_playback_position() * MIX_RATE / _samples.size() * rect.size.x
	var step := maxi(1, _samples.size() / int(maxf(1.0, rect.size.x)))
	for x in range(2, int(rect.size.x) - 2, 2):
		var peak := 0.0
		for i in range(x * step, mini((x + 2) * step, _samples.size())):
			peak = maxf(peak, absf(_samples[i]))
		var height := maxf(1.0, peak * (mid - 8))
		var color := ACCENT if x <= played else Color(ACCENT, 0.45)
		_wave.draw_line(Vector2(x, mid - height), Vector2(x, mid + height), color, 1.5)
	if played >= 0.0:
		_wave.draw_line(Vector2(played, 6), Vector2(played, rect.size.y - 6), TEXT, 2.0)

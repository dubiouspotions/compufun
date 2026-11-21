class_name VoiceLab
extends Control
## The Voice Lab, a dev tool: says a line with every Chimera parameter on a slider, then runs it
## through glitch effects. Open it from the Dev menu (F3 or Cmd+3), or run ui/voice_lab.tscn.
## While it is open the game is paused and its sounds are held. It needs the ChimeraVoice extension
## (tools/build-voice.sh); the game's voices are not changed.

const MIX_RATE: float = 22050.0
const BODIES: PackedStringArray = ["Male", "Female", "Child"]
const INTONATIONS: PackedStringArray = ["Line", "Statement", "Question", "Flat"]
const CUSTOMERS: String = "res://customers"
const BUS: StringName = &"VoiceLab"

## Each slider: [key, label, min, max, step, default]. Speech keys go to start(); body and source
## keys go to set_tweaks() when they differ from their default; glitch keys are effects on the
## rendered samples; bus keys drive the effects on the VoiceLab bus.
const GROUPS: Array = [
	["Speech", "How the line is said", [
		["rate", "Rate", 0.2, 3.0, 0.01, 1.0],
		["pitch", "Pitch", 0.2, 3.0, 0.01, 1.0],
		["accent", "Pitch swing", 0.0, 1.5, 0.01, 0.14],
		["fs", "Render rate", 2000.0, 60000.0, 50.0, 22050.0],
	]],
	["Body", "The throat that says it", [
		["female", "Female blend", 0.0, 1.0, 0.01, 0.0],
		["child", "Child blend", 0.0, 1.0, 0.01, 0.0],
		["scale", "Size", 0.2, 3.0, 0.01, 1.0],
		["pharynx", "Pharynx", 0.2, 3.0, 0.01, 1.0],
		["tongue", "Tongue", 0.2, 3.0, 0.01, 1.0],
		["lips", "Lips", 0.2, 3.0, 0.01, 1.0],
		["folds", "Vocal folds", 0.05, 3.0, 0.01, 1.0],
		["open_phase", "Open phase", -0.3, 0.8, 0.01, 0.0],
	]],
	["Source", "The folds and the breath", [
		["glide", "Pitch glide", 0.0, 1.0, 0.005, 0.06],
		["pressure", "Lung pressure", -10.0, 30.0, 0.1, 7.2],
		["breathiness", "Breathiness", 0.0, 1.0, 0.01, 0.15],
		["tension", "Tension", 0.0, 1.0, 0.01, 0.5],
		["fry", "Vocal fry", 0.0, 1.0, 0.01, 0.0],
		["roughness", "Roughness", 0.0, 1.0, 0.01, 0.1],
		["vibrato_depth", "Vibrato depth", 0.0, 2.0, 0.01, 0.0],
		["vibrato_rate", "Vibrato rate", 0.0, 40.0, 0.1, 6.0],
		["drift", "Pitch drift", 0.0, 400.0, 1.0, 5.0],
		["brightness", "Brightness", 0.0, 1.0, 0.01, 0.25],
	]],
	["Glitch", "Damage to the samples", [
		["bits", "Bit depth", 1.0, 16.0, 1.0, 16.0],
		["hold", "Sample hold", 1.0, 64.0, 1.0, 1.0],
		["drive", "Clip drive", 1.0, 40.0, 0.1, 1.0],
		["stutter", "Stutter chance", 0.0, 1.0, 0.01, 0.0],
		["stutter_ms", "Stutter length", 10.0, 400.0, 1.0, 80.0],
		["stutter_repeats", "Stutter repeats", 1.0, 12.0, 1.0, 3.0],
		["reverse", "Reverse chance", 0.0, 1.0, 0.01, 0.0],
		["dropout", "Dropout chance", 0.0, 1.0, 0.01, 0.0],
		["chunk_ms", "Chunk size", 20.0, 500.0, 1.0, 120.0],
		["ring_hz", "Ring mod", 0.0, 3000.0, 1.0, 0.0],
		["ring_mix", "Ring mod mix", 0.0, 1.0, 0.01, 0.0],
		["wobble", "Tape wobble", 0.0, 0.8, 0.01, 0.0],
		["wobble_hz", "Wobble rate", 0.1, 20.0, 0.1, 3.0],
	]],
	["Space", "Effects on the way out", [
		["distortion", "Distortion", 0.0, 1.0, 0.01, 0.0],
		["shift", "Pitch shift", 0.25, 4.0, 0.01, 1.0],
		["phaser", "Phaser", 0.0, 4.0, 0.01, 0.0],
		["chorus", "Chorus", 0.0, 1.0, 0.01, 0.0],
		["delay", "Echo", 0.0, 0.95, 0.01, 0.0],
		["reverb", "Reverb", 0.0, 1.0, 0.01, 0.0],
	]],
]
const TWEAK_GROUPS: PackedStringArray = ["Body", "Source"]
const UNITS: Dictionary = {"fs": " Hz", "glide": " s", "pressure": " cmH2O", "vibrato_rate": " Hz", "drift": " ct",
	"stutter_ms": " ms", "chunk_ms": " ms", "ring_hz": " Hz", "wobble_hz": " Hz", "bits": " bit", "rate": "x", "pitch": "x", "shift": "x"}

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
var _sliders: Dictionary = {}  # key -> HSlider
var _lines: Array = []  # [label, DialogueLine, voice]
var _samples: PackedFloat32Array = PackedFloat32Array()
var _bus: int = -1
var _effects: Dictionary = {}
var _was_paused: bool = false
var _held: Array[Node] = []

var _text: TextEdit
var _voice: ButtonGroup
var _intonation: ButtonGroup
var _voiced: CheckButton
var _auto: CheckButton
var _seed: SpinBox
var _status: Label
var _wave: Control
var _player: AudioStreamPlayer
var _respeak: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_game()
	_make_bus()
	_build()
	_engine = _make_engine()
	if _engine == null:
		_status.text = "No ChimeraVoice extension in this build. Run tools/build-voice.sh, then reopen."
		return
	_status.text = "Game paused. Pick a line or type one, then Speak."


func _exit_tree() -> void:
	if _bus >= 0 and AudioServer.get_bus_index(BUS) == _bus:
		AudioServer.remove_bus(_bus)
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


## Renders the text with every setting and plays it.
func speak() -> void:
	if _engine == null:
		return
	var text := _text.text.strip_edges()
	if text.is_empty():
		_status.text = "Nothing to say: the text is empty."
		return
	_engine.set_tweaks(_tweaks())
	var started := Time.get_ticks_usec()
	var count: int = _engine.start(text, _voice_index(), _value("fs"), _value("rate"), _value("pitch"), _value("accent"))
	if count <= 0:
		_status.text = "Chimera rendered nothing for \"%s\"." % text
		return
	var raw: PackedFloat32Array = _engine.render(count)
	var render_ms := (Time.get_ticks_usec() - started) / 1000.0
	_samples = _glitch(raw)
	_player.stream = _to_wav(_samples)
	_apply_bus()
	_player.play()
	_wave.queue_redraw()
	_status.text = "%.2f s  ·  rendered in %.0f ms  ·  %d voice tweaks" % [_samples.size() / MIX_RATE, render_ms, _tweaks().size()]


## The settings as JSON, for pasting into an issue or a mood.
func settings_json() -> String:
	var values := {"text": _text.text, "voice": BODIES[_voice_index()].to_lower(), "intonation": INTONATIONS[_intonation_index()].to_lower(),
		"voiced": _voiced.button_pressed, "seed": int(_seed.value)}
	for key: String in _sliders:
		values[key] = _value(key)
	return JSON.stringify(values, "  ")


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


func _voice_index() -> int:
	return _voice.get_pressed_button().get_index()


func _intonation_index() -> int:
	return _intonation.get_pressed_button().get_index()


func _value(key: String) -> float:
	return (_sliders[key] as HSlider).value


func _spec(key: String) -> Array:
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			if spec[0] == key:
				return spec
	assert(false, "VoiceLab: no slider %s" % key)
	return []


## Body and source settings that differ from Chimera's own.
func _tweaks() -> Dictionary:
	var tweaks := {}
	for group: Array in GROUPS:
		if not group[0] in TWEAK_GROUPS:
			continue
		for spec: Array in group[2]:
			if not is_equal_approx(_value(spec[0]), spec[5]):
				tweaks[spec[0]] = _value(spec[0])
	if not _voiced.button_pressed:
		tweaks["voiced"] = false
	if _intonation_index() > 0:
		tweaks["intonation"] = INTONATIONS[_intonation_index()].to_lower()
	# A blend replaces the picked voice, so keep the picked one's weights unless set.
	if tweaks.has("female") or tweaks.has("child"):
		tweaks["female"] = _value("female") if tweaks.has("female") else (1.0 if _voice_index() == 1 else 0.0)
		tweaks["child"] = _value("child") if tweaks.has("child") else (1.0 if _voice_index() == 2 else 0.0)
	return tweaks


## The glitch effects on [param raw], in order: tape wobble, stutters, reversed and dropped chunks,
## ring mod, clip drive, sample hold, bit depth. The seed makes the random ones repeatable.
func _glitch(raw: PackedFloat32Array) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed.value)
	var out := raw
	if _value("wobble") > 0.0:
		var wobbled := PackedFloat32Array()
		var at := 0.0
		var t := 0.0
		while at < out.size() - 1:
			var i := int(at)
			wobbled.append(lerpf(out[i], out[i + 1], at - i))
			at += 1.0 + _value("wobble") * sin(TAU * _value("wobble_hz") * t)
			t += 1.0 / MIX_RATE
		out = wobbled
	var chunk := maxi(1, int(_value("chunk_ms") / 1000.0 * MIX_RATE))
	if _value("stutter") > 0.0 or _value("reverse") > 0.0 or _value("dropout") > 0.0:
		var cut := PackedFloat32Array()
		var stutter_len := maxi(1, int(_value("stutter_ms") / 1000.0 * MIX_RATE))
		for start in range(0, out.size(), chunk):
			var piece := out.slice(start, mini(start + chunk, out.size()))
			if rng.randf() < _value("reverse"):
				piece.reverse()
			if rng.randf() < _value("dropout"):
				piece.fill(0.0)
			if rng.randf() < _value("stutter"):
				var grain := piece.slice(0, mini(stutter_len, piece.size()))
				for r in int(_value("stutter_repeats")):
					cut.append_array(grain)
			cut.append_array(piece)
		out = cut
	var ring_mix := _value("ring_mix")
	var drive := _value("drive")
	var hold := int(_value("hold"))
	var levels := pow(2.0, _value("bits") - 1.0)
	var held := 0.0
	for i in out.size():
		var s := out[i]
		if ring_mix > 0.0:
			s = lerpf(s, s * sin(TAU * _value("ring_hz") * i / MIX_RATE), ring_mix)
		s = clampf(s * drive, -1.0, 1.0)
		if i % hold == 0:
			held = s
		s = held
		if levels < 32768.0:
			s = roundf(s * levels) / levels
		out[i] = s
	return out


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.data = data
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
	if not engine.has_method(&"set_tweaks"):
		push_error("VoiceLab: this ChimeraVoice has no set_tweaks; rebuild it with tools/build-voice.sh")
		return null
	engine.load_dict(gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	return engine if engine.is_ready() else null


func _make_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		_bus = AudioServer.get_bus_index(BUS)
	else:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
	for effect: AudioEffect in [AudioEffectDistortion.new(), AudioEffectPitchShift.new(), AudioEffectPhaser.new(), AudioEffectChorus.new(), AudioEffectDelay.new(), AudioEffectReverb.new()]:
		_effects[effect.get_class()] = effect
		AudioServer.add_bus_effect(_bus, effect)


func _apply_bus() -> void:
	var effects := [["AudioEffectDistortion", "distortion"], ["AudioEffectPitchShift", "shift"], ["AudioEffectPhaser", "phaser"], ["AudioEffectChorus", "chorus"], ["AudioEffectDelay", "delay"], ["AudioEffectReverb", "reverb"]]
	for i in effects.size():
		var key: String = effects[i][1]
		AudioServer.set_bus_effect_enabled(_bus, i, not is_equal_approx(_value(key), _spec(key)[5]))
	(_effects["AudioEffectDistortion"] as AudioEffectDistortion).drive = _value("distortion")
	(_effects["AudioEffectPitchShift"] as AudioEffectPitchShift).pitch_scale = _value("shift")
	(_effects["AudioEffectPhaser"] as AudioEffectPhaser).depth = _value("phaser")
	(_effects["AudioEffectChorus"] as AudioEffectChorus).wet = _value("chorus")
	var delay := _effects["AudioEffectDelay"] as AudioEffectDelay
	delay.feedback_active = _value("delay") > 0.0
	delay.feedback_level_db = linear_to_db(maxf(0.001, _value("delay")))
	(_effects["AudioEffectReverb"] as AudioEffectReverb).wet = _value("reverb")


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for group: Array in GROUPS:
		if group[0] == "Speech":
			continue
		for spec: Array in group[2]:
			# Mostly leave a knob alone, so a random voice stays a voice.
			_set_quietly(spec[0], rng.randf_range(spec[2], spec[3]) if rng.randf() < 0.35 else spec[5])
	_seed.set_value_no_signal(rng.randi_range(0, 9999))
	speak()


func _reset() -> void:
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			_set_quietly(spec[0], spec[5])
	_voiced.set_pressed_no_signal(true)
	_intonation.get_buttons()[0].set_pressed_no_signal(true)
	_on_changed()


# Sets a slider and its row without speaking for each one.
func _set_quietly(key: String, value: float) -> void:
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)
	_describe(key)


func _save_wav() -> void:
	if _samples.is_empty():
		_status.text = "Nothing to save yet: Speak first."
		return
	var dir := "user://voice_lab"
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		_status.text = "Can't make %s: %s" % [ProjectSettings.globalize_path(dir), error_string(err)]
		return
	var path := "%s/%s.wav" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	err = _to_wav(_samples).save_to_wav(path)
	_status.text = ("Saved %s" % ProjectSettings.globalize_path(path)) if err == OK else ("Can't save %s: %s" % [path, error_string(err)])


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
	if picked[2] != "":
		_voice.get_buttons()[BODIES.find(String(picked[2]).capitalize())].set_pressed_no_signal(true)
	var mood := Voices.mood(line.pose)
	_set_quietly("rate", mood.rate)
	_set_quietly("pitch", mood.pitch)
	_set_quietly("accent", mood.swing)
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
	_player.bus = BUS
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
	titles.add_child(_label("Chimera, live. Every setting is a slider; double-click a row to reset it.", 15, DIM))
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
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 440
	side.add_theme_constant_override("separation", 16)

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
	_text.custom_minimum_size.y = 96
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.text_changed.connect(_on_changed)
	say[1].add_child(_text)

	var voice := _card("Voice", "Who says it, and how it ends")
	side.add_child(voice[0])
	_voice = ButtonGroup.new()
	voice[1].add_child(_segmented(BODIES, _voice))
	_intonation = ButtonGroup.new()
	voice[1].add_child(_segmented(INTONATIONS, _intonation))
	_voiced = CheckButton.new()
	_voiced.text = "Voiced (off whispers)"
	_voiced.button_pressed = true
	_voiced.toggled.connect(_on_changed)
	voice[1].add_child(_voiced)

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
	for entry: Array in [["Stop", func() -> void: _player.stop()], ["Random", _randomize], ["Reset", _reset]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		transport.add_child(button)
	_wave = Control.new()
	_wave.custom_minimum_size.y = 96
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
	_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(_auto)
	options.add_child(_label("Seed", 15, DIM))
	_seed = SpinBox.new()
	_seed.max_value = 9999
	_seed.value_changed.connect(_on_changed)
	options.add_child(_seed)
	var files := HBoxContainer.new()
	files.add_theme_constant_override("separation", 8)
	play[1].add_child(files)
	for entry: Array in [["Copy settings", func() -> void:
			DisplayServer.clipboard_set(settings_json())
			_status.text = "Copied the settings as JSON."], ["Save WAV", _save_wav]]:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[1])
		files.add_child(button)
	return side


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
	chip.custom_minimum_size.x = 92
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(chip)
	_sliders[spec[0]] = slider
	slider.value_changed.connect(func(_v: float) -> void:
		_describe(spec[0])
		_on_changed())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.double_click:
			slider.value = spec[5])
	_describe(spec[0])
	return row


# Shows a row's value, and marks it when it differs from the default.
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


func _draw_wave() -> void:
	var rect := Rect2(Vector2.ZERO, _wave.size)
	_wave.draw_style_box(_box(Color("0f1116"), 10), rect)
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

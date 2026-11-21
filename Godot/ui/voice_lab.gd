class_name VoiceLab
extends Control
## The Voice Lab, a debug tool: says a line with every Chimera parameter on a slider, then runs it
## through glitch effects. Open it from the Dev menu (F3), or run ui/voice_lab.tscn.
## It needs the ChimeraVoice extension (tools/build-voice.sh); the game's voices are not changed.

const MIX_RATE: float = 22050.0
const BODIES: PackedStringArray = ["male", "female", "child"]
const INTONATIONS: PackedStringArray = ["(the line's own)", "statement", "question", "flat"]
const CUSTOMERS: String = "res://customers"
const BUS: StringName = &"VoiceLab"

## Each slider: [key, label, min, max, step, default]. Speech and render keys go to start();
## body and source keys go to set_tweaks() when they differ from their default; glitch keys are
## effects on the rendered samples; bus keys drive the effects on the VoiceLab bus.
const GROUPS: Array = [
	["Speech", [
		["rate", "Rate", 0.2, 3.0, 0.01, 1.0],
		["pitch", "Pitch", 0.2, 3.0, 0.01, 1.0],
		["accent", "Pitch swing", 0.0, 1.5, 0.01, 0.14],
		["fs", "Render rate (Hz; 22050 is true)", 2000.0, 60000.0, 50.0, 22050.0],
	]],
	["Body", [
		["female", "Female blend", 0.0, 1.0, 0.01, 0.0],
		["child", "Child blend", 0.0, 1.0, 0.01, 0.0],
		["scale", "Size", 0.2, 3.0, 0.01, 1.0],
		["pharynx", "Pharynx", 0.2, 3.0, 0.01, 1.0],
		["tongue", "Tongue", 0.2, 3.0, 0.01, 1.0],
		["lips", "Lips", 0.2, 3.0, 0.01, 1.0],
		["folds", "Vocal folds", 0.05, 3.0, 0.01, 1.0],
		["open_phase", "Open phase", -0.3, 0.8, 0.01, 0.0],
	]],
	["Source", [
		["glide", "Pitch glide (s)", 0.0, 1.0, 0.005, 0.06],
		["pressure", "Lung pressure", -10.0, 30.0, 0.1, 7.2],
		["breathiness", "Breathiness", 0.0, 1.0, 0.01, 0.15],
		["tension", "Tension", 0.0, 1.0, 0.01, 0.5],
		["fry", "Vocal fry", 0.0, 1.0, 0.01, 0.0],
		["roughness", "Roughness", 0.0, 1.0, 0.01, 0.1],
		["vibrato_depth", "Vibrato depth", 0.0, 2.0, 0.01, 0.0],
		["vibrato_rate", "Vibrato rate (Hz)", 0.0, 40.0, 0.1, 6.0],
		["drift", "Pitch drift (cents)", 0.0, 400.0, 1.0, 5.0],
		["brightness", "Brightness", 0.0, 1.0, 0.01, 0.25],
	]],
	["Glitch", [
		["bits", "Bit depth (16 is clean)", 1.0, 16.0, 1.0, 16.0],
		["hold", "Sample hold (1 is clean)", 1.0, 64.0, 1.0, 1.0],
		["drive", "Clip drive", 1.0, 40.0, 0.1, 1.0],
		["stutter", "Stutter chance", 0.0, 1.0, 0.01, 0.0],
		["stutter_ms", "Stutter length (ms)", 10.0, 400.0, 1.0, 80.0],
		["stutter_repeats", "Stutter repeats", 1.0, 12.0, 1.0, 3.0],
		["reverse", "Reverse chance", 0.0, 1.0, 0.01, 0.0],
		["dropout", "Dropout chance", 0.0, 1.0, 0.01, 0.0],
		["chunk_ms", "Chunk size (ms)", 20.0, 500.0, 1.0, 120.0],
		["ring_hz", "Ring mod (Hz)", 0.0, 3000.0, 1.0, 0.0],
		["ring_mix", "Ring mod mix", 0.0, 1.0, 0.01, 0.0],
		["wobble", "Tape wobble", 0.0, 0.8, 0.01, 0.0],
		["wobble_hz", "Wobble rate (Hz)", 0.1, 20.0, 0.1, 3.0],
	]],
	["Bus effects", [
		["distortion", "Distortion", 0.0, 1.0, 0.01, 0.0],
		["shift", "Pitch shift", 0.25, 4.0, 0.01, 1.0],
		["phaser", "Phaser depth", 0.0, 4.0, 0.01, 0.0],
		["chorus", "Chorus wet", 0.0, 1.0, 0.01, 0.0],
		["delay", "Echo feedback", 0.0, 0.95, 0.01, 0.0],
		["reverb", "Reverb wet", 0.0, 1.0, 0.01, 0.0],
	]],
]
const START_KEYS: PackedStringArray = ["rate", "pitch", "accent", "fs"]
const TWEAK_GROUPS: PackedStringArray = ["Body", "Source"]

var _engine: Object
var _sliders: Dictionary = {}  # key -> HSlider
var _lines: Array = []  # [label, DialogueLine, voice]
var _samples: PackedFloat32Array = PackedFloat32Array()
var _bus: int = -1
var _effects: Dictionary = {}

var _text: TextEdit
var _voice: OptionButton
var _intonation: OptionButton
var _voiced: CheckBox
var _auto: CheckBox
var _seed: SpinBox
var _status: Label
var _wave: Control
var _player: AudioStreamPlayer
var _respeak: Timer


func _ready() -> void:
	_make_bus()
	_build()
	_engine = _make_engine()
	if _engine == null:
		_status.text = "No ChimeraVoice extension in this build: run tools/build-voice.sh, then reopen."
		return
	_status.text = "Pick a line or type one, then Speak (Space with the text box unfocused)."


func _exit_tree() -> void:
	if _bus >= 0 and AudioServer.get_bus_index(BUS) == _bus:
		AudioServer.remove_bus(_bus)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		speak()
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
	var count: int = _engine.start(text, _voice.selected, _value("fs"), _value("rate"), _value("pitch"), _value("accent"))
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
	_status.text = "%.2f s of audio, rendered in %.0f ms. %d tweaks set." % [_samples.size() / MIX_RATE, render_ms, _tweaks().size()]


## The settings as JSON, for pasting into an issue or a mood.
func settings_json() -> String:
	var values := {"text": _text.text, "voice": BODIES[_voice.selected], "intonation": INTONATIONS[_intonation.selected], "voiced": _voiced.button_pressed, "seed": int(_seed.value)}
	for key: String in _sliders:
		values[key] = _value(key)
	return JSON.stringify(values, "  ")


func _value(key: String) -> float:
	return (_sliders[key] as HSlider).value


func _default(key: String) -> float:
	for group: Array in GROUPS:
		for spec: Array in group[1]:
			if spec[0] == key:
				return spec[5]
	assert(false, "VoiceLab: no slider %s" % key)
	return 0.0


## Body and source settings that differ from Chimera's own.
func _tweaks() -> Dictionary:
	var tweaks := {}
	for group: Array in GROUPS:
		if not group[0] in TWEAK_GROUPS:
			continue
		for spec: Array in group[1]:
			if not is_equal_approx(_value(spec[0]), spec[5]):
				tweaks[spec[0]] = _value(spec[0])
	if not _voiced.button_pressed:
		tweaks["voiced"] = false
	if _intonation.selected > 0:
		tweaks["intonation"] = INTONATIONS[_intonation.selected]
	# A blend replaces the picked voice, so keep the picked one's weights unless set.
	if tweaks.has("female") or tweaks.has("child"):
		tweaks["female"] = _value("female") if tweaks.has("female") else (1.0 if _voice.selected == 1 else 0.0)
		tweaks["child"] = _value("child") if tweaks.has("child") else (1.0 if _voice.selected == 2 else 0.0)
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
		AudioServer.set_bus_effect_enabled(_bus, i, not is_equal_approx(_value(key), _default(key)))
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
		for spec: Array in group[1]:
			# Mostly leave a knob alone, so a random voice stays a voice.
			if rng.randf() < 0.35:
				(_sliders[spec[0]] as HSlider).value = rng.randf_range(spec[2], spec[3])
			else:
				(_sliders[spec[0]] as HSlider).value = spec[5]
	_seed.value = rng.randi_range(0, 9999)
	speak()


func _reset() -> void:
	for group: Array in GROUPS:
		for spec: Array in group[1]:
			(_sliders[spec[0]] as HSlider).set_value_no_signal(spec[5])
			_sliders[spec[0]].value_changed.emit(spec[5])
	_voiced.button_pressed = true
	_intonation.select(0)


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
						_lines.append(["%s / %s: %s" % [customer.display_name, conversation.id, line.text.left(40)], line, customer.voice])
		elif resource is Conversation:
			for line: DialogueLine in resource.lines:
				_lines.append(["(shared) %s: %s" % [resource.id, line.text.left(40)], line, ""])


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
		_voice.select(BODIES.find(picked[2]))
	var mood := Voices.mood(line.pose)
	_sliders["rate"].value = mood.rate
	_sliders["pitch"].value = mood.pitch
	_sliders["accent"].value = mood.swing
	speak()


func _on_changed(_value_unused: Variant = null) -> void:
	if _auto != null and _auto.button_pressed:
		_respeak.start()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.08, 0.1, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page := VBoxContainer.new()
	margin.add_child(page)

	var top := HBoxContainer.new()
	page.add_child(top)
	var title := Label.new()
	title.text = "Voice Lab"
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("Pick a line from the game...")
	_find_lines()
	for entry: Array in _lines:
		picker.add_item(entry[0])
	picker.item_selected.connect(_pick_line)
	top.add_child(picker)
	_voice = OptionButton.new()
	for body in BODIES:
		_voice.add_item(body)
	_voice.item_selected.connect(_on_changed)
	top.add_child(_voice)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	top.add_child(close)

	_text = TextEdit.new()
	_text.text = "Are you busy? I can go somewhere else."
	_text.custom_minimum_size.y = 56
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	page.add_child(_text)

	var buttons := HBoxContainer.new()
	page.add_child(buttons)
	for entry: Array in [["Speak", speak], ["Stop", func() -> void: _player.stop()], ["Random glitch", _randomize], ["Reset", _reset], ["Copy settings", func() -> void:
			DisplayServer.clipboard_set(settings_json())
			_status.text = "Copied the settings as JSON."], ["Save WAV", _save_wav]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	_auto = CheckBox.new()
	_auto.text = "Speak on change"
	_auto.button_pressed = true
	buttons.add_child(_auto)
	_voiced = CheckBox.new()
	_voiced.text = "Voiced (off whispers)"
	_voiced.button_pressed = true
	_voiced.toggled.connect(_on_changed)
	buttons.add_child(_voiced)
	_intonation = OptionButton.new()
	for option in INTONATIONS:
		_intonation.add_item(option)
	_intonation.item_selected.connect(_on_changed)
	buttons.add_child(_intonation)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	buttons.add_child(seed_label)
	_seed = SpinBox.new()
	_seed.max_value = 9999
	_seed.value_changed.connect(_on_changed)
	buttons.add_child(_seed)

	_status = Label.new()
	page.add_child(_status)
	_wave = Control.new()
	_wave.custom_minimum_size.y = 80
	_wave.draw.connect(_draw_wave)
	page.add_child(_wave)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	scroll.add_child(columns)
	for group: Array in GROUPS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var heading := Label.new()
		heading.text = group[0]
		heading.add_theme_font_size_override("font_size", 20)
		column.add_child(heading)
		for spec: Array in group[1]:
			_add_slider(column, spec)

	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_respeak = Timer.new()
	_respeak.one_shot = true
	_respeak.wait_time = 0.25
	_respeak.timeout.connect(speak)
	add_child(_respeak)


func _add_slider(column: VBoxContainer, spec: Array) -> void:
	var label := Label.new()
	column.add_child(label)
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.value = spec[5]
	slider.custom_minimum_size.x = 180
	var describe := func(value: float) -> void:
		label.text = "%s: %s" % [spec[1], snappedf(value, spec[4])]
		label.modulate = Color.WHITE if is_equal_approx(value, spec[5]) else Color(1.0, 0.8, 0.3)
	describe.call(spec[5])
	slider.value_changed.connect(describe)
	slider.value_changed.connect(_on_changed)
	column.add_child(slider)
	_sliders[spec[0]] = slider


func _draw_wave() -> void:
	var rect := Rect2(Vector2.ZERO, _wave.size)
	_wave.draw_rect(rect, Color(0, 0, 0, 0.5))
	if _samples.is_empty():
		return
	var mid := rect.size.y * 0.5
	var step := maxi(1, _samples.size() / int(maxf(1.0, rect.size.x)))
	for x in int(rect.size.x):
		var peak := 0.0
		for i in range(x * step, mini((x + 1) * step, _samples.size())):
			peak = maxf(peak, absf(_samples[i]))
		_wave.draw_line(Vector2(x, mid - peak * mid), Vector2(x, mid + peak * mid), Color(0.4, 0.8, 1.0))

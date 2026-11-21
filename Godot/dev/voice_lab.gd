class_name VoiceLab
extends Control
## The Voice Lab, a dev tool for the three layers of a voice (docs: Voices.layer). A line is said by
## a person (VoicePerson: who speaks, one per character in voices/persons/), in a mood (VoiceMood: how, one per pose,
## voices/moods/), under an effect (VoiceEffect: a corruption, voices/effects/). Pick one of each
## to hear them together; the layer chosen at the top is the one the levers edit and Save writes.
## Each layer has its own levers: a person its build and timbre, a mood its delivery, an effect
## its corruption. A lever starts from what the layers below give it, and stays out of its layer
## while it sits there.
## An effect has a base, an alternate and a curve over the line that says where the alternate
## plays, drawn over the line's waveform. It speaks through ChimeraVoice, the engine the game uses.
## Open it from the Dev menu (F3 or Cmd+3), or run dev/voice_lab.tscn. While it is open the game
## is paused and its sounds are held.

const MIX_RATE: float = 22050.0
const BODIES: PackedStringArray = ["Male", "Female", "Child"]
const INTONATIONS: PackedStringArray = ["Line", "Statement", "Question", "Flat"]
const SIDES: PackedStringArray = ["Base", "Alternate"]
const LAYERS: PackedStringArray = ["Person", "Mood", "Effect"]
const CUSTOMERS: String = "res://customers"
## What the levers edit: the effect's two sides, the person and the mood.
enum { BASE, ALT, PERSON, MOOD }
## The levers of a person: its build and timbre.
const PERSON_KEYS: PackedStringArray = ["female", "child", "scale", "pharynx", "tongue", "lips", "folds", "open_phase",
	"pressure", "brightness", "pitch", "rate", "breathiness", "roughness", "tension", "fry", "glide", "drift", "vibrato_depth", "vibrato_rate"]
## The levers of a mood. Rate, pitch and melody are the mood's own fields; the rest are settings.
const MOOD_KEYS: PackedStringArray = ["rate", "pitch", "accent", "tension", "breathiness", "roughness", "pressure", "brightness", "fry", "glide", "drift", "vibrato_depth"]
const MOOD_FIELDS: Dictionary = {"rate": "rate", "pitch": "pitch", "accent": "swing"}
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
## Effects only: the person and the mood own the human voice.
const COMMON: PackedStringArray = ["tune", "ring_mix", "metal_ms", "bits", "hold", "stutter", "dropout", "static", "wobble", "distortion", "chorus", "reverb"]
## The lever group that belongs to persons and moods, left out of an effect's levers.
const HUMAN_GROUP: String = "Human voice"

## Each lever: [key, label, min, max, step, default]. The key is the voice type's (see
## native/chimera_voice/src/voice_type.rs); a lever at its default is left out of the voice.
const GROUPS: Array = [
	["Robotic", "Flatten the human out of it", [
		["accent", "Melody", 0.0, 1.5, 0.01, 0.14],
		["tune", "Tune", 0.0, 1.0, 0.01, 0.0],
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
## The working copies of the three layers; Save writes the one being edited.
var _person: VoicePerson
var _mood: VoiceMood
var _effect: VoiceEffect
## The layer the levers edit: 0 person, 1 mood, 2 effect.
var _layer: int = 0
## Per target (BASE, ALT, PERSON, MOOD): every lever, by key. A lever can show twice (common and
## all), so each key holds a list of sliders.
var _sliders: Array[Dictionary] = [{}, {}, {}, {}]
var _macros: Array[Dictionary] = [{}, {}]
## Per target: "voiced" -> CheckButton, "intonation" -> ButtonGroup, "body" -> ButtonGroup.
var _switches: Array[Dictionary] = [{}, {}, {}, {}]
var _lines: Array = []  # [label, DialogueLine, VoicePerson or null, VoiceEffect or null]
var _samples: PackedFloat32Array = PackedFloat32Array()
var _was_paused: bool = false
var _held: Array[Node] = []
var _dragging: int = -1

## Per layer: the picker of saved ones, and what each item is (a path, or a pose for moods).
var _pickers: Array[OptionButton] = []
var _picked: Array[Array] = [[], [], []]
var _tabs: ButtonGroup
var _name: LineEdit
var _save: Button
var _cards: Array[Control] = []
var _timeline: Control
var _text: LineEdit
var _auto: CheckButton
var _loop: CheckButton
var _status: Label
var _all_levers: Control
var _player: AudioStreamPlayer
var _respeak: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_game()
	_person = VoicePerson.new()
	_mood = VoiceMood.new()
	_effect = _new_effect()
	_build()
	_pick(0, 1 if _picked[0].size() > 1 else 0)  # the first character, not a new person
	_pick(1, _picked[1].find(&"neutral"))
	_pick(2, 0)
	_show_layer(0)
	_engine = _make_engine()
	if _engine == null:
		_status.text = "No ChimeraVoice extension with voice types in this build. Run tools/build-voice.sh, then reopen."
		return
	_status.text = "Pick a person, a mood and an effect; edit one of them, then Save."
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


## Says the text through all three layers, the whole line at once, and plays it.
func speak() -> void:
	if _engine == null:
		return
	var text := _text.text.strip_edges()
	if text.is_empty():
		_status.text = "Nothing to say: the line is empty."
		return
	var started := Time.get_ticks_usec()
	_engine.set_voice_type(Voices.layer(_person, _mood, _effect))
	if _engine.start(text, VoicePlayer.BODIES.get(_person.body, 0), MIX_RATE, _mood.rate, _mood.pitch, _mood.swing) <= 0:
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
	_status.text = "%.2f s, rendered in %.0f ms. Person %d settings, mood %d, effect %d + %d." % [_samples.size() / MIX_RATE,
		(Time.get_ticks_usec() - started) / 1000.0, _person.settings.size(), _mood.settings.size(), _effect.base.size(), _effect.alternate.size()]


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


func _new_effect() -> VoiceEffect:
	var effect := VoiceEffect.new()
	effect.curve = _curve_from(CURVES[3][1])
	return effect


func _curve_from(points: Array) -> Curve:
	var curve := Curve.new()
	for p: Vector2 in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


func _settings(target: int) -> Dictionary:
	return [_effect.base, _effect.alternate, _person.settings, _mood.settings][target]


func _value(target: int, key: String) -> float:
	if target == MOOD and MOOD_FIELDS.has(key):
		return _mood.get(MOOD_FIELDS[key])
	return float(_settings(target).get(key, _below(target, key)))


# What a lever of [param target] is when the layer leaves it out: the value the layers under it
# give, or Chimera's. A lever at this value stays out of its layer, and Reset returns to it.
func _below(target: int, key: String) -> float:
	var value: float = _spec(key)[5]
	if target == PERSON or (target == MOOD and MOOD_FIELDS.has(key)):
		return value
	value = _person.settings.get(key, value)
	if target == MOOD:
		return value
	if key == "accent":
		value = _mood.swing  # an effect's melody sits on the mood's pitch swing
	return _mood.settings.get(key, value)


# The layer that gives [param target]'s lever its value from below, or "" when it is Chimera's.
func _below_from(target: int, key: String) -> String:
	if target in [BASE, ALT] and (_mood.settings.has(key) or key == "accent"):
		return "mood"
	if target in [MOOD, BASE, ALT] and not (target == MOOD and MOOD_FIELDS.has(key)) and _person.settings.has(key):
		return "person"
	return ""


func _spec(key: String) -> Array:
	for group: Array in GROUPS:
		for spec: Array in group[2]:
			if spec[0] == key:
				return spec
	assert(false, "VoiceLab: no lever %s" % key)
	return []


# Writes a lever into a target, left out at its default so the layer stays sparse, and shows it on
# every slider of that lever. A mood's rate, pitch and melody are its own fields.
func _set_lever(target: int, key: String, value: float) -> void:
	if target == MOOD and MOOD_FIELDS.has(key):
		_mood.set(MOOD_FIELDS[key], value)
	elif is_equal_approx(value, _below(target, key)):
		_settings(target).erase(key)
	else:
		_settings(target)[key] = value
	for slider: HSlider in _sliders[target].get(key, []):
		slider.set_value_no_signal(value)
		_describe(slider, target, key)


func _store_switches(target: int) -> void:
	var switches := _switches[target]
	if switches.has("voiced"):
		if (switches["voiced"] as CheckButton).button_pressed:
			_settings(target).erase("voiced")
		else:
			_settings(target)["voiced"] = 0.0
	if switches.has("intonation"):
		var tune: int = (switches["intonation"] as ButtonGroup).get_pressed_button().get_index()
		if tune == 0:
			_settings(target).erase("intonation")
		else:
			_settings(target)["intonation"] = float(tune)
	if switches.has("body"):
		_person.body = BODIES[(switches["body"] as ButtonGroup).get_pressed_button().get_index()].to_lower()
	_on_changed()


# Shows every layer on every lever, switch and macro, storing nothing.
func _show_all() -> void:
	for target in 4:
		for key: String in _sliders[target]:
			for slider: HSlider in _sliders[target][key]:
				slider.set_value_no_signal(_value(target, key))
				_describe(slider, target, key)
		var switches := _switches[target]
		if switches.has("voiced"):
			(switches["voiced"] as CheckButton).set_pressed_no_signal(_value(target, "voiced") >= 0.5 if _settings(target).has("voiced") else true)
		if switches.has("intonation"):
			var tune := int(_settings(target).get("intonation", 0.0))
			_press(switches["intonation"], tune)
		if switches.has("body"):
			var body := maxi(0, BODIES.find(_person.body.capitalize()))
			_press(switches["body"], body)
	for side in 2:
		for macro: String in _macros[side]:
			(_macros[side][macro] as HSlider).set_value_no_signal(0.0)
		_refresh_macros(side)
	_timeline.queue_redraw()


# Presses one button of a group without its signals; the others let go, as a click would do.
func _press(group: ButtonGroup, index: int) -> void:
	var buttons := group.get_buttons()
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == index)


# The effect's curve shows while the effect is edited, or when the picked effect does something.
func _curve_shown() -> bool:
	return _layer == 2 or not (_effect.base.is_empty() and _effect.alternate.is_empty())


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


# --- The three layers: picking, editing and saving ---------------------------------------------

func _dir(layer: int) -> String:
	return [Voices.PERSONS_DIR, Voices.MOODS_DIR, Voices.EFFECTS_DIR][layer]


# Fills a layer's picker: "New" and the saved persons or effects, or every pose's mood.
func _fill_picker(layer: int) -> void:
	var picker := _pickers[layer]
	picker.clear()
	_picked[layer] = []
	if layer == 1:
		for pose: StringName in Person.POSES:
			var saved := ResourceLoader.exists(Voices.MOODS_DIR + String(pose) + ".tres")
			picker.add_item(String(pose).capitalize() + ("" if saved else " (neutral's)"))
			_picked[layer].append(pose)
		return
	picker.add_item("New person" if layer == 0 else "No effect")
	_picked[layer].append("")
	var dir := _dir(layer)
	for file_name in (DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()):
		if file_name.ends_with(".tres"):
			picker.add_item(file_name.get_basename().capitalize())
			_picked[layer].append(dir + file_name)


# Loads the picked item of a layer into its working copy.
func _pick(layer: int, index: int) -> void:
	index = maxi(0, index)
	_pickers[layer].select(index)
	var item: Variant = _picked[layer][index]
	if layer == 1:
		_mood = Voices.mood(item).duplicate(true)
	elif String(item).is_empty():
		if layer == 0:
			_person = VoicePerson.new()
		else:
			_effect = _new_effect()
	else:
		var loaded := load(item)
		if (layer == 0 and not loaded is VoicePerson) or (layer == 2 and not loaded is VoiceEffect):
			_status.text = "%s is not a %s." % [item, "VoicePerson" if layer == 0 else "VoiceEffect"]
			return
		if layer == 0:
			_person = loaded.duplicate(true)
		else:
			_effect = loaded.duplicate(true)
			if _effect.curve == null:
				_effect.curve = _curve_from(CURVES[5][1])
	if layer == _layer:
		_show_name()
	_show_all()
	_on_changed()


func _show_layer(layer: int) -> void:
	_layer = layer
	_press(_tabs, layer)
	for i in _cards.size():
		_cards[i].visible = i == layer
	_save.text = "Save " + LAYERS[layer].to_lower()
	_show_all()  # a lower layer may have changed what this one starts from
	_show_name()
	_timeline.queue_redraw()


func _show_name() -> void:
	var item: Variant = _picked[_layer][_pickers[_layer].selected]
	_name.editable = _layer != 1
	if _layer == 1:
		_name.text = String(item)
		_name.tooltip_text = "A mood belongs to its pose; pick another mood to save that one."
	else:
		_name.text = String(item).get_file().get_basename()
		_name.tooltip_text = ""
	_name.placeholder_text = ["Name, e.g. Old man", "", "Name, e.g. Cambion rasp"][_layer]


# Writes the layer being edited to its folder, reads it back, and picks the saved file.
func _save_layer() -> void:
	var name_text := _name.text.strip_edges().to_snake_case().validate_filename()
	if _layer == 1:
		name_text = String(_picked[1][_pickers[1].selected])  # a mood keeps its pose's name
	if name_text.is_empty():
		_status.text = "Name the %s first." % LAYERS[_layer].to_lower()
		return
	var dir := _dir(_layer)
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		_status.text = "Can't make %s: %s" % [dir, error_string(err)]
		return
	var path := dir + name_text + ".tres"
	var layer: Resource = [_person, _mood, _effect][_layer]
	err = ResourceSaver.save(layer, path)
	if err != OK:
		_status.text = "Can't save %s: %s" % [path, error_string(err)]
		return
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if back == null or back.get_script() != layer.get_script():
		_status.text = "Saved %s, but it doesn't read back as a %s." % [path, LAYERS[_layer]]
		return
	_fill_picker(_layer)
	_pick(_layer, _picked[_layer].find(StringName(name_text) if _layer == 1 else path))
	_status.text = "Saved %s.%s" % [path, " Rendered voice files change with it: run render_voices.gd." if _layer == 1 else ""]


func _find_lines() -> void:
	for path: String in _resources(CUSTOMERS):
		var resource := load(path)
		var customer := resource as Customer
		if customer != null:
			for conversation: Conversation in customer.conversations:
				if conversation != null:
					for line: DialogueLine in conversation.lines:
						_lines.append(["%s · %s" % [customer.spoken_name(), line.text.left(50)], line, customer.voice, VoiceEffect.of(line, conversation)])
		elif resource is Conversation:
			for line: DialogueLine in resource.lines:
				_lines.append(["Everyone · %s" % line.text.left(50), line, null, VoiceEffect.of(line, resource)])


func _resources(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".tres"):
			found.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_resources(dir.path_join(sub)))
	return found


# A line from the game brings its pose's mood, its customer's person and its effect along.
func _pick_line(index: int) -> void:
	if index <= 0:
		return
	var picked: Array = _lines[index - 1]
	var line: DialogueLine = picked[1]
	_text.text = line.text
	_pick(1, _picked[1].find(line.pose))
	if picked[2] != null:
		_pick(0, _picked[0].find((picked[2] as VoicePerson).resource_path))
	_pick(2, _picked[2].find((picked[3] as VoiceEffect).resource_path) if picked[3] != null else 0)
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
	_cards.append(_layer_card(PERSON, "Person", "Who speaks: the body, its build and its timbre", PERSON_KEYS, "body"))
	_cards.append(_layer_card(MOOD, "Mood", "How a line in this pose is said, over any person", MOOD_KEYS, "intonation"))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	for side in 2:
		sides.add_child(_side_card(side))
	_cards.append(sides)
	for card in _cards:
		page.add_child(card)
	_all_levers = _all_levers_panel()
	add_child(_all_levers)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_respeak = Timer.new()
	_respeak.one_shot = true
	_respeak.wait_time = 0.25
	_respeak.timeout.connect(speak)
	add_child(_respeak)
	for layer in 3:
		_fill_picker(layer)


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
	row.add_child(_label("Edit", 14, DIM))
	_tabs = ButtonGroup.new()
	var tabs := _segmented(LAYERS, _tabs)
	tabs.custom_minimum_size.x = 300
	row.add_child(tabs)
	for button in _tabs.get_buttons():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_layer(button.get_index()))
	_name = LineEdit.new()
	_name.custom_minimum_size.x = 240
	row.add_child(_name)
	_save = Button.new()
	_save.theme_type_variation = &"AccentButton"
	_save.pressed.connect(_save_layer)
	row.add_child(_save)
	var copy := Button.new()
	copy.text = "Copy"
	copy.tooltip_text = "Copy the text form of all three layers together"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Voices.layer(_person, _mood, _effect))
		_status.text = "Copied the voice's text form.")
	row.add_child(copy)
	var close := Button.new()
	close.text = "Close  Esc"
	close.pressed.connect(queue_free)
	row.add_child(close)
	return row


# The line, the three layers that say it, and the timeline: its waveform, with the effect's curve.
func _line_card() -> Control:
	var card := _card("Line", "Effect: drag the points where the alternate plays · double-click adds one · right-click removes one")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card[1].add_child(row)
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 300
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
	for layer in 3:
		row.add_child(_label(LAYERS[layer], 14, DIM))
		var layer_picker := OptionButton.new()
		layer_picker.custom_minimum_size.x = 170
		layer_picker.fit_to_longest_item = false
		layer_picker.item_selected.connect(func(index: int) -> void: _pick(layer, index))
		row.add_child(layer_picker)
		_pickers.append(layer_picker)
	_timeline = Control.new()
	_timeline.custom_minimum_size.y = 200
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
			_effect.curve = _curve_from(preset[1])
			_timeline.queue_redraw()
			_on_changed())
		bottom.add_child(button)
	return card[0]


# The levers of a person or a mood, in three columns, with its switch (the body or the tune).
func _layer_card(target: int, title: String, hint: String, keys: PackedStringArray, switch: String) -> Control:
	var card := _card(title, hint)
	var head: HBoxContainer = card[1].get_child(0)
	var group := ButtonGroup.new()
	var options := BODIES if switch == "body" else INTONATIONS
	var buttons := _segmented(options, group)
	buttons.custom_minimum_size.x = 300
	head.add_child(buttons)
	for button in group.get_buttons():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_store_switches(target))
	_switches[target] = {switch: group}
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func() -> void:
		_settings(target).clear()
		if target == MOOD:
			for key: String in MOOD_FIELDS:
				_set_lever(MOOD, key, _spec(key)[5])
		_show_all()
		_on_changed())
	head.add_child(reset)
	var levers := GridContainer.new()
	levers.columns = 3
	levers.add_theme_constant_override("h_separation", 24)
	levers.add_theme_constant_override("v_separation", 4)
	card[1].add_child(levers)
	for key in keys:
		levers.add_child(_slider_row(target, _spec(key)))
	return card[0]


# One side of the effect: its four macros and the common levers, two columns.
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
		_show_all()
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
			if group[0] == HUMAN_GROUP:
				continue
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
		var below := _below(side, key)
		var value := below
		for macro: String in MACROS:
			if MACROS[macro].has(key):
				value += (_macros[side][macro] as HSlider).value * (MACROS[macro][key] - below)
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
	var reset := _reset_button(func() -> void: _set_lever(side, spec[0], _below(side, spec[0])))
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
			_set_lever(side, spec[0], _below(side, spec[0]))
			_on_changed())
	_describe(slider, side, spec[0])
	return row


# Shows a slider's value, and marks its row when this layer changes it from what the layers below
# give; the tooltip says where that value comes from.
func _describe(slider: HSlider, target: int, key: String) -> void:
	var spec := _spec(key)
	var row := slider.get_parent()
	var below := _below(target, key)
	var changed := not is_equal_approx(slider.value, below)
	var from := _below_from(target, key)
	row.tooltip_text = "Without this layer: %s%s (%s)" % [snappedf(below, spec[4]), UNITS.get(key, ""), "from the " + from if from != "" else "Chimera's"]
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


# --- The timeline: the line's waveform, and over it the effect's curve that says where the
# alternate plays.

func _area() -> Rect2:
	return Rect2(Vector2(12, 12), _timeline.size - Vector2(24, 24))


func _to_screen(p: Vector2) -> Vector2:
	var r := _area()
	return Vector2(r.position.x + p.x * r.size.x, r.position.y + (1.0 - p.y) * r.size.y)


func _to_curve(at: Vector2) -> Vector2:
	var r := _area()
	return Vector2(clampf((at.x - r.position.x) / r.size.x, 0.0, 1.0), clampf(1.0 - (at.y - r.position.y) / r.size.y, 0.0, 1.0))


func _point_near(at: Vector2) -> int:
	for i in _effect.curve.point_count:
		if _to_screen(_effect.curve.get_point_position(i)).distance_to(at) < 12.0:
			return i
	return -1


func _on_timeline_input(event: InputEvent) -> void:
	if not _curve_shown():
		return
	var curve := _effect.curve
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
	var curve := _effect.curve if _curve_shown() else null
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

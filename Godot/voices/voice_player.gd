class_name VoicePlayer
extends AudioStreamPlayer
## Says a DialogueLine in a customer's voice, as live as the platform allows: in a browser the
## page renders it (voices/live/live_voice.js), on desktop the ChimeraVoice extension streams it
## into this player, and without either it plays the line's pre-rendered WAV.
## docs/building-and-testing.md, "Voices", says how to build it.

## The sample rate of a live line; the WAVs are imported at the same rate.
const MIX_RATE: float = 22050.0
const LIVE_DIR: String = "res://voices/live/"
## The most samples rendered in one frame: about 46 ms of audio.
const FEED_SAMPLES: int = 1024
const BODIES: Dictionary = {"male": 0, "female": 1, "child": 2}
## The audio bus that every voice plays on, so that [method level] hears the voice alone.
const BUS: StringName = &"Voice"
## The peak, in dB, at which [method level] is 0 (and below), and at which it is 1 (and above).
const QUIET_DB: float = -40.0
const LOUD_DB: float = -6.0

# One engine for every player: one line plays at a time, and the dictionary loads once.
static var _engine: Object
static var _engine_tried: bool = false
static var _owner: VoicePlayer
static var _web: JavaScriptObject
static var _web_tried: bool = false
static var _web_error: JavaScriptObject

## What every line of this player passes through last, such as the telephone on the phone: its
## base settings go over the line's own effect for the whole line (Voices.layer). Live only: a
## pre-rendered WAV plays without it. null for none.
@export var through: VoiceEffect
## Each line is said a little differently: its mood's rate, pitch and pitch swing each move by up
## to this fraction, at random, so a repeated line doesn't sound copied. 0 says it as written.
@export_range(0.0, 0.5, 0.01) var rate_jitter: float = 0.05
@export_range(0.0, 0.5, 0.01) var pitch_jitter: float = 0.04
@export_range(0.0, 1.0, 0.01) var swing_jitter: float = 0.3

var _left: int = 0
# The parts of the live line on desktop (say's dictionaries), the one that plays now, and the body.
var _live: Array[Dictionary] = []
var _live_at: int = 0
var _body: int = 0
# The rendered files still to play, each [stream, pitch_scale], when the line is not live.
var _files: Array[Array] = []
## When the last samples are pushed, in ticks (msec); the player stops once they have played.
var _drained_at: int = 0


func _ready() -> void:
	set_process(false)
	if AudioServer.get_bus_index(BUS) < 0:
		push_error("VoicePlayer: no \"%s\" bus in the bus layout (default_bus_layout.tres)" % BUS)
	bus = BUS
	finished.connect(_play_next_file)


## Starts saying [param line] as [param person], in its mood, under [param effect]
## (null for none) and [member through], and returns its length in seconds, or 0 when the length
## is not known yet (a live line in a browser). A line with parts ([method DialogueLine.parts]) says
## them one after another, each in its own mood, without a pause between them. A pre-rendered WAV
## has only the person's body and the mood's rate, pitch and swing.
func say(line: DialogueLine, person: VoicePerson, effect: VoiceEffect = null) -> float:
	hush()
	if line == null or line.text.strip_edges().is_empty():
		return 0.0
	if person == null or not BODIES.has(person.body):
		push_error("VoicePlayer: no voice person, or one with an unknown body, for \"%s\"" % line.text)
		return 0.0
	var voice := person.body
	# One jitter for the whole line, so that its parts sound like one person.
	var jitter := Vector3(1.0 + randf_range(-rate_jitter, rate_jitter), 1.0 + randf_range(-pitch_jitter, pitch_jitter), 1.0 + randf_range(-swing_jitter, swing_jitter))
	var parts: Array[Dictionary] = []
	for part: DialogueLine in line.parts():
		var mood := Voices.mood(part.voice())
		parts.append({line = part, mood = mood, rate = mood.rate * jitter.x, pitch = mood.pitch * jitter.y,
				swing = mood.swing * jitter.z, type = Voices.layer(person, mood, effect, through)})
	pitch_scale = 1.0
	var web := _web_voice()
	if web != null:
		var said: Array[Dictionary] = []
		for part: Dictionary in parts:
			said.append({text = (part.line as DialogueLine).text, speed = part.rate, pitch = part.pitch, accent = part.swing, voiceType = part.type})
		web.sayParts(JSON.stringify(said), BODIES[voice], db_to_linear(volume_db))
		_owner = self
		return 0.0
	var engine := _desktop_engine()
	if engine != null:
		_live = parts
		_body = BODIES[voice]
		# Planned last to first: each later part's length, then the first part, which plays now.
		var samples := 0
		for i: int in range(parts.size() - 1, -1, -1):
			_left = _start_part(i)
			samples += _left
		if _left > 0:
			var generator := AudioStreamGenerator.new()
			generator.mix_rate = MIX_RATE
			generator.buffer_length = 0.25
			stream = generator
			_start()
			_owner = self
			_drained_at = 0
			set_process(true)
			return samples / MIX_RATE
		_live = []
		push_error("VoicePlayer: ChimeraVoice rendered nothing for \"%s\"; playing the file" % line.text)
	var seconds := 0.0
	for part: Dictionary in parts:
		var file := Voices.stream_of(part.line, voice)
		if file == null:
			continue
		# A rendered file is fixed; playing it a touch higher or lower is the variation it can have.
		var scale: float = part.pitch / (part.mood as VoiceMood).pitch
		_files.append([file, scale])
		seconds += file.get_length() / scale
	_play_next_file()
	return seconds


## How loud the voice is right now, from 0 (silent) to 1 (loud speech). It follows the syllables,
## so it can move things in time with the voice. Any player reads the line that plays now.
func level() -> float:
	var peak: float
	if _web != null:
		peak = _web.level()
	elif OS.has_feature("web"):
		# The browser plays the WAVs outside Godot's mixer, so the bus has no level.
		peak = 1.0 if playing else 0.0
	else:
		peak = db_to_linear(AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(bus), 0))
	return clampf(inverse_lerp(QUIET_DB, LOUD_DB, linear_to_db(peak)), 0.0, 1.0)


## Whether the voice has ended and died away: nothing plays and [method level] is near silent.
func quiet() -> bool:
	return not playing and level() < 0.05


## Stops the line, live or not.
func hush() -> void:
	_files.clear()
	_live = []
	stop()
	set_process(false)
	if _owner != self:
		return
	_owner = null
	if _engine != null:
		_engine.stop()
	if _web != null:
		_web.stop()


func _process(_delta: float) -> void:
	if _owner != self:
		set_process(false)
		return
	if _drained_at > 0:
		if Time.get_ticks_msec() - _drained_at > (stream as AudioStreamGenerator).buffer_length * 1000.0:
			hush()
		return
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	# A cap keeps each frame cheap; at 60 fps a frame plays about 370 samples.
	var wanted := mini(playback.get_frames_available(), FEED_SAMPLES)
	if wanted <= 0:
		return
	var samples: PackedFloat32Array = _engine.render(wanted)
	if samples.is_empty() and _live_at + 1 < _live.size():
		_start_part(_live_at + 1)
		samples = _engine.render(wanted)
	if samples.is_empty():
		_drained_at = Time.get_ticks_msec()
		return
	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		frames[i] = Vector2(samples[i], samples[i])
	playback.push_buffer(frames)


# Plans part [param index] of the live line in the engine, which renders it next; returns its length
# in samples, 0 when it says nothing.
func _start_part(index: int) -> int:
	var part := _live[index]
	_live_at = index
	_engine.set_voice_type(part.type)
	return _engine.start((part.line as DialogueLine).text, _body, MIX_RATE, part.rate, part.pitch, part.swing)


# Plays the next rendered file of the line, if any is left.
func _play_next_file() -> void:
	if _files.is_empty():
		return
	var next: Array = _files.pop_front()
	stream = next[0]
	pitch_scale = next[1]
	_start()


# The ChimeraVoice extension with the dictionary loaded, or null without the extension.
static func _desktop_engine() -> Object:
	if _engine_tried:
		return _engine
	_engine_tried = true
	if OS.has_feature("web") or not ClassDB.class_exists(&"ChimeraVoice"):
		return null
	var dict := _dictionary()
	if dict.is_empty():
		return null
	var engine: Object = ClassDB.instantiate(&"ChimeraVoice")
	engine.load_dict(dict)
	if not engine.is_ready():
		push_error("VoicePlayer: ChimeraVoice did not take the dictionary")
		return null
	_engine = engine
	return _engine


# The page's live voice with chimera_voice.wasm loaded, or null outside a browser or without it.
static func _web_voice() -> JavaScriptObject:
	if _web_tried:
		return _web
	_web_tried = true
	if not OS.has_feature("web"):
		return null
	var wasm_path := LIVE_DIR + "chimera_voice.wasm"
	if not FileAccess.file_exists(wasm_path):
		push_warning("VoicePlayer: no %s in this build; playing the rendered files" % wasm_path)
		return null
	var glue := FileAccess.get_file_as_string(LIVE_DIR + "live_voice.js")
	if glue.is_empty():
		push_error("VoicePlayer: can't read %slive_voice.js: %s" % [LIVE_DIR, error_string(FileAccess.get_open_error())])
		return null
	var wasm := FileAccess.get_file_as_bytes(wasm_path)
	var dict := FileAccess.get_file_as_bytes(LIVE_DIR + "cmudict.txt.gz")
	if wasm.is_empty() or dict.is_empty():
		push_error("VoicePlayer: can't read %s or the dictionary: %s" % [wasm_path, error_string(FileAccess.get_open_error())])
		return null
	JavaScriptBridge.eval(glue, true)
	var web := JavaScriptBridge.get_interface("humanerrorVoice")
	if web == null:
		push_error("VoicePlayer: live_voice.js did not set window.humanerrorVoice")
		return null
	_web_error = JavaScriptBridge.create_callback(func(args: Array) -> void: push_error("VoicePlayer (browser): %s" % args[0]))
	web.onerror = _web_error
	web.init(Marshalls.raw_to_base64(wasm), Marshalls.raw_to_base64(dict))
	_web = web
	return _web


# cmudict.txt, gunzipped, or "" with the error pushed.
static func _dictionary() -> String:
	var path := LIVE_DIR + "cmudict.txt.gz"
	var gz := FileAccess.get_file_as_bytes(path)
	if gz.is_empty():
		push_error("VoicePlayer: can't read %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return ""
	var text := gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	if text.is_empty():
		push_error("VoicePlayer: %s did not unzip" % path)
	return text


# Plays the stream; started while the tree is paused, it waits for the unpause (docs/gotchas.md).
func _start() -> void:
	play()
	stream_paused = not can_process()

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

# One engine for every player: one line plays at a time, and the dictionary loads once.
static var _engine: Object
static var _engine_tried: bool = false
static var _owner: VoicePlayer
static var _web: JavaScriptObject
static var _web_tried: bool = false
static var _web_error: JavaScriptObject

var _left: int = 0
## When the last samples are pushed, in ticks (msec); the player stops once they have played.
var _drained_at: int = 0


func _ready() -> void:
	set_process(false)


## Starts saying [param line] in [param voice] (male, female or child) and returns its length
## in seconds, or 0 when the length is not known yet (a live line in a browser).
func say(line: DialogueLine, voice: String) -> float:
	hush()
	if line == null or line.text.strip_edges().is_empty():
		return 0.0
	if not BODIES.has(voice):
		push_error("VoicePlayer: no voice \"%s\"; have %s" % [voice, ", ".join(BODIES.keys())])
		return 0.0
	var mood := Voices.mood(line.pose)
	var web := _web_voice()
	if web != null:
		web.say(line.text, BODIES[voice], mood.rate, mood.pitch, mood.swing, db_to_linear(volume_db))
		return 0.0
	var engine := _desktop_engine()
	if engine != null:
		_left = engine.start(line.text, BODIES[voice], MIX_RATE, mood.rate, mood.pitch, mood.swing)
		if _left > 0:
			var generator := AudioStreamGenerator.new()
			generator.mix_rate = MIX_RATE
			generator.buffer_length = 0.25
			stream = generator
			play()
			_owner = self
			_drained_at = 0
			set_process(true)
			return _left / MIX_RATE
		push_error("VoicePlayer: ChimeraVoice rendered nothing for \"%s\"; playing the file" % line.text)
	var file := Voices.stream_of(line, voice)
	if file == null:
		return 0.0
	stream = file
	play()
	return file.get_length()


## Stops the line, live or not.
func hush() -> void:
	stop()
	set_process(false)
	if _owner == self and _engine != null:
		_engine.stop()
		_owner = null
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
	if samples.is_empty():
		_drained_at = Time.get_ticks_msec()
		return
	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		frames[i] = Vector2(samples[i], samples[i])
	playback.push_buffer(frames)


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

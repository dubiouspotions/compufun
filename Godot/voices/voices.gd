@tool
class_name Voices
## The voice files of the customer lines: where each one is, and how Chimera renders it.
## The steps are in docs/building-and-testing.md, "Voices".

const DIR: String = "res://voices/"
const MOODS_DIR: String = "res://voices/moods/"
const PERSONS_DIR: String = "res://voices/persons/"
const EFFECTS_DIR: String = "res://voices/effects/"
## The editor setting with the path of the chimera binary: Editor Settings > Humanerror > Voices.
const CHIMERA_SETTING: String = "humanerror/voices/chimera_path"
# The import settings of a new voice file: 22 kHz and QOA keep the web download small.
const IMPORT: String = """[remap]

importer="wav"
type="AudioStreamWAV"

[params]

force/8_bit=false
force/mono=true
force/max_rate=true
force/max_rate_hz=22050
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
"""


## How a line in [param of] sounds: voices/moods/<mood>.tres, or neutral.tres for a mood
## without a mood file.
static func mood(of: StringName) -> VoiceMood:
	for name: StringName in [of, &"neutral"]:
		var path := _mood_path(name)
		if ResourceLoader.exists(path):
			var found := load(path) as VoiceMood
			if found != null:
				return found
			push_error("Voices: %s is not a VoiceMood" % path)
	push_error("Voices: no %sneutral.tres; the line is said with Chimera's defaults" % MOODS_DIR)
	return VoiceMood.new()


## True when [param of] has its own voice, voices/moods/<mood>.tres; false when it speaks as neutral.
static func has_mood(of: StringName) -> bool:
	return ResourceLoader.exists(_mood_path(of))


static func _mood_path(of: StringName) -> String:
	return MOODS_DIR + String(of) + ".tres"


## The text form of a voice for ChimeraVoice and the web voice: [param person] at the bottom,
## [param mood] over it, [param effect] over that and [param through] on top, each layer's settings
## over the ones below. [param through] is what the voice passes through last, such as the
## telephone (voices/effects/telephone.tres): only its base settings count, and they hold for the
## whole line on both sides of [param effect]. Any layer may be null.
static func layer(person: VoicePerson, mood: VoiceMood, effect: VoiceEffect, through: VoiceEffect = null) -> String:
	var below: Dictionary = {}
	if person != null:
		below.merge(person.settings, true)
	if mood != null:
		below.merge(mood.settings, true)
	var top: Dictionary = through.base if through != null else {}
	if effect == null:
		below.merge(top, true)
		return VoiceEffect.encode(below, {}, null)
	var base := below.duplicate()
	base.merge(effect.base, true)
	base.merge(top, true)
	var alternate := below.duplicate()
	alternate.merge(effect.alternate, true)
	alternate.merge(top, true)
	return VoiceEffect.encode(base, alternate, effect.curve)


## The voice file of [param line] in [param voice]. Its name is a hash of all that shapes the
## sound (the voice, the line's voice mood and the text), so an edited line never finds
## old audio.
static func path_of(line: DialogueLine, voice: String) -> String:
	var shape := mood(line.voice())
	var key := "%s|%.3f|%.3f|%.3f|%s" % [voice, shape.rate, shape.pitch, shape.swing, line.text]
	return DIR + key.md5_text() + ".wav"


## The voice of [param line] in [param voice], or null: with a warning when it is not rendered
## yet (docs/building-and-testing.md, Voices), with an error when the file will not load.
static func stream_of(line: DialogueLine, voice: String) -> AudioStream:
	if line == null or line.text.strip_edges().is_empty():
		return null
	var path := path_of(line, voice)
	if not ResourceLoader.exists(path):
		push_warning("Voices: no voice for \"%s\" (%s). Render it: see docs/building-and-testing.md" % [line.text, path])
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Voices: can't load the voice %s" % path)
	return stream


## Says [param line] as [param person] in its voice mood, under [param effect], through the
## ChimeraVoice extension, and returns the whole line as a WAV; null with the error pushed when the
## extension is missing. For the editor: the game streams lines with VoicePlayer instead.
static func say_live(line: DialogueLine, person: VoicePerson, effect: VoiceEffect) -> AudioStreamWAV:
	if not ClassDB.class_exists(&"ChimeraVoice"):
		push_error("Voices: no ChimeraVoice extension; build it with tools/build-voice.sh")
		return null
	var engine: Object = ClassDB.instantiate(&"ChimeraVoice")
	if not engine.has_method(&"set_voice_type"):
		push_error("Voices: this ChimeraVoice has no voice types; rebuild it with tools/build-voice.sh")
		return null
	var gz := FileAccess.get_file_as_bytes("res://voices/live/cmudict.txt.gz")
	if gz.is_empty():
		push_error("Voices: can't read res://voices/live/cmudict.txt.gz: %s" % error_string(FileAccess.get_open_error()))
		return null
	engine.load_dict(gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	var shape := mood(line.voice())
	engine.set_voice_type(layer(person, shape, effect))
	if engine.start(line.text, VoicePlayer.BODIES.get(person.body, 0), VoicePlayer.MIX_RATE, shape.rate, shape.pitch, shape.swing) <= 0:
		push_error("Voices: ChimeraVoice said nothing for \"%s\"" % line.text)
		return null
	var samples := PackedFloat32Array()
	while true:
		var chunk: PackedFloat32Array = engine.render(4096)
		if chunk.is_empty():
			break
		samples.append_array(chunk)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(VoicePlayer.MIX_RATE)
	wav.data = data
	return wav


## Why [param chimera] can't render moods, or "" when it can: it must exist and carry
## tools/chimera-moods.patch. Without the patch, Chimera would say every mood as neutral.
static func chimera_problem(chimera: String) -> String:
	if chimera.is_empty() or not FileAccess.file_exists(chimera):
		return "Chimera is not at \"%s\". Build it and set its path: docs/building-and-testing.md, Voices" % chimera
	var output: Array = []
	OS.execute(chimera, [], output, true)
	if not "".join(output).contains("[rate] [pitch] [accent]"):
		return "%s has no mood support. Apply tools/chimera-moods.patch and build it again" % chimera
	return ""


## Renders the voice file of [param line] in [param voice] with the chimera binary at
## [param chimera], and its import settings. Returns "" when the file is there, or why not.
static func render(line: DialogueLine, voice: String, chimera: String) -> String:
	var path := path_of(line, voice)
	var shape := mood(line.voice())
	# OS.execute with output runs a shell, which splits an argument at a double quote; quotes aren't spoken.
	var arguments := ["render", "text", ProjectSettings.globalize_path(path).trim_suffix(".wav"),
		line.text.replace("\n", " ").replace("\"", ""), voice, "%.3f" % shape.rate, "%.3f" % shape.pitch, "%.3f" % shape.swing]
	var output: Array = []
	var code := OS.execute(chimera, arguments, output, true)
	if code != 0 or not FileAccess.file_exists(path):
		return "Chimera failed (%d) on \"%s\": %s" % [code, line.text, "".join(output).strip_edges()]
	var file := FileAccess.open(path + ".import", FileAccess.WRITE)
	if file == null:
		return "Couldn't write %s.import: %s" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(IMPORT)
	file.close()
	return ""

@tool
class_name Voices
## The voice files of the customer lines: where each one is, and how Chimera renders it.
## The steps are in docs/building-and-testing.md, "Voices".

const DIR: String = "res://voices/"
const MOODS_DIR: String = "res://voices/moods/"
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


## How a line in [param pose] sounds: voices/moods/<pose>.tres, or neutral.tres for a pose
## without a mood file.
static func mood(pose: StringName) -> VoiceMood:
	for name: StringName in [pose, &"neutral"]:
		var path := MOODS_DIR + String(name) + ".tres"
		if ResourceLoader.exists(path):
			var found := load(path) as VoiceMood
			if found != null:
				return found
			push_error("Voices: %s is not a VoiceMood" % path)
	push_error("Voices: no %sneutral.tres; the line is said with Chimera's defaults" % MOODS_DIR)
	return VoiceMood.new()


## The voice file of [param line] in [param voice]. Its name is a hash of all that shapes the
## sound (the voice, the mood of the line's pose and the text), so an edited line never finds
## old audio.
static func path_of(line: DialogueLine, voice: String) -> String:
	var shape := mood(line.pose)
	var key := "%s|%.3f|%.3f|%.3f|%s" % [voice, shape.rate, shape.pitch, shape.swing, line.text]
	return DIR + key.md5_text() + ".wav"


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
	var shape := mood(line.pose)
	var arguments := ["render", "text", ProjectSettings.globalize_path(path).trim_suffix(".wav"),
		line.text.replace("\n", " "), voice, "%.3f" % shape.rate, "%.3f" % shape.pitch, "%.3f" % shape.swing]
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

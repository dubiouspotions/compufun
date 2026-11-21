extends SceneTree
## Renders the voice file of every customer line that has none, with Chimera's command-line tool,
## and lists the voice files that no line uses any more. See docs/building-and-testing.md.
## From Godot/: CHIMERA=/path/to/chimera godot --headless --script res://voices/render_voices.gd

const CUSTOMERS: String = "res://customers"
const VOICES: String = "res://voices"
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


func _initialize() -> void:
	var chimera := OS.get_environment("CHIMERA")
	if chimera.is_empty() or not FileAccess.file_exists(chimera):
		_fail("set CHIMERA to the built chimera binary (now \"%s\")" % chimera)
		return
	var wanted := {}
	var errors := 0
	for path: String in _resources(CUSTOMERS):
		var resource := load(path)
		if resource == null:
			push_error("render_voices: can't load %s" % path)
			errors += 1
			continue
		var customer := resource as Customer
		if customer == null:
			continue
		for conversation: Conversation in customer.conversations:
			if conversation == null:
				continue
			for line: DialogueLine in conversation.lines:
				if line != null and not line.text.strip_edges().is_empty():
					wanted[line.voice_path(customer.voice)] = [line.text, customer.voice, path]
	var rendered := 0
	for voice_path: String in wanted:
		if FileAccess.file_exists(voice_path):
			continue
		var text: String = wanted[voice_path][0]
		var stem := ProjectSettings.globalize_path(voice_path).trim_suffix(".wav")
		var output: Array = []
		var code := OS.execute(chimera, ["render", "text", stem, text.replace("\n", " "), wanted[voice_path][1]], output, true)
		if code != 0 or not FileAccess.file_exists(voice_path):
			push_error("render_voices: chimera failed (%d) on \"%s\" from %s: %s" % [code, text, wanted[voice_path][2], "".join(output).strip_edges()])
			errors += 1
			continue
		var file := FileAccess.open(voice_path + ".import", FileAccess.WRITE)
		if file == null:
			push_error("render_voices: can't write %s.import: %s" % [voice_path, error_string(FileAccess.get_open_error())])
			errors += 1
			continue
		file.store_string(IMPORT)
		file.close()
		rendered += 1
		print("rendered %s  \"%s\"" % [voice_path.get_file(), text])
	var unused := 0
	for file_name: String in DirAccess.get_files_at(VOICES):
		if file_name.ends_with(".wav") and not wanted.has(VOICES.path_join(file_name)):
			print("unused (git rm it): %s" % VOICES.path_join(file_name))
			unused += 1
	print("render_voices: %d lines, %d rendered now, %d unused files, %d errors. Run --import next." % [wanted.size(), rendered, unused, errors])
	quit(1 if errors > 0 else 0)


func _resources(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".tres"):
			found.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_resources(dir.path_join(sub)))
	return found


func _fail(message: String) -> void:
	push_error("render_voices: " + message)
	quit(1)

extends SceneTree
## Renders the voice file of every customer line in the story files and the shared conversations
## that has none, with Chimera's command-line tool, and lists the voice files that no line uses any
## more. See docs/building-and-testing.md.
## From Godot/: CHIMERA=/path/to/chimera godot --headless --script res://voices/render_voices.gd

const CUSTOMERS: String = "res://customers"


func _initialize() -> void:
	var chimera := OS.get_environment("CHIMERA")
	var problem := Voices.chimera_problem(chimera)
	if problem != "":
		_fail(problem)
		return
	var wanted := {}
	var errors := 0
	# Conversations in their own file are shared, for example what every customer says while
	# waiting: render them in each voice that a customer has.
	var shared: Array[Conversation] = []
	var voices := {}
	for path: String in _resources(CUSTOMERS):
		var resource := load(path)
		if resource == null:
			push_error("render_voices: can't load %s" % path)
			errors += 1
			continue
		if resource is Conversation:
			shared.append(resource)
			continue
		var customer := resource as Customer
		if customer == null:
			continue
		if customer.voice == null:
			push_error("render_voices: %s has no voice person" % path)
			errors += 1
			continue
		voices[customer.voice.body] = true
	var week := StoryFiles.load_week()
	for error: String in week.errors:
		push_error("render_voices: " + error)
		errors += 1
	for d: Day in week.days:
		for errand: Errand in d.errands:
			var voice := errand.customer.voice if errand.customer != null else null
			if voice == null:
				continue  # the customer loop above or the parse reported it
			for conversation: Conversation in errand.conversations:
				for line: DialogueLine in conversation.all_lines():
					if not line.text.strip_edges().is_empty():
						wanted[Voices.path_of(line, voice.body)] = [line, voice.body, errand.file]
	for conversation in shared:
		for voice: String in voices:
			for line: DialogueLine in conversation.all_lines():
				if line != null and not line.text.strip_edges().is_empty():
					wanted[Voices.path_of(line, voice)] = [line, voice, conversation.resource_path]
	var rendered := 0
	for voice_path: String in wanted:
		if FileAccess.file_exists(voice_path):
			continue
		var line: DialogueLine = wanted[voice_path][0]
		var failure := Voices.render(line, wanted[voice_path][1], chimera)
		if failure != "":
			push_error("render_voices: %s (in %s)" % [failure, wanted[voice_path][2]])
			errors += 1
			continue
		rendered += 1
		print("rendered %s  %s \"%s\"" % [voice_path.get_file(), line.mood, line.text])
	var unused := 0
	for file_name: String in DirAccess.get_files_at(Voices.DIR):
		if file_name.ends_with(".wav") and not wanted.has(Voices.DIR + file_name):
			print("unused (git rm it): %s" % (Voices.DIR + file_name))
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

extends "res://tests/test.gd"
## A customer line whose mood changes partway ("(mood)" inside it, a mood of Person.MOODS): it
## parses into line parts and writes back exactly, every committed story file loads as before, the
## dialogue box shows each part's face as the typing reaches it, the voice says the parts in order
## from one file each, the story check and the Week page read it, and the graph edits its parts.

const PATH := "res://story/errands/0603_activist_guy.errand"
const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
const ConversationGraph := preload("res://dev/story_lab/conversation_graph.gd")
const ERRAND := """customer: activist_guy

== drop-off
(neutral) I always help when I can. About the computer... (angry) You can keep it - I'm (sighs) done. [voice thinking] [effect cambion_glitch]
(happy) Hi(angry) there.
(neutral) One mood (only), as ever.
"""
## Two committed lines of the activist, as one line: each part has its rendered voice file.
const SAID := "(neutral) No worries, dude. (angry) You can keep it - I'm planning on staying away from any tech for the foreseeable future."


func run() -> void:
	_parse_and_write_back()
	_parse_errors()
	_committed_files_load_unchanged()
	_voice_files_per_part()
	await _voice_says_the_parts_in_order()
	await _dialogue_box_faces()
	_story_check_and_week_page()
	await _graph_edits_parts()


func _line(said: String) -> DialogueLine:
	var parsed := StoryFormat.parse_line(said, PATH)
	check("\"%s\" parses" % said, parsed.errors, PackedStringArray())
	return parsed.value as DialogueLine


func _parse_and_write_back() -> void:
	var parsed := StoryFormat.parse_errand(ERRAND, PATH)
	check("the errand parses", parsed.errors, PackedStringArray())
	var lines := (parsed.value as Errand).conversations[0].lines
	var mixed := lines[0]
	check("the text holds the words without the (mood)", mixed.text, "I always help when I can. About the computer... You can keep it - I'm (sighs) done.")
	check("the mood changes where the angry part starts", mixed.mood_changes, {mixed.text.find("You"): &"angry"})
	check("its parts: words and moods; (sighs) is no mood, so it stays text", mixed.parts().map(func(p: DialogueLine) -> Array: return [p.text, p.mood]),
		[["I always help when I can. About the computer...", &"neutral"], ["You can keep it - I'm (sighs) done.", &"angry"]])
	check("[voice] and [effect] hold for every part", mixed.parts().map(func(p: DialogueLine) -> Array: return [p.voice(), p.effect == mixed.effect]), [[&"thinking", true], [&"thinking", true]])
	check("mood_at follows the parts", [mixed.mood_at(0), mixed.mood_at(mixed.text.find("You") - 1), mixed.mood_at(mixed.text.find("You"))], [&"neutral", &"neutral", &"angry"])
	check("a (mood) without a space before it", [lines[1].text, lines[1].parts().map(func(p: DialogueLine) -> String: return p.text)], ["Hithere.", ["Hi", "there."]])
	check("a line in one mood is its own only part", [lines[2].mood_changes, lines[2].parts() == [lines[2]], lines[2].text], [{}, true, "One mood (only), as ever."])
	check("written back exactly", StoryFormat.write_errand(parsed.value as Errand), ERRAND)
	check("said_text puts the (mood)s back", StoryFormat.said_text(mixed), "I always help when I can. About the computer... (angry) You can keep it - I'm (sighs) done.")
	var same_voice := StoryFormat.parse_errand("customer: activist_guy\n\n== drop-off\n(happy) Hi. (angry) Grr. [voice happy]\n", PATH)
	check("[voice] in the first part's mood holds for the whole line, and writes back", [(same_voice.value as Errand).conversations[0].lines[0].parts()[1].voice(), StoryFormat.write_errand(same_voice.value as Errand)],
		[&"happy", "customer: activist_guy\n\n== drop-off\n(happy) Hi. (angry) Grr. [voice happy]\n"])
	var event := "customer: skater_bro\n\n== event [pop-up (happy) Hey! (angry) Over here!]\n(neutral) Yo.\n"
	var popped := StoryFormat.parse_errand(event, "res://story/errands/0403_skater_bro.errand")
	check("a pop-up line has parts too, and writes back", [popped.errors, (popped.value as Errand).conversations[0].pop_up.parts().size(), StoryFormat.write_errand(popped.value as Errand)], [PackedStringArray(), 2, event])
	var outs := StoryFormat.parse_call_outs("== waiting\n(neutral) Yo? (angry) HELLO?\n", "res://story/callouts/skater_bro.callouts")
	check("a call-out has parts", [outs.errors, (outs.value as CallOuts).sets[0].lines[0].parts().map(func(p: DialogueLine) -> StringName: return p.mood)], [PackedStringArray(), [&"neutral", &"angry"]])


func _parse_errors() -> void:
	for case: Array in [
		["(neutral) Hi (angry)", "no words after (angry)"],
		["(neutral) (angry) Hi", "no words before (angry)"],
		["(neutral) Hi (happy) (angry) there", "no words after (happy)"],
	]:
		var errors := StoryFormat.parse_line(case[0], PATH).errors
		check("\"%s\" is refused: %s" % [case[0], errors], [errors.size(), errors[0].contains(case[1]) if not errors.is_empty() else false], [1, true])


# Every committed errand and call-out reads as before: no line has parts, and each errand writes
# back the same, but for spaces at the end of a line.
func _committed_files_load_unchanged() -> void:
	var with_parts := PackedStringArray()
	var rewritten := PackedStringArray()
	for path: String in StoryFiles.files(StoryFiles.ERRANDS_DIR, ".errand"):
		var text := FileAccess.get_file_as_string(path)
		var parsed := StoryFormat.parse_errand(text, path)
		check("%s parses" % path, parsed.errors, PackedStringArray())
		if _rstripped(StoryFormat.write_errand(parsed.value as Errand)) != _rstripped(text):
			rewritten.append(path)
		for c: Conversation in (parsed.value as Errand).conversations:
			for line: DialogueLine in c.all_lines():
				if not line.mood_changes.is_empty():
					with_parts.append("%s: %s" % [path, line.text])
	for path: String in StoryFiles.files(StoryFiles.CALL_OUTS_DIR, ".callouts"):
		var outs := StoryFormat.parse_call_outs(FileAccess.get_file_as_string(path), path)
		for each: CallOuts.Set in (outs.value as CallOuts).sets:
			for line: DialogueLine in each.lines:
				if not line.mood_changes.is_empty():
					with_parts.append("%s: %s" % [path, line.text])
	check("no committed line has parts", with_parts, PackedStringArray())
	check("every committed errand writes back the same", rewritten, PackedStringArray())


static func _rstripped(text: String) -> String:
	return "\n".join(Array(text.split("\n")).map(func(l: String) -> String: return l.rstrip(" \t")))


func _voice_files_per_part() -> void:
	var line := _line(SAID)
	var parts := line.parts()
	var each := parts.map(func(p: DialogueLine) -> String: return Voices.path_of(p, "male"))
	check("each part has the file that a line of its words and mood has", each, [Voices.path_of(_line("(neutral) No worries, dude."), "male"), Voices.path_of(_line("(angry) You can keep it - I'm planning on staying away from any tech for the foreseeable future."), "male")])
	var edited := _line("(neutral) No worries, dude. (angry) Keep it.")
	check("an edit of the second part leaves the first part's file", [Voices.path_of(edited.parts()[0], "male") == each[0], Voices.path_of(edited.parts()[1], "male") == each[1]], [true, false])


func _voice_says_the_parts_in_order() -> void:
	var activist := load("res://customers/activist_guy.tres") as Customer
	var line := _line(SAID)
	var files: Array = line.parts().map(func(p: DialogueLine) -> AudioStream: return Voices.stream_of(p, activist.voice.body))
	check("both parts are rendered", files.has(null), false)
	var player := VoicePlayer.new()
	player.pitch_jitter = 0.0
	root.add_child(player)
	await process_frame
	var seconds := player.say(line, activist.voice)
	check("it says the first part's file first, and its length is both parts'", [player.stream, snappedf(seconds, 0.001)], [files[0], snappedf(files[0].get_length() + files[1].get_length(), 0.001)])
	player.finished.emit()
	check("then the second part's, at once", [player.stream, player.playing], [files[1], true])
	player.hush()
	player.finished.emit()
	check("hushed, it says no more", player.stream, files[1])
	player.queue_free()
	await process_frame


func _dialogue_box_faces() -> void:
	var activist := load("res://customers/activist_guy.tres") as Customer
	var talk := (StoryFormat.parse_errand("customer: activist_guy\n\n== drop-off\n%s\n(happy) Bye.\n" % SAID, PATH).value as Errand).conversations[0]
	var box: Control = (load("res://ui/dialogue_overlay.tscn") as PackedScene).instantiate()
	root.add_child(box)
	await process_frame
	var label := box.get_node("%LineLabel") as TypedLabel
	var portrait := box.get_node("%PortraitTexture") as TextureRect
	box.call(&"start", activist, talk)
	var turn := talk.lines[0].text.find("You")
	label.call(&"_process", (turn - 2) / label.chars_per_second)
	box.call(&"_process", 0.0)
	check("typing the first part shows its face", [label.visible_characters < turn, box.call(&"face"), portrait.texture], [true, &"neutral", activist.person.portraits[&"neutral"]])
	label.call(&"_process", 3.0 / label.chars_per_second)
	box.call(&"_process", 0.0)
	check("once the typing reaches the second part, its face", [label.visible_characters > turn, box.call(&"face"), portrait.texture], [true, &"angry", activist.person.portraits[&"angry"]])
	box.call(&"start", activist, talk)
	check("a new start shows the first face", box.call(&"face"), &"neutral")
	box.call(&"click")
	check("a click that shows the rest of the line shows the last part's face", [label.is_typing(), box.call(&"face")], [false, &"angry"])
	box.call(&"click")
	check("the next line has its own face", box.call(&"face"), &"happy")
	box.queue_free()
	await process_frame


func _story_check_and_week_page() -> void:
	var text := "customer: activist_guy\n\n== drop-off\n(neutral) Hi. (despair) Oh no.\n"
	var errand := StoryFormat.parse_errand(text, PATH).value as Errand
	errand.file = "0603_activist_guy.errand"
	var found := PackedStringArray()
	StoryCheck._check_errand(errand, found)
	check("a mood inside a line without a portrait is a missing link", Array(found).filter(func(l: String) -> bool: return l.contains("\"Oh no.\" is in the mood despair, which res://people/activist_guy/person.tres has no portrait for")).size(), 1)
	var page := PackedStringArray()
	StoryWeekPage._errand(page, errand, PackedStringArray())
	check("the Week page writes the line as the file does", "\n".join(page).contains("(neutral) Hi. (despair) Oh no."), true)


func _graph_edits_parts() -> void:
	var errand := StoryFormat.parse_errand(ERRAND, PATH).value as Errand
	var talk := errand.conversations[0]
	var graph: ConversationGraph = (load(GRAPH) as PackedScene).instantiate()
	graph.set_anchors_preset(Control.PRESET_TOP_LEFT)
	graph.size = Vector2(1400, 800)
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	root.add_child(graph)
	graph.show_conversation(talk, errand.customer)
	await process_frame
	var mixed := talk.lines[0]
	check("the box shows a face per part", _faces(graph, talk), [&"neutral", &"angry", &"happy", &"angry", &"neutral"])
	graph.set_line_part_mood(mixed, 1, &"irritated02")
	check("a part's own mood", mixed.parts().map(func(p: DialogueLine) -> StringName: return p.mood), [&"neutral", &"irritated02"])
	check("which the file writes", StoryFormat.write_errand(errand).contains("About the computer... (irritated02) You can keep it"), true)
	check("a part's words, the spaces around them kept", [graph.edit_line_part(mixed, 0, " I help. "), mixed.text], ["", "I help. You can keep it - I'm (sighs) done."])
	check("an empty part is refused", graph.edit_line_part(mixed, 1, "  ") != "", true)
	check("a split at the cursor: a new part in the same mood", [graph.split_line_part(mixed, 1, "You can keep it - ".length()), mixed.parts().map(func(p: DialogueLine) -> Array: return [p.text, p.mood])],
		["", [["I help.", &"neutral"], ["You can keep it -", &"irritated02"], ["I'm (sighs) done.", &"irritated02"]]])
	check("a split with no words before the cursor is refused", graph.split_line_part(mixed, 0, 0) != "", true)
	check("a split with no words after it is refused", graph.split_line_part(mixed, 2, "I'm (sighs) done.".length()) != "", true)
	graph.merge_line_part(mixed, 1)
	check("a merge: the part's words join the part before, in its mood", mixed.parts().map(func(p: DialogueLine) -> Array: return [p.text, p.mood]),
		[["I help. You can keep it -", &"neutral"], ["I'm (sighs) done.", &"irritated02"]])
	check("typing a (mood) in a line's words starts a part", [graph.edit_text(talk.lines[2], "Fine. (angry) Not fine."), talk.lines[2].parts().size()], ["", 2])
	check("a (mood) without words after it is refused", [graph.edit_text(talk.lines[2], "Fine. (angry)").contains("no words after (angry)"), talk.lines[2].text], [true, "Fine. Not fine."])
	var written := StoryFormat.write_errand(errand)
	check("after the edits the file reads back the same", StoryFormat.write_errand(StoryFormat.parse_errand(written, PATH).value as Errand), written)
	await process_frame
	check("the box follows", _faces(graph, talk), [&"neutral", &"irritated02", &"happy", &"angry", &"neutral", &"angry"])
	graph.queue_free()
	await process_frame


# The moods of the faces in [param talk]'s box, top to bottom.
func _faces(graph: ConversationGraph, talk: Conversation) -> Array:
	var faces: Array = []
	for node: Node in graph.box_of(talk).find_children("*", "Button", true, false):
		var face := node as Button
		if face.custom_minimum_size == graph.thumb_size:
			faces.append(StringName(face.tooltip_text.get_slice("\n", 0)))
	return faces

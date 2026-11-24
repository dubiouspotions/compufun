extends "res://tests/test.gd"
## A customer line types in time with its voice when the voice knows its timing: each part's
## characters over that part's audio, and the face of a part from the moment its audio starts, in
## the dialogue box, the call-out box and on the phone. A click shows the whole line, and the face
## still follows the audio. A hushed line holds its typing, and follows the voice again when it is
## said again. VoicePlayer tells the timing of its rendered files.

const FakeVoice := preload("res://tests/fake_voice.gd")
const PATH := "res://story/errands/0603_activist_guy.errand"
## A line in two parts, for the tests with a fake voice.
const SAID := "(neutral) No worries, dude. (angry) You can keep it - I'm staying away from tech."
## The parts' audio in the tests with a fake voice: 2 s, then 4 s.
var times := PackedVector2Array([Vector2(0.0, 2.0), Vector2(2.0, 4.0)])

var _activist: Customer = load("res://customers/activist_guy.tres")


func run() -> void:
	await _voice_player_timing()
	await _dialogue_box_follows_the_voice()
	await _call_out_box_follows_the_voice()
	await _phone_follows_the_voice()


func _conversation(lines: String) -> Conversation:
	var parsed := StoryFormat.parse_errand("customer: activist_guy\n\n== drop-off\n%s\n(happy) Bye.\n" % lines, PATH)
	check("the errand parses", parsed.errors, PackedStringArray())
	return (parsed.value as Errand).conversations[0]


func _voice_player_timing() -> void:
	var found := _rendered_two_part_line()
	check("the week has a line in two parts with their voices rendered", found.is_empty(), false)
	if found.is_empty():
		return
	var line: DialogueLine = found["line"]
	var voice: VoicePerson = found["voice"]
	var player := VoicePlayer.new()
	player.rate_jitter = 0.0
	player.pitch_jitter = 0.0
	root.add_child(player)
	await process_frame
	check("before a line, the timing is unknown", [player.said(), player.part_times(), player.played(), player.playing_part()], [null, PackedVector2Array(), -1.0, -1])
	var seconds := player.say(line, voice)
	var times := player.part_times()
	check("each part starts as the one before ends, and they last as long as the line", [player.said() == line, times.size(), times[0].x, times[1].x, snappedf(times[1].x + times[1].y, 0.001)], [true, 2, 0.0, times[0].y, snappedf(seconds, 0.001)])
	check("the line plays its first part", player.playing_part(), 0)
	if not ClassDB.class_exists(&"ChimeraVoice"):
		var files: Array = line.parts().map(func(p: DialogueLine) -> AudioStream: return Voices.stream_of(p, voice.body))
		check("each part lasts as long as its file", [snappedf(times[0].y, 0.001), snappedf(times[1].y, 0.001)], [snappedf(files[0].get_length(), 0.001), snappedf(files[1].get_length(), 0.001)])
		player.finished.emit()
		check("the second file plays the second part", [player.playing_part(), player.played() >= times[1].x], [1, true])
		player.finished.emit()
		check("once the voice has ended, it has played the whole line", [snappedf(player.played(), 0.001), player.playing_part()], [snappedf(seconds, 0.001), 1])
		var unrendered: DialogueLine = _conversation("(neutral) Nobody rendered this line, ever.").lines[0]
		player.say(unrendered, _activist.voice)
		check("a line without its file has no known timing", [player.said() == unrendered, player.part_times(), player.played()], [true, PackedVector2Array(), -1.0])
	player.hush()
	check("hushed, it forgets the line and its timing", [player.said(), player.part_times(), player.played()], [null, PackedVector2Array(), -1.0])
	player.queue_free()
	await process_frame


func _dialogue_box_follows_the_voice() -> void:
	var talk := _conversation(SAID)
	var line: DialogueLine = talk.lines[0]
	var turn := line.part_starts()[1]
	var length := line.text.length()
	var box: Control = (load("res://ui/dialogue_overlay.tscn") as PackedScene).instantiate()
	var voice := box.get_node("Voice")
	voice.set_script(FakeVoice)
	voice.set(&"times", times)
	root.add_child(box)
	await process_frame
	var label := box.get_node("%LineLabel") as TypedLabel
	var show_at := func(seconds: float) -> Array:
		voice.set(&"at", seconds)
		label.call(&"_process", 0.0)
		box.call(&"_process", 0.0)
		return [label.visible_characters, box.call(&"face")]
	box.call(&"start", _activist, talk)
	check("the line starts with nothing typed", show_at.call(0.0), [0, &"neutral"])
	check("halfway through the first part's audio, half its characters", show_at.call(1.0), [int(turn * 0.5), &"neutral"])
	label.call(&"_process", 10.0)
	check("the typing speed doesn't move it on", label.visible_characters, int(turn * 0.5))
	check("just before the second part's audio, the first face", show_at.call(1.99)[1], &"neutral")
	check("the second part's face as its audio starts, before its first character types", show_at.call(2.0), [turn, &"angry"])
	check("halfway through the second part, half of its characters", show_at.call(4.0), [int(turn + (length - turn) * 0.5), &"angry"])
	voice.set(&"at", 6.0)
	label.call(&"_process", 0.0)
	check("all of it once the voice has ended", label.is_typing(), false)

	box.call(&"start", _activist, talk)
	show_at.call(1.0)
	box.call(&"click")
	check("a click shows the whole line, with the face of the part that plays", [label.is_typing(), box.call(&"face")], [false, &"neutral"])
	check("then the face follows the audio", show_at.call(2.5)[1], &"angry")
	check("and stays on the last part's once the voice has ended", show_at.call(6.0)[1], &"angry")

	box.call(&"start", _activist, talk)
	show_at.call(3.0)
	var typed := label.visible_characters
	box.call(&"hush")
	label.call(&"_process", 1.0)
	check("a hushed line holds its typing", [label.visible_characters, label.is_typing()], [typed, true])
	box.call(&"replay")
	check("said again, it types in time with the voice from its start", show_at.call(0.5), [int(turn * 0.25), &"neutral"])

	voice.set(&"times", PackedVector2Array())
	box.call(&"start", _activist, talk)
	label.call(&"_process", 10.5 / label.chars_per_second)
	check("without known timing, it types at its own speed", label.visible_characters, 10)
	box.queue_free()
	await process_frame


func _call_out_box_follows_the_voice() -> void:
	var line: DialogueLine = _conversation("(neutral) Hello? Anybody here?").lines[0]
	var calling: Node = load("res://ui/customer_calling.tscn").instantiate()
	var voice := calling.get_node("Voice")
	voice.set_script(FakeVoice)
	voice.set(&"times", PackedVector2Array([Vector2(0.0, 2.0)]))
	root.add_child(calling)
	await process_frame
	var label := calling.get_node("%Line") as TypedLabel
	calling.call(&"say", _activist, line, null)
	check("the call-out box starts the line with nothing typed", [label.text, label.visible_characters], [line.text, 0])
	voice.set(&"at", 1.0)
	label.call(&"_process", 0.0)
	check("and types it in time with the voice", label.visible_characters, int(line.text.length() * 0.5))
	voice.set(&"times", PackedVector2Array())
	calling.call(&"stop")
	calling.call(&"say", _activist, line, null)
	check("without known timing, it shows the line at once, as ever", [label.is_typing(), label.visible_characters], [false, -1])
	calling.queue_free()
	await process_frame


func _phone_follows_the_voice() -> void:
	var errand: Errand = StoryFormat.parse_errand("customer: activist_guy\nproblem: dust_overheat\n\n== drop-off\n(neutral) Here.\n\n== phone\n(neutral) Oh, it's ready? Great.\n", PATH).value
	var phone: Node = load("res://ui/phone_call.tscn").instantiate()
	var voice := phone.get_node("Voice")
	voice.set_script(FakeVoice)
	voice.set(&"times", PackedVector2Array([Vector2(0.0, 2.0)]))
	root.add_child(phone)
	await process_frame
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(make_day(1, [[errand.customer, errand.problem, errand.conversations]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	job.hardware_fixed = true
	game.set_tested(job)
	game.call_customer(job)
	phone.call(&"_process", phone.get(&"ring_seconds"))
	var label := phone.get_node("%Line") as TypedLabel
	var text: String = errand.conversations[1].lines[0].text
	check("the customer answers, nothing typed yet", [label.text, label.visible_characters], [text, 0])
	voice.set(&"at", 1.0)
	label.call(&"_process", 0.0)
	check("the phone types the line in time with the voice", label.visible_characters, int(text.length() * 0.5))
	game.hang_up()
	phone.queue_free()
	await process_frame


# A committed customer line in two or more parts whose parts all have their rendered voice files,
# with its customer's voice: {"line", "voice"}, or {} when the week has none. Found, not named, so
# that the writers' edits don't break the test.
func _rendered_two_part_line() -> Dictionary:
	var week := StoryFiles.load_week()
	for day: Day in week.days:
		for errand: Errand in day.errands:
			if errand.customer == null or errand.customer.person == null or errand.customer.person.voice == null:
				continue
			var voice := errand.customer.person.voice
			for conversation: Conversation in errand.conversations:
				for line: DialogueLine in _lines_of(conversation):
					if line.parts().size() >= 2 and line.parts().all(func(p: DialogueLine) -> bool: return Voices.stream_of(p, voice.body) != null):
						return {"line": line, "voice": voice}
	return {}


func _lines_of(reply: Reply) -> Array[DialogueLine]:
	var found: Array[DialogueLine] = []
	if reply == null:
		return found
	found.append_array(reply.lines)
	for choice: Choice in reply.choices:
		for answer: Reply in choice.replies:
			found.append_array(_lines_of(answer))
	found.append_array(_lines_of(reply.then))
	return found

extends "res://tests/test.gd"
## A customer line that starts while the game is paused (the Story Lab restores the paused game on
## every saved edit) stays silent until the game goes on.


func run() -> void:
	var errand: Errand = StoryFormat.parse_errand(FileAccess.get_file_as_string("res://story/errands/0102_skater_bro.errand"), "res://story/errands/0102_skater_bro.errand").value
	var line: DialogueLine = errand.conversations[0].lines[0]
	var player := VoicePlayer.new()
	root.add_child(player)
	paused = true
	await process_frame
	player.say(line, errand.customer.person.voice)
	check("a line started while paused is held, not playing", [player.stream_paused, player.playing], [true, false])
	paused = false
	await process_frame
	check("it plays once the game goes on", [player.stream_paused, player.playing], [false, true])
	player.stop()
	await process_frame
	player.say(line, errand.customer.person.voice)
	check("a line started while running plays at once", [player.stream_paused, player.playing], [false, true])
	player.queue_free()
	await process_frame

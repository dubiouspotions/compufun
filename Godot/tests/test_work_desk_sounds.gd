extends "res://tests/test.gd"
## CompuFunDB's keys and dial-up play in the shop, from the work keyboard and the modem, through the
## shop's sound zone; not flat from everywhere.


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var keys := get_first_node_in_group(&"work_keys_speaker") as AudioStreamPlayer3D
	var modem := get_first_node_in_group(&"modem_speaker") as AudioStreamPlayer3D
	check("a 3D speaker at the work keyboard", keys != null and keys.get_parent().name == &"WorkKeyboard", true)
	check("a 3D speaker in the work modem", modem != null and modem.get_parent().name == &"WorkModem", true)
	if keys == null or modem == null:
		main.queue_free()
		return
	for speaker: AudioStreamPlayer3D in [keys, modem]:
		check("%s hears the sound zones" % speaker.get_path(), speaker.area_mask & SoundSet.SOUND_ZONES != 0, true)

	var db: Node = main.find_child("CompuFunDBView", true, false).find_child("CompuFunDB", true, false)
	db.call("_play_key", "a")
	check("a typed key plays at the keyboard", [keys.playing, keys.stream in (db.get("keystroke") as SoundSet).sounds], [true, true])
	main.queue_free()
	await process_frame

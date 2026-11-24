extends "res://tests/test.gd"
## The trash can plays a part's trash sound as a piece lands in it: the low error chord once for the
## bootfloppy problem's floppy, nothing for other parts or the antivirus floppy, and nothing when a
## restore puts the floppy in the can.

var _can: Node3D  # not TrashCan: it names the Game autoload


func run() -> void:
	_can = load("res://props/trash_can.tscn").instantiate()
	root.add_child(_can)
	check("restore a floppy in A:", game.restore({"jobs": [
		{"customer": "res://customers/young_entrepreneur.tres", "problem": "bootfloppy", "slot": 0}],
		"focus_slot": 0, "connected_slot": -1}), "")
	await process_frame
	for part_id: StringName in [&"fan", &"antivirus_floppy"]:
		game.take_new_part(Part.named(part_id))
		game.trash_part()
		await process_frame
		check("%s thrown away plays nothing" % part_id, _played(), [])

	var chord := load("res://sounds/chord_low.tres") as SoundSet
	check("the chord is quiet and low", [chord.volume_db <= -12.0, chord.pitch_range.y < 1.0], [true, true])
	game.eject_floppy(game.jobs[0])
	check("the boot floppy is in the hand", game.hand != null and game.hand.part.id() == &"floppy", true)
	game.trash_part()
	await process_frame
	check("the boot floppy thrown away plays the low chord once", _played(), [[chord.sounds[0], chord.volume_db]])

	await _quiet()
	game.take_from_trash()
	await process_frame
	check("the boot floppy taken back out plays nothing", _played(), [])
	game.trash_part()
	await process_frame
	check("thrown away again, it plays again", _played().size(), 1)

	await _quiet()
	var trashed: Variant = game.snapshot().get("trashed")
	check("restore the floppy in the trash", game.restore({"trashed": trashed}), "")
	await process_frame
	check("a restore plays nothing", [game.trashed.size(), _played()], [3, []])
	_can.queue_free()


# The stream and volume of each player that the can has started since the last _quiet.
func _played() -> Array:
	var played := []
	for player: Node in _can.get_children():
		if player is AudioStreamPlayer3D and not player.is_queued_for_deletion():
			played.append([(player as AudioStreamPlayer3D).stream, (player as AudioStreamPlayer3D).volume_db])
	return played


func _quiet() -> void:
	for player: Node in _can.get_children():
		if player is AudioStreamPlayer3D:
			player.queue_free()
	await process_frame

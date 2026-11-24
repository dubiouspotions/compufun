extends "res://tests/test.gd"
## A click that throws a piece in the trash can plays its part's trash sound, once: the low error chord
## for the bootfloppy problem's floppy, nothing for other parts or the antivirus floppy. The throw
## stays in the view it came from. A piece that lands in the can without a click, as on a restore,
## plays nothing.

var _can: Node3D  # not TrashCan: it names the Game autoload


func run() -> void:
	_can = load("res://props/trash_can.tscn").instantiate()
	root.add_child(_can)
	check("restore a floppy in A:, in the Right view", game.restore({"jobs": [
		{"customer": "res://customers/young_entrepreneur.tres", "problem": "bootfloppy", "slot": 0}],
		"focus_slot": 0, "connected_slot": -1, "view": "Right"}), "")
	await process_frame
	for part_id: StringName in [&"fan", &"antivirus_floppy"]:
		game.take_new_part(Part.named(part_id))
		_throw()
		await process_frame
		check("%s thrown away plays nothing" % part_id, [game.hand, _played()], [null, []])

	var chord := load("res://sounds/chord_low.tres") as SoundSet
	check("the chord is quiet and low", [chord.volume_db <= -12.0, chord.pitch_range.y < 1.0], [true, true])
	game.eject_floppy(game.jobs[0])
	check("the boot floppy is in the hand", game.hand != null and game.hand.part.id() == &"floppy", true)
	_throw()
	check("the click that throws the boot floppy plays the low chord at once", _played(), [[chord.sounds[0], chord.volume_db]])
	for i in 5:
		await process_frame
	check("once, and the view stays", [_played().size(), game.view], [1, &"Right"])

	await _quiet()
	game.take_new_part(Part.named(&"fan"))
	game.trash_part()
	await process_frame
	check("thrown in without a click, it plays nothing", _played(), [])
	var trashed: Variant = game.snapshot().get("trashed")
	check("restore the floppy in the trash", game.restore({"trashed": trashed}), "")
	await process_frame
	check("a restore plays nothing", [game.trashed.size(), _played()], [4, []])
	_can.queue_free()


func _throw() -> void:
	var hotspot: Node = _can.get_node("%Hotspot")
	hotspot.emit_signal(&"clicked", hotspot)


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

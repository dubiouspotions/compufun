extends "res://tests/test.gd"
## The blood puddle's drops sound as they land in the floor puddle, on the frame that the drawn drop
## reaches it, only on the day that the blood appeared: the next day it neither drips nor sounds.

var _dripped_frames: Array[int] = []
var _frame: int = 0


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var sign: Node = shop.get_node("CorruptionSigns/BloodPuddle")
	var drop: Node3D = sign.get_node("%Drop")
	var player: AudioStreamPlayer3D = sign.get_node("%DripSound")
	sign.connect(&"dripped", func() -> void: _dripped_frames.append(_frame))

	check("restore on day 6", game.restore({"day": 6, "arrivals": game.day_of(6).codes().size()}), "")
	game.set_flag(&"sign_blood_puddle", 2)
	await process_frame
	check("set during play: fresh, the day kept", [sign.call("fresh"), game.flag(&"blood_puddle_day")], [true, 6])

	var landings := await _watch(drop, float(sign.call("settled_seconds")) - float(sign.get("floor_grow_seconds")) + 6.5)
	check("three drops land, each with its sound on the frame that the drawn drop reaches the floor", [_dripped_frames.size(), _dripped_frames], [3, landings])
	check("the sound plays", [player.stream != null, player.playing], [true, true])

	check("a restore on the same day", game.restore(game.snapshot()), "")
	await process_frame  # the jump moves the drop on to the settled time
	_dripped_frames.clear()
	landings = await _watch(drop, 3.5)
	check("still fresh: it drips and sounds", [_dripped_frames.size(), _dripped_frames], [1, landings])

	game.close_shop()
	game.start_next_day()
	await process_frame
	check("the next day: not fresh", [game.day_number, sign.call("fresh")], [7, false])
	_dripped_frames.clear()
	var drop_shown := false
	for i: int in 7 * FPS:
		drop_shown = drop_shown or drop.visible
		_frame += 1
		await process_frame
	check("the next day: no drop falls, nothing sounds", [drop_shown, _dripped_frames], [false, []])
	shop.queue_free()
	await process_frame


# Plays [param seconds]; returns the frames on which the drawn drop vanished at the floor.
func _watch(drop: Node3D, seconds: float) -> Array[int]:
	var landings: Array[int] = []
	for i: int in ceili(seconds * FPS):
		var was := drop.visible
		_frame += 1
		await process_frame
		if was and not drop.visible:
			landings.append(_frame)
	return landings

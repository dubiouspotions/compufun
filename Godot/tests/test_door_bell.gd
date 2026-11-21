extends "res://tests/test.gd"
## The door bell rings when the visitor passes under it, walking in and walking out.

const GAME := preload("res://game.gd")
const WALK_SECONDS: float = 2.0
## How far from the bell, along the floor, the visitor may be when it starts ringing.
const TOLERANCE: float = 0.5


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	shop.walk_seconds = WALK_SECONDS
	root.add_child(shop)
	await process_frame
	var bell: AudioStreamPlayer3D = shop.find_child("DoorBell", true, false)
	var follow: PathFollow3D = shop.find_child("CustomerFollow", true, false)
	var day: Day = (load("res://days/day_1.tres") as Day).duplicate()
	day.first_wait_seconds = Vector2.ZERO

	game.start_day(day)
	check("a visitor walks in", game.visitor_state, GAME.VisitorState.WALKING_IN)
	await process_frame
	check("silent while the visitor is in the alley", bell.playing, false)
	check("rings at the doorway on the way in", await _distance_at_ring(bell, follow) < TOLERANCE, true)
	bell.stop()

	await create_timer(WALK_SECONDS * 1.5).timeout
	check("the visitor reaches the counter", game.visitor_state, GAME.VisitorState.TALKING)
	game.dialogue_finished()
	check("the visitor walks out", game.visitor_state, GAME.VisitorState.WALKING_OUT)
	await process_frame
	check("silent while the visitor is at the counter", bell.playing, false)
	check("rings at the doorway on the way out", await _distance_at_ring(bell, follow) < TOLERANCE, true)


## The floor distance between the visitor and the bell on the frame that the bell starts, or INF
## if it doesn't start within the walk.
func _distance_at_ring(bell: AudioStreamPlayer3D, follow: PathFollow3D) -> float:
	var deadline := Time.get_ticks_msec() + int(WALK_SECONDS * 2000.0)
	while not bell.playing:
		if Time.get_ticks_msec() > deadline:
			printerr("the door bell didn't ring; visitor at %s" % follow.global_position)
			return INF
		await process_frame
	var offset := follow.global_position - bell.global_position
	print("door bell rang with the visitor at %s, %.2f m from the bell" % [follow.global_position, Vector2(offset.x, offset.z).length()])
	return Vector2(offset.x, offset.z).length()

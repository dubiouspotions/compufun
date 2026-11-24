extends "res://tests/test.gd"
## Customers come in from either end of the alley at random, and mostly walk out toward the end that
## they came from (Game.SAME_WAY_OUT). A snapshot keeps both ends, and the room walks the path of each.

const GAME := preload("res://game.gd")
const WALK_SECONDS: float = 2.0
const ARRIVALS: int = 400


func run() -> void:
	var day: Day = computer_day(1)
	day.first_wait_seconds = Vector2.ZERO
	seed(264)
	var from_left := 0
	var same_way := 0
	for i: int in ARRIVALS:
		game.start_day(day)
		game.open_shop()
		from_left += int(game.visitor_from == GAME.AlleyEnd.LEFT)
		same_way += int(game.visitor_to == game.visitor_from)
	print("of %d arrivals, %d came from the left and %d left the way they came" % [ARRIVALS, from_left, same_way])
	check("about half come from the left", absf(float(from_left) / ARRIVALS - 0.5) < 0.1, true)
	check("most leave the way they came", absf(float(same_way) / ARRIVALS - GAME.SAME_WAY_OUT) < 0.1, true)

	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	shop.set("walk_seconds", WALK_SECONDS)
	root.add_child(shop)
	await process_frame
	var follow: PathFollow3D = shop.find_child("CustomerFollow", true, false)
	var walking_in := {"day": 1, "arrivals": 2, "visitor": "res://customers/skater_bro.tres", "visitor_state": "WALKING_IN"}
	for end: String in ["LEFT", "RIGHT"]:
		walking_in.merge({"visitor_from": end, "visitor_to": end}, true)
		check("restore a visitor walking in from the %s" % end, game.restore(walking_in), "")
		check("the snapshot keeps the ends", [game.snapshot()["visitor_from"], game.snapshot()["visitor_to"]], [end, end])
		await process_frame
		check("they start at the %s end of the alley" % end, signf(follow.global_position.x), -1.0 if end == "LEFT" else 1.0)
		check("on asphalt", Ground.under(follow.global_position, self).steps.resource_path, "res://sounds/footsteps_asphalt.tres")
	check("an unknown end is refused", game.restore(walking_in.merged({"visitor_to": "UP"}, true)).contains("visitor_to can't be UP"), true)

	await create_timer(WALK_SECONDS * 1.5).timeout
	check("the visitor reaches the counter", game.visitor_state, GAME.VisitorState.TALKING)
	game.visitor_to = GAME.AlleyEnd.LEFT
	game.dialogue_finished()
	await process_frame
	check("walks out", game.visitor_state, GAME.VisitorState.WALKING_OUT)
	await create_timer(WALK_SECONDS * 0.6).timeout
	check("out the door toward the other end", [game.visitor_state, follow.global_position.x < 0.0], [GAME.VisitorState.OUTSIDE, true])
	var farthest := 0.0
	var deadline := now() + WALK_SECONDS * 2.0
	while game.visitor != null and now() < deadline:
		farthest = minf(farthest, follow.global_position.x)
		await process_frame
	check("gone at the left end", [game.visitor, farthest < -10.0], [null, true])

	var outside := walking_in.merged({"visitor_state": "OUTSIDE", "visitor_from": "RIGHT", "visitor_to": "LEFT"}, true)
	check("restore the visitor outside, walking to the left", game.restore(outside), "")
	await create_timer(WALK_SECONDS * 0.3).timeout
	check("walks on to the left from the door", follow.global_position.x < -1.0, true)
	shop.queue_free()
	await process_frame

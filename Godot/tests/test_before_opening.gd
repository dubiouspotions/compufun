extends "res://tests/test.gd"
## A customer whose errand comes before opening (day 1's middle manager) is at the counter and talking
## as the day starts, in the closed shop. The shop opens only once he is out the door; then the Open
## sign shakes, and the next customer comes the day's first wait after opening. Restore keeps such a
## visit and refuses one that doesn't come before opening.

const MANAGER: String = "res://customers/middle_manager.tres"


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var sign: Node3D = shop.get_node("%OpenSign")

	game.start_day(game.day_of(1))
	await process_frame
	check("day 1 starts closed with the middle manager talking at the counter",
		[game.phase, game.arrivals, game.visitor.resource_path, game.visit, game.visitor_state, game.conversation.id],
		[game.Phase.CLOSED, 1, MANAGER, game.Visit.DROP_OFF, game.VisitorState.TALKING, &"0101/drop-off/1"])
	check("he stands at the counter at once", shop.get_node("%CustomerFollow").get("progress_ratio"), 1.0)
	check("while he is in: the shop can't open, the phone can't be picked up, the sign is still", [game.can_open(), game.can_pick_up_phone(), sign.call("is_shaking")], [false, false, false])

	var talking: Dictionary = game.snapshot()
	check("a snapshot of his talk restores as it was", [game.restore(talking), game.snapshot() == talking], ["", true])
	var stranger := talking.duplicate()
	stranger.merge({"day": 2, "visitor": "res://customers/nice_lady.tres"}, true)
	check("a visitor whose errand doesn't come before opening is refused in the closed shop", game.restore(stranger) != "", true)
	check("restore talking again", game.restore(talking), "")

	game.dialogue_finished()
	check("walking out, he is still in the shop", [game.visitor_state, game.can_open()], [game.VisitorState.WALKING_OUT, false])
	var waited := 0.0
	while game.visitor_state == game.VisitorState.WALKING_OUT and waited < 10.0:
		await process_frame
		waited += 1.0 / FPS
	check("out the door, the shop can open, and the sign shakes", [game.visitor_state, game.can_open(), sign.call("is_shaking")], [game.VisitorState.OUTSIDE, true, true])

	while game.visitor != null and waited < 20.0:
		await process_frame
		waited += 1.0 / FPS
	check("he has left", [game.visitor, game.phase], [null, game.Phase.CLOSED])
	game.open_shop()
	tick(game.day.first_wait_seconds.x - 0.1)
	check("open: nobody before the day's first wait", [game.phase, game.arrivals, game.visitor], [game.Phase.OPEN, 1, null])
	tick(game.day.first_wait_seconds.y - game.day.first_wait_seconds.x + 0.2)
	check("the second errand comes after the first wait", [game.arrivals, game.errand.code], [2, "0102"])

	shop.queue_free()
	await process_frame

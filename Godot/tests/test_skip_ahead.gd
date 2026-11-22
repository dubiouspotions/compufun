extends "res://tests/test.gd"
## Cmd+N skips to the next event: the wait for a customer, then the walk to the counter.

const GAME := preload("res://game.gd")


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	shop.walk_seconds = 1000.0
	root.add_child(shop)
	await process_frame
	var day: Day = game.day_of(1).duplicate()
	day.first_wait_seconds = Vector2(1000.0, 1000.0)

	game.start_day(day)
	game.open_shop()
	tick(1.0)
	check("nobody yet", game.visitor_state, GAME.VisitorState.NONE)
	check("no walk to skip", shop.skip_walk(), false)
	game.skip_wait()
	tick(0.0)
	check("the skipped wait lets the customer in", game.visitor_state, GAME.VisitorState.WALKING_IN)
	await process_frame
	check("a walk to skip", shop.skip_walk(), true)
	check("the skipped walk reaches the counter", game.visitor_state, GAME.VisitorState.TALKING)

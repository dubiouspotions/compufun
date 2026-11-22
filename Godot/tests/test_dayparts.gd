extends "res://tests/test.gd"
## The day starts in the morning, the second and third arrivals make it midday and afternoon,
## closing makes it evening, and the sky outside follows.

const GAME := preload("res://game.gd")


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	var skater: Customer = load("res://customers/skater_bro.tres")
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	var hat_guy: Customer = load("res://customers/hat_guy.tres")
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var day := make_day(1, [[skater, dust], [entrepreneur, dust], [hat_guy, dust]])
	day.first_wait_seconds = Vector2(5.0, 8.0)
	day.gap_seconds = Vector2(20.0, 40.0)

	check("no day: no daypart", game.daypart, GAME.Daypart.NONE)
	game.start_day(day)
	game.open_shop()
	check("the day starts in the morning, nobody in yet", [game.daypart, game.arrivals], [GAME.Daypart.MORNING, 0])
	tick(4.9)
	check("4.9 s: nobody yet", game.arrivals, 0)
	tick(3.2)
	check("8.1 s: the first customer, morning", [game.arrivals, game.daypart], [1, GAME.Daypart.MORNING])
	check("the sky shows the morning", outside.hour, outside.morning_hour)
	serve()
	check("midday arrival", [game.arrivals, game.daypart], [2, GAME.Daypart.MIDDAY])
	check("the sky shows midday", outside.hour, outside.midday_hour)
	serve()
	check("afternoon arrival", [game.arrivals, game.daypart], [3, GAME.Daypart.AFTERNOON])
	check("the sky shows the afternoon", outside.hour, outside.afternoon_hour)
	serve()
	game.close_shop()
	check("closed: evening", [game.phase, game.daypart], [GAME.Phase.DAY_OVER, GAME.Daypart.EVENING])
	check("the sky shows the evening", outside.hour, outside.evening_hour)
	check("a closed day restores as evening", [game.restore({"phase": "DAY_OVER"}), game.daypart], ["", GAME.Daypart.EVENING])


## Plays the visitor's drop-off to the end and waits out the gap to the next customer, checking
## that nobody comes before the gap's shortest time.
func serve() -> void:
	game.customer_arrived()
	if game.visitor_state == GAME.VisitorState.TALKING:
		game.dialogue_finished()
	game.customer_left()
	var before: int = game.arrivals
	tick(game.day.gap_seconds.x - 0.1)
	check("nobody before the gap's shortest time", game.arrivals, before)
	tick(game.day.gap_seconds.y - game.day.gap_seconds.x + 0.2)

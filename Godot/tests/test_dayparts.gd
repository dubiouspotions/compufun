extends "res://tests/test.gd"
## The day starts in the morning, the second and third arrivals make it midday and afternoon,
## closing makes it evening, and the sky outside follows.

const GAME := preload("res://game.gd")


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	var pierre: Customer = load("res://customers/pierre.tres")
	var javve: Customer = load("res://customers/javve.tres")
	var day := Day.new()
	day.number = 1
	day.customers = [pierre, javve, pierre]
	day.gap_seconds = 10.0

	check("no day: no daypart", game.daypart, GAME.Daypart.NONE)
	game.start_day(day)
	check("first arrival: morning", game.daypart, GAME.Daypart.MORNING)
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


## Plays the visitor's drop-off to the end and waits out the gap to the next customer.
func serve() -> void:
	game.customer_arrived()
	if game.visitor_state == GAME.VisitorState.TALKING:
		game.dialogue_finished()
	game.customer_left()
	tick(game.day.gap_seconds)

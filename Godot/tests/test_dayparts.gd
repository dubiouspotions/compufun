extends "res://tests/test.gd"
## Each arrival moves the day on (morning, midday, evening), closing makes it night, and the
## sky outside follows.

const GAME := preload("res://game.gd")


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	var skater: Customer = load("res://customers/skater_bro.tres")
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	var day := Day.new()
	day.number = 1
	day.customers = [skater, entrepreneur, skater]
	day.gap_seconds = 10.0

	game.start_day(day)
	check("first arrival: morning", game.daypart, GAME.Daypart.MORNING)
	check("the sky shows the morning", outside.hour, outside.morning_hour)
	serve()
	check("midday arrival", [game.arrivals, game.daypart], [2, GAME.Daypart.MIDDAY])
	check("the sky shows midday", outside.hour, outside.midday_hour)
	serve()
	check("evening arrival", [game.arrivals, game.daypart], [3, GAME.Daypart.EVENING])
	check("the sky shows the evening", outside.hour, outside.evening_hour)
	serve()
	game.close_shop()
	check("closed: night", [game.phase, game.daypart], [GAME.Phase.DAY_OVER, GAME.Daypart.NIGHT])
	check("the sky shows the night", outside.hour, outside.night_hour)


## Plays the visitor's drop-off to the end and waits out the gap to the next customer.
func serve() -> void:
	game.customer_arrived()
	if game.visitor_state == GAME.VisitorState.TALKING:
		game.dialogue_finished()
	game.customer_left()
	tick(game.day.gap_seconds)

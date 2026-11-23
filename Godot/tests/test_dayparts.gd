extends "res://tests/test.gd"
## The day starts in the morning, the second and third arrivals make it midday and afternoon,
## closing makes it evening, and the sky outside follows: it runs forward to each daypart's hour
## within the day, and shows a new day's or a restored state's hour at once.

const GAME := preload("res://game.gd")


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	outside.daypart_seconds = 1.0
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
	await check_eases(outside, outside.morning_hour, outside.midday_hour, "midday")
	serve()
	check("afternoon arrival", [game.arrivals, game.daypart], [3, GAME.Daypart.AFTERNOON])
	await check_eases(outside, outside.midday_hour, outside.afternoon_hour, "the afternoon")
	serve()
	game.close_shop()
	check("closed: evening", [game.phase, game.daypart], [GAME.Phase.DAY_OVER, GAME.Daypart.EVENING])
	await check_eases(outside, outside.afternoon_hour, outside.evening_hour, "the evening")
	check("a closed day restores as evening", [game.restore({"phase": "DAY_OVER"}), game.daypart], ["", GAME.Daypart.EVENING])
	check("a restore to the afternoon shows its hour at once", [game.restore({"arrivals": 3, "daypart": "AFTERNOON"}), outside.hour], ["", outside.afternoon_hour])
	outside.hour = 2.0
	game.start_day(day)
	check("a new day shows the morning at once", outside.hour, outside.morning_hour)


## Checks that the sky leaves [param from] at the daypart change, is between the two hours half way,
## and shows [param to] once the ease is over.
func check_eases(outside: Node, from: float, to: float, what: String) -> void:
	check("the sky starts at %s's hour" % what, is_equal_approx(outside.hour, from), true)
	await create_timer(outside.daypart_seconds * 0.5).timeout
	check("half way to %s, the sky is between the hours" % what, [outside.hour > from and outside.hour < to, outside.seconds_to_daypart() > 0.0], [true, true])
	await create_timer(outside.daypart_seconds * 0.6).timeout
	check("the sky shows %s" % what, [outside.hour, outside.seconds_to_daypart()], [to, 0.0])


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

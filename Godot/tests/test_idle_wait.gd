extends "res://tests/test.gd"
## With an empty counter and nobody in the shop, the next customer comes in at most
## Day.idle_wait_seconds after the last one left; a shorter gap stays, and so do the first wait and
## the full gap while a computer is on the counter.

func run() -> void:
	var day_1: Day = game.day_of(1)  # the week's own day, which restore plays
	var accountant: Customer = day_1.errands[2].customer
	day_1.gap_seconds = Vector2(100.0, 100.0)
	check("the idle wait is 4 s", day_1.idle_wait_seconds, 4.0)

	check("an empty counter after the first customer", game.restore({"day": 1, "arrivals": 2}), "")
	tick(3.9)
	check("nobody yet after 3.9 s", game.visitor, null)
	tick(0.2)
	check("an empty counter shortens a long gap to 4 s", game.visitor, accountant)

	check("a computer on the counter", game.restore({"day": 1, "arrivals": 2, "jobs": [{"errand": "0102_skater_bro"}]}), "")
	tick(50.0)
	check("it keeps the full gap: nobody after 50 s", game.visitor, null)
	tick(50.1)
	check("in after 100 s", game.visitor, accountant)

	day_1.gap_seconds = Vector2(2.0, 2.0)
	game.restore({"day": 1, "arrivals": 2})
	tick(1.9)
	check("a shorter gap stays: nobody after 1.9 s", game.visitor, null)
	tick(0.2)
	check("in after 2 s", game.visitor, accountant)

	var slow_start := make_day(1, [[accountant, load("res://problems/dust_overheat.tres")]])
	slow_start.first_wait_seconds = Vector2(100.0, 100.0)
	game.restore({"day": 1, "phase": "CLOSED"})
	game.start_day(slow_start)
	game.open_shop()
	tick(10.0)
	check("the first wait stays, also on an empty counter", game.visitor, null)

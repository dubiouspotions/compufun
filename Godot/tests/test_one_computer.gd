extends "res://tests/test.gd"
## A customer has one computer: while it is in the shop they don't come in again, and those after
## them on the day wait; after the pickup they come. The shop can close while they can't come.

const GAME := preload("res://game.gd")


func run() -> void:
	var hardware: Problem = load("res://problems/dust_overheat.tres")
	var a := Customer.new()
	a.display_name = "A"
	var b := Customer.new()
	b.display_name = "B"

	game.start_day(make_day(1, [[a, hardware]]))
	game.open_shop()
	tick(0.0)
	walk_through()
	game.close_shop()
	check("day 1 over, A's computer overnight", [game.phase, game.jobs.size()], [GAME.Phase.DAY_OVER, 1])

	game.start_day(make_day(2, [[a, hardware], [b, hardware]]))
	game.open_shop()
	tick(1000.0)
	check("A's computer is in the shop: nobody comes, B waits behind A", [game.visitor, game.arrivals], [null, 0])
	check("nobody can come without a pickup: the shop can close", game.can_close(), true)

	var job: Job = game.jobs[0]
	game.focus_job(job)
	game.fix(Problem.Location.HARDWARE)
	game.set_tested(job)
	game.call_customer(job)
	game.hang_up()
	check("A comes to pick up", [game.visitor == a, game.visit], [true, GAME.Visit.PICKUP])
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	check("A took the computer home", game.jobs.size(), 0)
	check("A can come in again: the shop can't close", game.can_close(), false)
	tick(60.0)
	check("after the gap, A comes in with day 2's errand", [game.visitor == a, game.visit, game.arrivals], [true, GAME.Visit.DROP_OFF, 1])
	walk_through()
	tick(60.0)
	check("then B", [game.visitor == b, game.arrivals], [true, 2])
	walk_through()
	check("everyone came in: the shop can close", game.can_close(), true)

	# The real day 2: the retired accountant's day-1 computer stayed overnight.
	check("restore day 1 over", game.restore({"day": 1, "phase": "DAY_OVER", "arrivals": 3,
			"jobs": [{"customer": "res://customers/retired_accountant.tres", "slot": 0}]}), "")
	game.start_next_day()
	game.open_shop()
	tick(1000.0)
	var accountant: Customer = load("res://customers/retired_accountant.tres")
	var came: Array[Customer] = []
	while game.visitor != null:
		came.append(game.visitor)
		walk_through()
		tick(1000.0)
	check("day 2: the others come, the accountant doesn't while his computer is here", [came.has(accountant), came.size(), game.arrivals], [false, 2, 2])
	game.close_shop()
	check("the shop closes", game.phase, GAME.Phase.DAY_OVER)


## The visitor who walks in drops off the computer and leaves.
func walk_through() -> void:
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()

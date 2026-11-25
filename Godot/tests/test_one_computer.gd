extends "res://tests/test.gd"
## A customer has one computer: while it is in the shop they don't come in again, and those after
## them on the day wait; after the pickup they come. The shop can't close until they came in, unless
## their computer stays in the shop for good (its call rang out): then they never come back, and those
## after them come.

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
	check("A is still due: the shop can't close", game.can_close(), false)

	var job: Job = game.jobs[0]
	_call_back(job)
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
	game.close_shop()

	game.start_day(make_day(3, [[b, hardware], [a, hardware]]))
	game.open_shop()
	tick(1000.0)
	check("day 3: B and A wait for their computers", [game.visitor, game.can_close()], [null, false])
	game.jobs[0].unanswered = true
	tick(1000.0)
	check("A's computer stays for good: A is not due, and B, still due, waits", [game.visitor, game.can_close()], [null, false])
	_call_back(game.jobs[1])
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	tick(1000.0)
	check("after B's pickup, B comes in", [game.visitor == b, game.arrivals], [true, 1])
	walk_through()
	tick(1000.0)
	check("A never comes back: the shop can close", [game.visitor, game.can_close()], [null, true])

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
	check("so the shop can't close", game.can_close(), false)
	_call_back(game.jobs.filter(func(j: Job) -> bool: return j.customer == accountant)[0])
	walk_through()
	tick(1000.0)
	check("after his pickup he comes in", [game.visitor == accountant, game.arrivals], [true, 3])
	walk_through()
	game.close_shop()
	check("the shop closes", game.phase, GAME.Phase.DAY_OVER)


# Fixes and tests [param job], and calls its customer, who comes to pick it up.
func _call_back(job: Job) -> void:
	game.focus_job(job)
	game.connect_cable(job)
	game.fix(job.problem.location)
	game.set_tested(job)
	game.call_customer(job)
	game.hang_up()


## The visitor who walks in drops off the computer and leaves.
func walk_through() -> void:
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()

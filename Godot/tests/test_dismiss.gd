extends "res://tests/test.gd"
## Game.dismiss_visitor, the [x] of the corruption sign customer_x: a regular customer vanishes at
## once with their computers, never comes in again, and the day still ends.

const GAME := preload("res://game.gd")
const SKATER: String = "res://customers/skater_bro.tres"
const ENTREPRENEUR: String = "res://customers/young_entrepreneur.tres"


func run() -> void:
	var skater: Customer = load(SKATER)
	var entrepreneur: Customer = load(ENTREPRENEUR)
	skater.regular = true

	# Day 1: the skater talks, and the [x] sends him away.
	game.start_day(make_day(1, [skater, entrepreneur]))
	game.open_shop()
	check("the skater walks in", game.visitor == skater, true)
	game.customer_arrived()
	game.dismiss_visitor()
	check("gone at once, no computer left", [game.visitor, game.visitor_state, game.jobs.size()], [null, GAME.VisitorState.NONE, 0])
	check("gone for good, by flag", [game.is_gone(skater), game.flag(&"gone_skater_bro")], [true, 1])
	check("he counts as come in", game.arrivals, 1)

	# A customer that the story needs can't be sent away.
	tick(61.0)
	game.customer_arrived()
	game.dismiss_visitor()
	check("not regular: refused, still talking", [game.visitor == entrepreneur, game.visitor_state, game.is_gone(entrepreneur)], [true, GAME.VisitorState.TALKING, false])
	game.dialogue_finished()
	game.customer_left()
	check("the day can end", game.can_close(), true)
	game.close_shop()

	# Day 2: he is skipped, first and last.
	game.start_day(make_day(2, [skater, entrepreneur]))
	game.open_shop()
	check("the skater is skipped: the entrepreneur comes", [game.visitor == entrepreneur, game.arrivals], [true, 2])
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	check("the day can end", game.can_close(), true)
	game.start_day(make_day(3, [entrepreneur, skater]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	check("the gone last customer doesn't hold the day open", [game.can_close(), game.visitor], [true, null])
	tick(1000.0)
	check("and doesn't come", game.visitor, null)

	# The flag survives a snapshot and a restore; a restore can't bring him back.
	var state: Dictionary = game.snapshot()
	check("restore", game.restore(state), "")
	check("still gone after a restore", game.is_gone(skater), true)
	var gone := {"gone_skater_bro": 1}
	check("a gone visitor is refused", game.restore({"day": 1, "arrivals": 1, "visitor": SKATER, "flags": gone}) != "", true)
	check("a gone customer's computer is refused", game.restore({"day": 1, "arrivals": 1, "jobs": [{"customer": SKATER}], "flags": gone}) != "", true)

	# A pickup: he vanishes with the computer, and with an older one of his on the counter.
	var fixed := {"customer": SKATER, "slot": 0, "hardware_fixed": true, "software_fixed": true}
	var older := {"customer": SKATER, "slot": 2}
	check("restore a pickup", game.restore({"day": 1, "arrivals": 2, "jobs": [fixed, older, {"customer": ENTREPRENEUR, "slot": 1}],
			"focus_slot": 0, "connected_slot": 2, "visitor": SKATER, "visit": "PICKUP", "visitor_state": "TALKING"}), "")
	game.dismiss_visitor()
	check("both his computers gone, focus and cable free", [slots(), game.focus, game.connected, game.visitor], [["Young entrepreneur@1"], null, null, null])
	check("nobody to call for his computer", game.can_call(), false)


func make_day(number: int, customers: Array[Customer]) -> Day:
	var d := Day.new()
	d.number = number
	d.customers = customers
	d.first_wait_seconds = Vector2.ZERO
	d.gap_seconds = Vector2(60.0, 60.0)
	return d


## The jobs on the counter as "<customer>@<slot>", oldest first.
func slots() -> Array:
	return game.jobs.map(func(j: Job) -> String: return "%s@%d" % [j.customer.display_name, j.slot])

extends "res://tests/test.gd"
## Game.dismiss_visitor, the [x] of the corruption sign customer_x: the visitor vanishes at once with
## their computers, never comes in again, the next customer comes the given seconds later, and the
## day still ends.

const GAME := preload("res://game.gd")
const SKATER: String = "res://customers/skater_bro.tres"
const ENTREPRENEUR: String = "res://customers/young_entrepreneur.tres"


func run() -> void:
	var skater: Customer = load(SKATER)
	var entrepreneur: Customer = load(ENTREPRENEUR)
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var quiet: Problem = load("res://problems/no_sound.tres")

	# Day 1: the skater talks, and the [x] sends him away.
	game.start_day(make_day(1, [[skater, dust], [entrepreneur, quiet]]))
	game.open_shop()
	check("the skater walks in", game.visitor == skater, true)
	game.customer_arrived()
	game.dismiss_visitor(6.0)
	check("gone at once, no computer left", [game.visitor, game.visitor_state, game.jobs.size()], [null, GAME.VisitorState.NONE, 0])
	check("gone for good, by flag", [game.is_gone(skater), game.flag(&"gone_skater_bro")], [true, 1])
	check("he counts as come in", game.arrivals, 1)

	game.dismiss_visitor(6.0)
	check("with nobody in, nothing changes", [game.visitor, game.arrivals, game.is_gone(entrepreneur)], [null, 1, false])
	tick(61.0)
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	check("the day can end", game.can_close(), true)
	game.close_shop()

	# Day 2: he is skipped, first and last. The entrepreneur's computer is still in, so others come.
	var accountant: Customer = load("res://customers/retired_accountant.tres")
	var hat_guy: Customer = load("res://customers/hat_guy.tres")
	game.start_day(make_day(2, [[skater, dust], [accountant, quiet]]))
	game.open_shop()
	check("the skater is skipped: the accountant comes", [game.visitor == accountant, game.arrivals], [true, 2])
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	check("the day can end", game.can_close(), true)
	game.start_day(make_day(3, [[hat_guy, quiet], [skater, dust]]))
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
	check("restore a pickup", game.restore({"day": 1, "arrivals": 2, "jobs": [fixed, older, {"customer": ENTREPRENEUR, "problem": "no_sound", "slot": 1}],
			"focus_slot": 0, "connected_slot": 2, "visitor": SKATER, "visit": "PICKUP", "visitor_state": "TALKING"}), "")
	game.dismiss_visitor(6.0)
	check("both his computers gone, focus and cable free", [slots(), game.focus, game.connected, game.visitor], [["Young entrepreneur@0"], null, null, null])
	check("nobody to call for his computer", game.can_call(), false)

	# The next customer comes the given seconds after the [x], not a whole gap later.
	check("an empty counter", game.restore({"day": 1}), "")
	game.start_day(make_day(4, [[hat_guy, dust], [entrepreneur, quiet], [accountant, quiet]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	tick(61.0)
	game.customer_arrived()
	check("the entrepreneur talks, the hat guy's computer is in", [game.visitor, slots()], [entrepreneur, ["Hat guy@0"]])
	game.dismiss_visitor(6.0)
	tick(5.9)
	check("nobody comes within the 6 s", game.visitor, null)
	tick(0.2)
	check("the next customer walks in after 6 s", [game.visitor, game.visitor_state], [accountant, GAME.VisitorState.WALKING_IN])


## The jobs on the counter as "<customer>@<slot>", oldest first.
func slots() -> Array:
	return game.jobs.map(func(j: Job) -> String: return "%s@%d" % [j.customer.display_name, j.slot])

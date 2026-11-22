extends "res://tests/test.gd"
## The end: closing the shop on the last day ends the game instead of the night, and a reboot
## starts again on day 1 with every Win95 setup forgotten.

const GAME := preload("res://game.gd")


func run() -> void:
	check("day 6 closes for the night", _close_on(6), GAME.Phase.DAY_OVER)
	check("day 7 closes into the end", _close_on(7), GAME.Phase.ENDED)
	check("the end is in the evening", game.daypart, GAME.Daypart.EVENING)

	check("ENDED restores on day 7", game.restore({"day": 7, "phase": "ENDED"}), "")
	check("ENDED is refused on a day with a next day", game.restore({"day": 6, "phase": "ENDED"}) != "", true)
	check("a refusal keeps the end", game.phase, GAME.Phase.ENDED)

	game.go_to_view(&"End")
	game.setups[Computer.new()] = Win95Setup.new()
	game.reboot()
	check("a reboot starts day 1, closed", [game.day_number, game.phase, game.arrivals], [1, GAME.Phase.CLOSED, 0])
	check("a reboot faces the counter", game.view, &"Main")
	check("a reboot forgets the setups", game.setups.size(), 0)


func _close_on(number: int) -> GAME.Phase:
	var refused: String = game.restore({"day": number, "arrivals": (load(GAME.DAY_PATH % number) as Day).errands.size()})
	if refused != "":
		return GAME.Phase.IDLE
	game.close_shop()
	return game.phase

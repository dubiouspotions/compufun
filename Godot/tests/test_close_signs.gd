extends "res://tests/test.gd"
## Day.close_signs: closing the shop on day 5 starts posters_bounce, and the next day stops it.

const GAME := preload("res://game.gd")
const FLAG: StringName = &"sign_posters_bounce"


func run() -> void:
	check("day 4 closes without it", _close_on(4), 0)
	check("day 5 closes with it", _close_on(5), 1)
	check("the night is still on day 5", [game.day_number, game.phase], [5, GAME.Phase.DAY_OVER])
	game.start_next_day()
	check("day 6 puts the posters back", [game.day_number, game.flag(FLAG)], [6, 0])


func _close_on(number: int) -> int:
	var refused: String = game.restore({"day": number, "arrivals": 2})
	if refused != "":
		return -1
	game.close_shop()
	return game.flag(FLAG)


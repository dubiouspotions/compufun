extends "res://tests/test.gd"
## The weather follows the day: days 2 and 5 rain from morning to evening, the other days are dry, and
## the debug menu's rain switch holds until the next daypart.


func run() -> void:
	var outside: Node = load("res://rooms/shop/outside.tscn").instantiate()
	root.add_child(outside)
	await process_frame
	for number: int in range(1, 8):
		var day: Resource = load("res://days/day_%d.tres" % number)
		game.start_day(day)
		var rainy := number in [2, 5]
		check("day %d rains in the closed morning" % number, outside.raining, rainy)
		check("day %d rain shows" % number, (outside.get_node("%Rain") as CPUParticles3D).emitting, rainy)

	check("restore day 2 at midday", game.restore({"day": 2, "phase": "OPEN", "daypart": "MIDDAY"}), "")
	check("a restored day 2 rains", outside.raining, true)
	outside.raining = false
	game.changed.emit()
	check("the debug switch holds within the daypart", outside.raining, false)
	check("restore day 2 in the evening", game.restore({"day": 2, "phase": "DAY_OVER", "daypart": "EVENING"}), "")
	check("day 2 rains again in the evening", outside.raining, true)
	game.start_next_day()
	check("the next day is dry", outside.raining, false)
	outside.queue_free()

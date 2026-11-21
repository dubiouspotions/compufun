extends "res://tests/test.gd"
## The computer mouse that the ceiling mouse drops, and the storage bin (wiki: Hardware Repair): a
## part with no place in a computer, put away and taken back, kept by a snapshot and a restore.


func run() -> void:
	var mouse: Part = load("res://parts/mouse.tres")
	var fan: Part = load("res://parts/fan.tres")
	check("the computer mouse has no place in a computer", [mouse.fits_computer(), fan.fits_computer()], [false, true])
	check("a part by its id", [Part.named(&"mouse"), Part.named(&"toaster")], [mouse, null])
	check("every() keeps the computer's seven places", Part.every().size(), 7)

	# A customer leaves a computer on the counter, so a snapshot has a day to restore.
	var customer: Customer = load("res://customers/skater_bro.tres")
	var day := Day.new()
	day.number = 1
	day.customers = [customer] as Array[Customer]
	day.first_wait_seconds = Vector2.ZERO
	day.gap_seconds = Vector2(60.0, 60.0)
	game.start_day(day)
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()

	check("nothing to put away", game.put_in_storage(), false)
	check("nothing to take back", game.take_from_storage(), false)
	check("the computer mouse in the hand", [game.take_new_part(mouse), game.hand.part], [true, mouse])
	check("put away", [game.put_in_storage(), game.hand, game.stored.size()], [true, null, 1])
	game.take_new_part(fan)
	game.put_in_storage()
	check("the last part comes back first", [game.take_from_storage(), game.hand.part, game.stored.size()], [true, fan, 1])
	check("a full hand takes nothing back", game.take_from_storage(), false)

	var saved: Dictionary = game.snapshot()
	check("the snapshot names the bin", saved["stored"], ["mouse+"])
	game.trash_part()
	game.take_from_storage()
	game.trash_part()
	check("restore", game.restore(saved), "")
	check("restored", [game.stored.size(), game.stored[0].part, game.hand.part], [1, mouse, fan])
	saved["stored"] = ["toaster"]
	check("an unknown part: refused", game.restore(saved).contains("no part 'toaster'"), true)

	# A computer has no place for the computer mouse, open or not.
	game.trash_part()
	var job: Job = game.jobs[0]
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	game.open_case(job, true)
	game.take_new_part(mouse)
	check("no place for the computer mouse", [game.can_put(job, mouse), game.put_part(job)], [false, false])
	check("the mat takes it", game.put_on_mat(job), true)
	var state: Dictionary = game.snapshot()
	state["jobs"][0]["parts"]["mouse"] = "mouse"
	check("a computer mouse in a place: refused", game.restore(state).contains("no place 'mouse'"), true)

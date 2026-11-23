extends "res://tests/test.gd"
## The computer mouse that the ceiling mouse drops: a part with no place in a computer. An old
## snapshot with the retired storage bin's parts still restores.


func run() -> void:
	var mouse: Part = load("res://parts/mouse.tres")
	var fan: Part = load("res://parts/fan.tres")
	check("the computer mouse has no place in a computer", [mouse.fits_computer(), fan.fits_computer()], [false, true])
	check("a part by its id", [Part.named(&"mouse"), Part.named(&"toaster")], [mouse, null])
	check("every() keeps the computer's seven places", Part.every().size(), 7)

	# A customer leaves a computer on the counter, so a snapshot has a day to restore.
	var customer: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[customer, load("res://problems/dust_overheat.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()

	check("the computer mouse in the hand", [game.take_new_part(mouse), game.hand.part], [true, mouse])
	var saved: Dictionary = game.snapshot()
	check("the snapshot has no storage bin", saved.has("stored"), false)
	saved["stored"] = ["fan", "toaster"]
	check("an old report with bin contents restores without them", [game.restore(saved), game.hand.part], ["", mouse])

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

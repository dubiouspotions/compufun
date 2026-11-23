extends "res://tests/test.gd"
## Game.restore(Game.snapshot()) keeps what play made: a software fix stays fixed rather than broken
## again.


func run() -> void:
	var no_sound: Problem = load("res://problems/no_sound.tres")
	var dust: Problem = load("res://problems/dust_overheat.tres")
	var accountant: Customer = load("res://customers/retired_accountant.tres")
	var skater: Customer = load("res://customers/skater_bro.tres")
	game.start_day(make_day(1, [[accountant, no_sound], [skater, dust]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var setup: Win95Setup = game.setup_for(job)
	setup.muted = false
	game.set_software_fixed(job, no_sound.software_check.is_fixed(setup))
	check("the fix holds before the restore", [job.software_fixed, setup.muted], [true, false])

	check("a restore of the snapshot", game.restore(game.snapshot()), "")
	var restored: Job = game.jobs[0]
	check("the fix holds after it: the running copy isn't broken again", [restored.software_fixed, game.setup_for(restored).muted], [true, false])


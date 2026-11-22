extends "res://tests/test.gd"
## Bootfloppy: the problem puts a floppy in A:, Game.eject_floppy takes it out and fixes the job.
## Day.close_flags: closing day 3 turns the logo blue, and it stays blue on day 4.

const GAME := preload("res://game.gd")


func run() -> void:
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	var floppy: Problem = load("res://problems/bootfloppy.tres")
	game.start_day(make_day(2, [[entrepreneur, floppy]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	var job: Job = game.jobs[0]
	check("the problem puts a floppy in A:", [game.has_floppy(job), job.software_fixed], [true, false])
	game.eject_floppy(job)
	check("ejected: out and fixed", [game.has_floppy(job), job.software_fixed], [false, true])
	check("the .tres keeps no floppy", entrepreneur.computer.win95_setup.floppy_in_a, false)

	var day_3: Day = game.day_of(3)
	check("day 3 is the first to close with it", day_3.close_flags, {&"sign_logo_blue": 1})
	game.restore({"day": 3, "arrivals": day_3.codes().size()})
	check("blue only from closing", game.flag(&"sign_logo_blue"), 0)
	game.close_shop()
	check("closing day 3 turns it blue", game.flag(&"sign_logo_blue"), 1)
	game.start_next_day()
	check("still blue on day 4", [game.day_number, game.flag(&"sign_logo_blue")], [4, 1])

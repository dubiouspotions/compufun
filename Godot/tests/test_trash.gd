extends "res://tests/test.gd"
## The trash can (wiki: Hardware Repair): a thrown part lies on top for good, stays overnight and
## through a snapshot, and goes only with a new game.


func run() -> void:
	var fan: Part = load("res://parts/fan.tres")
	var cpu: Part = load("res://parts/cpu.tres")
	game.start_day(game.day_of(1))

	check("nothing to throw", game.trash_part(), false)
	game.take_new_part(fan)
	game.trash_part()
	game.take_new_part(cpu)
	check("thrown on top", [game.trash_part(), game.hand, game.trashed.size(), game.trashed[1].part], [true, null, 2, cpu])

	var saved: Dictionary = game.snapshot()
	check("the snapshot names the trash", saved["trashed"].size(), 2)
	game.take_new_part(fan)
	game.trash_part()
	check("restore", game.restore(saved), "")
	check("restored", [game.trashed.size(), game.trashed[1].part, game.hand], [2, cpu, null])

	game.start_next_day()
	check("not emptied overnight", [game.day_number, game.trashed.size()], [2, 2])
	game.reboot()
	check("a new game starts with an empty trash", game.trashed.size(), 0)

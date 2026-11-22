extends "res://tests/test.gd"
## The trash can (wiki: Hardware Repair): a thrown part lies on top, comes back with an empty
## hand, stays overnight and through a snapshot, and goes only with a new game.


func run() -> void:
	var fan: Part = load("res://parts/fan.tres")
	var cpu: Part = load("res://parts/cpu.tres")
	game.start_day(game.day_of(1))

	check("nothing to throw", game.trash_part(), false)
	check("nothing to fish out", game.take_from_trash(), false)
	game.take_new_part(fan)
	game.trash_part()
	game.take_new_part(cpu)
	check("thrown on top", [game.trash_part(), game.hand, game.trashed.size()], [true, null, 2])
	check("the top part comes back", [game.take_from_trash(), game.hand.part, game.trashed.size()], [true, cpu, 1])
	check("a full hand takes nothing", game.take_from_trash(), false)
	game.trash_part()

	var saved: Dictionary = game.snapshot()
	check("the snapshot names the trash", saved["trashed"].size(), 2)
	game.take_from_trash()
	check("restore", game.restore(saved), "")
	check("restored", [game.trashed.size(), game.trashed[1].part, game.hand], [2, cpu, null])

	game.start_next_day()
	check("not emptied overnight", [game.day_number, game.trashed.size()], [2, 2])
	game.reboot()
	check("a new game starts with an empty trash", game.trashed.size(), 0)

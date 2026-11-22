extends "res://tests/test.gd"
## Game.runs_cambion reads the flag <customer>_runs_cambion: in such a computer the Calculator answers
## every sum with the corruption sign calc_666's number, and clearing the flag uninstalls Cambion.

const CAMBION_RESULT_META: StringName = &"win95_cambion_result"  # calculator.gd's; preloading it needs Game


func run() -> void:
	var skater: Customer = load("res://customers/skater_bro.tres")
	var accountant: Customer = load("res://customers/retired_accountant.tres")
	check("no flag, no Cambion", game.runs_cambion(skater), false)
	game.set_flag(&"skater_bro_runs_cambion")
	check("the flag installs it in his computer only", [game.runs_cambion(skater), game.runs_cambion(accountant)], [true, false])

	root.set_meta(CAMBION_RESULT_META, "666")
	var calculator: Node = (load("res://win95/calculator.tscn") as PackedScene).instantiate()
	root.add_child(calculator)
	await process_frame
	calculator.set("_job", Job.new(skater, null, 0, 0))
	check("1 + 1 in his computer", _sum(calculator), "666")
	game.set_flag(&"skater_bro_runs_cambion", 0)
	check("clearing the flag uninstalls it", [game.runs_cambion(skater), _sum(calculator)], [false, "2"])
	calculator.set("_job", Job.new(accountant, null, 0, 0))
	game.set_flag(&"skater_bro_runs_cambion")
	check("another customer's computer adds up", _sum(calculator), "2")
	root.remove_meta(CAMBION_RESULT_META)


func _sum(calculator: Node) -> String:
	for key: String in ["C", "1", "+", "1", "="]:
		calculator.call("press", key)
	return (calculator.get_node("%Display") as Label).text

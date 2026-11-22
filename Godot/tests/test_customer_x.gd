extends "res://tests/test.gd"
## The corruption sign customer_x shows its [x] only over its target customer (the young
## entrepreneur), only while they talk and sign_customer_x is set; a click sends them away for good.

const GAME := preload("res://game.gd")


func run() -> void:
	var overlay: Control = (load("res://ui/dialogue_overlay.tscn") as PackedScene).instantiate()
	overlay.add_to_group(&"dialogue_overlay")
	root.add_child(overlay)
	var sign: Node = (load("res://corruption/customer_x.tscn") as PackedScene).instantiate()
	root.add_child(sign)
	await process_frame
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	var skater: Customer = load("res://customers/skater_bro.tres")
	var dust: Problem = load("res://problems/dust_overheat.tres")
	check("its target is the young entrepreneur", sign.get("target"), entrepreneur)
	var close: Button = sign.get_node("%Close")

	game.set_flag(&"sign_customer_x")
	game.start_day(make_day(6, [[skater, dust], [entrepreneur, dust]]))
	game.open_shop()
	game.customer_arrived()
	check("not over another customer", [game.visitor, sign.is_processing(), close.get_parent() == sign], [skater, false, true])
	game.dialogue_finished()
	game.customer_left()
	tick(61.0)
	check("not while the target walks in", [game.visitor, sign.is_processing()], [entrepreneur, false])
	game.customer_arrived()
	check("over the target while they talk", [sign.is_processing(), close.get_parent() == overlay], [true, true])
	game.set_flag(&"sign_customer_x", 0)
	check("not without the flag", sign.is_processing(), false)
	game.set_flag(&"sign_customer_x")
	close.pressed.emit()
	check("a click sends them away for good", [game.visitor, game.is_gone(entrepreneur), game.flag(&"gone_young_entrepreneur"), game.jobs.size()], [null, true, 1, 1])

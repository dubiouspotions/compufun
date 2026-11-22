extends "res://tests/test.gd"
## A day sets its flags as it starts, and a conversation as it starts to play; a later conversation
## can check and clear them.


func run() -> void:
	var problem: Problem = load("res://problems/no_sound.tres")
	var a_talk := arrival("A", {&"met_a": 1, &"sign_test": 2}, [], [&"met_a"])
	var b_talk := arrival("B", {&"met_a": 0}, [&"met_a"], [])
	var a := Customer.new()
	a.display_name = "A"
	var b := Customer.new()
	b.display_name = "B"
	var d := make_day(1, [[a, problem, [a_talk]], [b, problem, [b_talk]]])
	d.set_flags = {&"sign_day": 1, &"cleared_by_day": 0}
	game.set_flag(&"cleared_by_day")
	game.start_day(d)
	check("the day set its flags as it started", [game.flag(&"sign_day"), game.flags.has(&"cleared_by_day")], [1, false])
	game.open_shop()
	tick(1.0)

	check("A is in", game.visitor, a)
	game.customer_arrived()
	check("A's conversation set its flags", [game.flag(&"met_a"), game.flag(&"sign_test")], [1, 2])
	game.dialogue_finished()
	game.customer_left()
	tick(1000.0)
	check("B is in", game.visitor, b)
	game.customer_arrived()
	check("B's conversation, which needs met_a, plays", game.conversation, b_talk)
	check("and clears met_a; sign_test stays", [game.flags.has(&"met_a"), game.flag(&"sign_test")], [false, 2])


func arrival(display_name: String, sets: Dictionary[StringName, int], needs: Array[StringName], not_with: Array[StringName]) -> Conversation:
	var conversation := Conversation.new()
	conversation.id = StringName(display_name + "/arrive")
	conversation.set_flags = sets
	conversation.when = Condition.new()
	conversation.when.need_flags = needs
	conversation.when.not_flags = not_with
	var line := DialogueLine.new()
	line.text = display_name + " arrives"
	conversation.lines = [line]
	return conversation

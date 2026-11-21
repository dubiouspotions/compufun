extends "res://tests/test.gd"
## A conversation sets its flags as it starts to play, and a later conversation can check and clear
## them.


func run() -> void:
	var problem: Problem = load("res://problems/no_sound.tres")
	var a := customer("A", problem, {&"met_a": 1, &"sign_test": 2}, [], [&"met_a"])
	var b := customer("B", problem, {&"met_a": 0}, [&"met_a"], [])
	var d := Day.new()
	d.customers = [a, b]
	d.first_wait_seconds = Vector2.ZERO
	game.start_day(d)

	game.customer_arrived()
	check("A's conversation set its flags", [game.flag(&"met_a"), game.flag(&"sign_test")], [1, 2])
	game.dialogue_finished()
	game.customer_left()
	tick(1000.0)
	check("B is in", game.visitor, b)
	game.customer_arrived()
	check("B's conversation, which needs met_a, plays", game.conversation, b.conversations[0])
	check("and clears met_a; sign_test stays", [game.flags.has(&"met_a"), game.flag(&"sign_test")], [false, 2])


func customer(display_name: String, problem: Problem, sets: Dictionary[StringName, int], needs: Array[StringName], not_with: Array[StringName]) -> Customer:
	var c := Customer.new()
	c.display_name = display_name
	c.problem = problem
	var conversation := Conversation.new()
	conversation.id = &"arrive"
	conversation.set_flags = sets
	conversation.when = Condition.new()
	conversation.when.need_flags = needs
	conversation.when.not_flags = not_with
	var line := DialogueLine.new()
	line.text = display_name + " arrives"
	conversation.lines = [line]
	c.conversations = [conversation]
	return c

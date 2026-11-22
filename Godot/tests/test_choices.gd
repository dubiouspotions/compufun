extends "res://tests/test.gd"
## The player's choices: a choice shows only when its condition holds and a reply can play, the
## first matching reply plays and sets its flags, and a reply's own choices lead further.


func run() -> void:
	var c := Customer.new()
	c.display_name = "Pat"
	var arrive := reply_of(["My computer is broken."], {}) as Reply
	var talk := Conversation.new()
	talk.id = &"arrive"
	talk.lines = arrive.lines
	var installed := choice("Did you install anything?", [
		reply_of(["Well... Cambion, from a friend."], {&"pat_confessed": 1}, [&"pat_pressed"]),
		reply_of(["No, nothing."], {}),
	])
	var press := choice("Think hard.", [reply_of(["Hmm."], {&"pat_pressed": 1})])
	installed.replies[1].choices = [press]
	var secret := choice("Is it Cambion?", [reply_of(["How do you know?"], {})])
	secret.when = Condition.new()
	secret.when.need_flags = [&"knows_cambion"]
	var empty := choice("Nobody answers this.", [])
	talk.choices = [installed, secret, empty]
	game.start_day(make_day(1, [[c, load("res://problems/no_sound.tres"), [talk]]]))
	game.open_shop()
	tick(1.0)
	game.customer_arrived()
	check("the arrival plays", game.conversation, talk)

	check("only the choice whose condition holds and that has a reply", game.offered(talk), [installed])
	var first: Reply = game.choose(installed)
	check("the first matching reply plays: no confession yet", first.lines[0].text, "No, nothing.")
	check("its follow-up", game.offered(first), [press])
	var pressed: Reply = game.choose(press)
	check("pressing sets the flag", [pressed.lines[0].text, game.flag(&"pat_pressed")], ["Hmm.", 1])
	var again: Reply = game.choose(installed)
	check("asked again, the reply that needs the flag plays and sets its own", [again.lines[0].text, game.flag(&"pat_confessed")], ["Well... Cambion, from a friend.", 1])
	game.set_flag(&"knows_cambion")
	check("a flag unlocks a choice", game.offered(talk), [installed, secret])
	check("every line of the tree, for the voices", talk.all_lines().size(), 5)


func choice(text: String, replies: Array) -> Choice:
	var each := Choice.new()
	each.text = text
	each.replies.assign(replies)
	return each


func reply_of(texts: Array, sets: Dictionary[StringName, int], needs: Array[StringName] = []) -> Reply:
	var reply := Reply.new()
	for text: String in texts:
		var line := DialogueLine.new()
		line.text = text
		reply.lines.append(line)
	reply.set_flags = sets
	if not needs.is_empty():
		reply.when = Condition.new()
		reply.when.need_flags = needs
	return reply

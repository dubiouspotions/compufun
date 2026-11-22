extends "res://tests/test.gd"
## The dialogue box walks a conversation tree: a click finishes a line, then goes on; under the last
## line it shows the choices, a pick plays the reply, a reply without choices returns to its list, a deeper list goes back up, and the leave
## button ends the conversation.


func run() -> void:
	var c := Customer.new()
	c.display_name = "Pat"
	var talk := Conversation.new()
	talk.id = &"arrive"
	talk.lines = [line("Hi.")]
	var how := choice("How long?", reply_of("Since Monday."))
	var deep_reply := reply_of("Installed something.")
	deep_reply.lines.push_front(line("Hm."))
	var why := choice("Why?", deep_reply)
	deep_reply.choices = [choice("What?", reply_of("Cambion."))]
	talk.choices = [how, why]
	c.conversations = [talk]
	game.start_day(make_day(1, [[c, load("res://problems/no_sound.tres")]]))
	game.open_shop()
	tick(1.0)
	game.customer_arrived()

	var box: Control = (load("res://ui/dialogue_overlay.tscn") as PackedScene).instantiate()
	root.add_child(box)
	await process_frame
	var ended := [false]
	box.connect(&"finished", func() -> void: ended[0] = true)
	box.call(&"start", c, talk)
	await process_frame
	check("under the last line: the choices and the leave button", [text(box), buttons(box)], ["Hi.", ["> How long?", "> Why?", "> That's all, thanks."]])
	click(box)
	check("a click doesn't skip the choices", buttons(box).size(), 3)
	press(box, 0)
	await process_frame
	check("the reply shows, with the same list under it", [text(box), buttons(box).size()], ["Since Monday.", 3])
	press(box, 1)
	await process_frame
	check("a two-line reply: the first line, no choices yet", [text(box), buttons(box)], ["Hm.", []])
	click(box)
	check("a click shows the rest of the line", (box.get_node("%LineLabel") as TypedLabel).is_typing(), false)
	box.call(&"_process", 0.5)
	check("not yet on after half a second", text(box), "Hm.")
	box.call(&"_process", 1.5)
	await process_frame
	check("on by itself once the line has been quiet long enough: a deeper list, with a way back", [text(box), buttons(box)], ["Installed something.", ["> What?", "> Something else..."]])
	press(box, 1)
	await process_frame
	check("back up", buttons(box).size(), 3)
	press(box, 2)
	check("leave ends the conversation", ended[0], true)


func click(box: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	box.call(&"_on_click", event)


func press(box: Control, index: int) -> void:
	var live := box.get_node("%Choices").get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	(live[index] as Button).pressed.emit()


func buttons(box: Control) -> Array:
	return box.get_node("%Choices").get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).map(func(b: Button) -> String: return b.text)


func text(box: Control) -> String:
	return (box.get_node("%LineLabel") as Label).text


func line(text_: String) -> DialogueLine:
	var each := DialogueLine.new()
	each.text = text_
	return each


func choice(text_: String, reply: Reply) -> Choice:
	var each := Choice.new()
	each.text = text_
	each.replies = [reply]
	return each


func reply_of(text_: String) -> Reply:
	var reply := Reply.new()
	reply.lines = [line(text_)]
	return reply

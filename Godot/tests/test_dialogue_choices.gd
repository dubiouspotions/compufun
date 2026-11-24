extends "res://tests/test.gd"
## The dialogue box plays a conversation from a story file (with the fades off): a click finishes a
## line, then goes on; 48 px under the last line it shows the choices, a pick plays the reply, a +
## reply returns to its list, a deeper list goes back up, and the leave button goes on below the list.

const ERRAND := """customer: skater_bro

== drop-off
(neutral) Hi.
+ How long?
	(neutral) Since Monday.
+ Why?
	(neutral) Hm.
	(neutral) Installed something.
	+ What?
		(neutral) Cambion.
(neutral) See you.
"""


func run() -> void:
	var c := Customer.new()
	c.display_name = "Pat"
	var parsed := StoryFormat.parse_errand(ERRAND, "res://story/errands/0101_pat.errand")
	check("the errand parses", parsed.errors, PackedStringArray())
	var talk: Conversation = (parsed.value as Errand).conversations[0]
	game.start_day(make_day(1, [[c, load("res://problems/no_sound.tres"), [talk]]]))
	game.open_shop()
	tick(1.0)
	game.customer_arrived()

	var box: Control = (load("res://ui/dialogue_overlay.tscn") as PackedScene).instantiate()
	root.add_child(box)
	await process_frame
	box.set(&"choice_fade_seconds", 0.0)  # the steps below follow the logic, not the fades
	var ended := [false]
	box.connect(&"finished", func(_leaving: Array[DialogueLine]) -> void: ended[0] = true)
	box.call(&"start", c, talk)
	await process_frame
	check("no choices while the customer talks", buttons(box), [])
	await settle(box)
	check("under the last line: the choices and the leave button", [text(box), buttons(box)], ["Hi.", ["> How long?", "> Why?", "> That's all, thanks."]])
	await process_frame
	var gap: float = (box.get_node("%Choices") as Control).get_global_rect().position.y - (box.get_node("%LineLabel") as Control).get_global_rect().end.y
	check("the choices stand 48 px below the line", gap, 48.0)
	click(box)
	check("a click doesn't skip the choices", buttons(box).size(), 3)
	press(box, 0)
	await process_frame
	check("a pick hides the choices while the reply plays", buttons(box), [])
	await settle(box)
	check("the reply shows, with the same list under it", [text(box), buttons(box).size()], ["Since Monday.", 3])
	press(box, 1)
	await process_frame
	check("a two-line reply: the first line, no choices yet", [text(box), buttons(box)], ["Hm.", []])
	click(box)
	check("a click shows the rest of the line", (box.get_node("%LineLabel") as TypedLabel).is_typing(), false)
	box.call(&"_process", 0.5)
	check("not yet on after half a second", text(box), "Hm.")
	box.call(&"_process", 1.5)
	await settle(box)
	check("on by itself once the line has been quiet long enough: a deeper list, with a way back", [text(box), buttons(box)], ["Installed something.", ["> What?", "> Something else..."]])
	press(box, 1)
	await process_frame
	var how_long: Button = live(box)[0]
	check("back up, the picks greyed", [buttons(box).size(), how_long.get_theme_color(&"font_color")], [3, box.get(&"asked_color")])
	press(box, 2)
	await settle(box)
	check("leave goes on below the list", [text(box), buttons(box), ended[0]], ["See you.", [], false])
	click(box)
	check("then the conversation is over", ended[0], true)

	box.set(&"choice_fade_seconds", 0.18)
	box.call(&"start", c, talk)
	await settle(box)
	press(box, 0)
	check("with the fades on, the reply waits while the other choices fade", text(box), "Hi.")
	press(box, 1)
	await create_timer(0.5).timeout
	check("then the picked one's reply plays; a second click during the fade did nothing", text(box), "Since Monday.")


# Lets the shown line finish and go quiet, so pending choices show.
func settle(box: Control) -> void:
	(box.get_node("%LineLabel") as TypedLabel).finish()
	box.call(&"_process", 0.5)
	await process_frame


func click(box: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	box.call(&"_on_click", event)


func press(box: Control, index: int) -> void:
	(live(box)[index] as Button).pressed.emit()


func live(box: Control) -> Array:
	return box.get_node("%Choices").get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func buttons(box: Control) -> Array:
	return live(box).map(func(b: Button) -> String: return b.text)


func text(box: Control) -> String:
	return (box.get_node("%LineLabel") as Label).text

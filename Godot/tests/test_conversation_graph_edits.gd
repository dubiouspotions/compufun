extends "res://tests/test.gd"
## Each edit of the Story Lab's conversation graph changes the conversation as docs/dialogue.md
## means it, emits edited, and leaves a story file that parses back to the same text.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
const ConversationGraph := preload("res://dev/story_lab/conversation_graph.gd")
const PATH := "res://story/errands/0101_skater_bro.errand"

var graph: ConversationGraph
var errand: Errand
var talk: Conversation
var edits: int = 0


func run() -> void:
	var text: String = (load("res://tests/test_conversation_graph.gd") as GDScript).get_script_constant_map()["ERRAND"]
	errand = StoryFormat.parse_errand(text, PATH).value as Errand
	talk = errand.conversations[0]
	graph = (load(GRAPH) as PackedScene).instantiate()
	graph.set_anchors_preset(Control.PRESET_TOP_LEFT)
	graph.size = Vector2(1400, 800)
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	root.add_child(graph)
	graph.show_conversation(talk, errand.customer)
	graph.edited.connect(func() -> void: edits += 1)
	await process_frame
	var issue := talk.then
	var questions := issue.then
	var greeting := talk.choices[0]
	var install := questions.choices[1]

	var first := talk.lines[0]
	check("a line's text", [graph.edit_text(first, "  Yo dude!  "), first.text], ["", "Yo dude!"])
	await _check_file("a line's text")
	check("an empty text is refused", [graph.edit_text(first, " "), first.text], ["Type some text, or delete it.", "Yo dude!"])
	check("a text that the file would read as a tag is refused", [graph.edit_text(greeting, "Hi [end]") != "", greeting.text], [true, "Welcome to CompuFun! You're in the right place! How can I help you?"])
	check("the brief", [graph.edit_text(talk, "He wants help."), talk.brief], ["", "He wants help."])
	await _check_file("the brief")

	graph.set_mood(first, &"happy")
	check("a mood", first.mood, &"happy")
	await _check_file("a mood")

	var added := graph.add_line(greeting.replies[0], 1)
	check("a line under a line", greeting.replies[0].lines.map(func(l: DialogueLine) -> String: return l.text), ["Sweet! Maybe you can help a buddy out!", "...", "My computer isn't working!"])
	check("the new line is neutral", added.mood, &"neutral")
	await _check_file("a new line")
	graph.move_line(greeting.replies[0], 1, 0)
	check("drag a line up", greeting.replies[0].lines[0], added)
	await _check_file("a moved line")
	graph.delete_line(greeting.replies[0], 0)
	check("delete a line", greeting.replies[0].lines.size(), 2)

	var choice := graph.add_choice(questions)
	check("a choice joins the list as a -", [questions.choices.size(), questions.choices[4] == choice, choice.returns, choice.ends], [5, true, false, false])
	await _check_file("a new choice")
	var nested := graph.add_choice(greeting.replies[0])
	check("a choice under an answer starts a deeper list", greeting.replies[0].choices, [nested])
	await _check_file("a deeper list")
	graph.move_choice(questions, 4, 0)
	check("drag a choice up", questions.choices[0], choice)
	await _check_file("a moved choice")

	graph.cycle_mark(choice)
	check("- becomes +", [choice.returns, choice.ends], [true, false])
	graph.cycle_mark(choice)
	check("+ becomes end", [choice.returns, choice.ends], [false, true])
	await _check_file("an end mark")
	graph.cycle_mark(choice)
	check("end becomes -", [choice.returns, choice.ends], [false, false])
	await process_frame
	var after := _find(graph.box_of(choice), func(node: Node) -> bool: return node is OptionButton and (node as OptionButton).get_item_text(0) == "Go on below") as OptionButton
	for pick: Array in [[1, true, false], [2, false, true], [0, false, false]]:
		after.select(pick[0])
		after.item_selected.emit(pick[0])
		check("\"%s\" sets returns and ends" % after.get_item_text(pick[0]), [choice.returns, choice.ends], [pick[1], pick[2]])
		await process_frame
		after = _find(graph.box_of(choice), func(node: Node) -> bool: return node is OptionButton and (node as OptionButton).get_item_text(0) == "Go on below") as OptionButton
		check("and the dropdown shows it", after.selected, pick[0])

	var answer := graph.add_answer(choice)
	check("the only answer becomes the else", [choice.replies.size(), choice.replies[0] == answer, answer.when.need_flags, choice.replies[1].when], [2, true, [graph.new_flag], null])
	await _check_file("an answer")
	var third := graph.add_answer(install)
	check("a new answer comes before the else", [install.replies.size(), install.replies[1] == third, install.replies[2].when], [3, true, null])
	check("an answer's condition", [graph.set_condition(third, "not skater_cambion, days 2-4"), third.when.not_flags, third.when.from_day, third.when.to_day], ["", [&"skater_cambion"], 2, 4])
	await _check_file("an answer's condition")
	check("a second else is refused", graph.set_condition(third, "") != "", true)
	check("a bad condition is refused, naming it", [graph.set_condition(third, "Skater!"), third.when.not_flags], ["'Skater!' is not a condition: a flag, not flag, day 3 or days 2-4", [&"skater_cambion"]])
	graph.delete_box(install.replies[2])
	await process_frame
	check("an answer without a condition becomes the else and moves last", [graph.set_condition(third, ""), install.replies[1] == third, third.when], ["", true, null])
	await _check_file("a new else")

	check("a choice's condition", [graph.set_condition(choice, "skater_cambion"), choice.when.need_flags], ["", [&"skater_cambion"]])
	await _check_file("a choice's condition")
	check("no condition", [graph.set_condition(choice, " "), choice.when], ["", null])
	check("flags", [graph.set_flags(answer, "skater_new_windows, skater_mood=2"), answer.set_flags], ["", {&"skater_new_windows": 1, &"skater_mood": 2}])
	await _check_file("flags")
	check("bad flags are refused", [graph.set_flags(answer, "a=b"), answer.set_flags.size()], ["'a=b' is not a flag: name, or name=number", 2])

	var below := graph.go_on_below(questions)
	check("go on below a list", [questions.then == below, below.lines.size()], [true, 1])
	await _check_file("go on below")
	check("a list goes on below once", graph.go_on_below(questions), null)

	var before := _count()
	graph.delete_box(choice)
	await process_frame
	check("delete a choice and its answers", [questions.choices.has(choice), _count()], [false, before - 3])
	await _check_file("a deleted choice")
	graph.delete_box(below)
	await process_frame
	check("delete what goes on below", questions.then, null)
	graph.delete_box(issue.choices[0])
	await process_frame
	check("a list that loses its last choice takes in what came below it", [issue.choices.size(), issue.then], [4, null])
	await _check_file("a folded list")
	check("every edit emitted edited", edits, 27)

	await _check_in_place(questions)
	await _check_effect_and_answers(questions)


# A line's own effect from its dropdown, and dragging a choice's answers into another order.
func _check_effect_and_answers(questions: Reply) -> void:
	var line := questions.choices[0].replies[0].lines[0]
	var effect := _find(graph.box_of(questions.choices[0].replies[0]), func(node: Node) -> bool: return node is OptionButton and (node as OptionButton).get_item_text(0) == "Conversation's voice") as OptionButton
	check("a line speaks with its conversation's effect", [effect.selected, line.effect], [0, null])
	for i: int in effect.item_count:
		if effect.get_item_text(i) == "cambion_glitch":
			effect.select(i)
			effect.item_selected.emit(i)
	check("its dropdown gives it its own", line.effect.resource_path, "res://voices/effects/cambion_glitch.tres")
	await _check_file("a line's own effect")

	var install := questions.choices[1]
	var answer := graph.add_answer(install)
	await process_frame
	var first := install.replies[0]
	check("moving the else from last is refused", [graph.move_answer(install, install.replies.size() - 1, 0) != "", install.replies[0]], [true, first])
	check("moving an if answer works", [graph.move_answer(install, 1, 0), install.replies[0]], ["", answer])
	await process_frame
	var box := graph.box_of(install.replies[1])
	var grip := _find(box, func(node: Node) -> bool: return node is Label and node.get(&"text") == "::") as Label
	check("an answer box has a drag handle when its choice has several", grip != null, true)
	await _check_file("moved answers")


# Edits a line and a chip as a writer does: double-click, type, Enter; and adds with the buttons.
func _check_in_place(questions: Reply) -> void:
	var line := questions.choices[0].replies[0].lines[0]
	var label := _find(graph.box_of(questions.choices[0].replies[0]), func(node: Node) -> bool: return node is Label and node.get(&"text") == line.text) as Label
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	label.gui_input.emit(click)
	var field := _find(graph.box_of(questions.choices[0].replies[0]), func(node: Node) -> bool: return node is TextEdit) as TextEdit
	check("a double-click opens the line's whole text", field.text if field != null else null, line.text)
	if field == null:
		return
	check("in an editor as wide as the box, five lines tall", [field.custom_minimum_size.x >= graph.box_width - 24, field.custom_minimum_size.y >= field.get_line_height() * 5], [true, true])
	field.text = "Right after the new\nWindows, dude."
	field.gui_input.emit(_key(KEY_ESCAPE))
	await process_frame
	check("Esc cancels", line.text, "Right after I got the new Windows.")
	_find(graph.box_of(questions.choices[0].replies[0]), func(node: Node) -> bool: return node is Label and node.get(&"text") == line.text).gui_input.emit(click)
	field = _find(graph.box_of(questions.choices[0].replies[0]), func(node: Node) -> bool: return node is TextEdit) as TextEdit
	field.text = "Right after the new\nWindows, dude."
	field.gui_input.emit(_key(KEY_ENTER, true))
	check("Ctrl+Enter sets it, a line break as a space", line.text, "Right after the new Windows, dude.")
	await process_frame
	var chip := _find(graph.box_of(questions.choices[2]), func(node: Node) -> bool: return node is Button and node.get(&"text") == "only if skater cambion") as Button
	chip.pressed.emit()
	var editor := _find(chip, func(node: Node) -> bool: return node is StoryConditionEditor) as StoryConditionEditor
	check("the chip opens the condition editor with its condition", StoryFormat.write_condition(editor.condition()) if editor != null else null, "skater_cambion")
	var is_true := _find(editor, func(node: Node) -> bool: return node is OptionButton and (node as OptionButton).get_item_text(0) == "is true") as OptionButton
	is_true.select(1)
	is_true.item_selected.emit(1)
	check("nothing changes until it closes", questions.choices[2].when.need_flags, [&"skater_cambion"])
	(_find(chip, func(node: Node) -> bool: return node is PopupPanel) as PopupPanel).hide()
	check("closing it sets the condition", [questions.choices[2].when.need_flags, questions.choices[2].when.not_flags], [[], [&"skater_cambion"]])
	await process_frame
	check("and the chip says it in words", _find(graph.box_of(questions.choices[2]), func(node: Node) -> bool: return node is Button and node.get(&"text") == "only if not skater cambion") != null, true)
	await _check_file("in-place edits")

	var answer := questions.choices[0].replies[0]
	_tip(graph.box_of(answer), "Add a choice the player can say after these lines").pressed.emit()
	await process_frame
	check("the + at a box's right edge starts a list under an answer", answer.choices.size(), 1)
	check("and opens the new choice's text", (_find(graph.box_of(answer.choices[0]), func(node: Node) -> bool: return node is TextEdit) as TextEdit).text, graph.new_text)
	_tip(graph.box_of(answer.choices[0]), "Add an answer that plays only when certain facts hold").pressed.emit()
	await process_frame
	check("the + at a choice's right edge adds an if branch", answer.choices[0].replies[0].when.need_flags, [graph.new_flag])
	_then_under(answer.choices[0]).pressed.emit()
	await process_frame
	check("+ then... gives the list a then", answer.then != null, true)
	check("a list that goes on below has no + then...", _then_under(answer.choices[0]), null)
	await _check_file("the add buttons")

	check("the brief shows in the header above the graph, not in a box", _find(graph.box_of(talk), func(node: Node) -> bool: return node is Label and node.get(&"text") == "He wants help."), null)


# The "+ then..." button right under the list whose last choice is [param last], or null.
func _then_under(last: Choice) -> Button:
	var box := graph.box_of(last)
	for node: Node in graph.get_children():
		var holder := node as GraphElement
		if holder == null or holder is GraphNode or holder.is_queued_for_deletion():
			continue
		var button := _button(holder, "+ then...")
		var below := holder.position_offset.y - (box.position_offset.y + box.size.y)
		if button != null and is_equal_approx(holder.position_offset.x, box.position_offset.x) and below >= 0.0 and below <= graph.row_gap:
			return button
	return null


func _tip(under: Node, tooltip: String) -> Button:
	return _find(under, func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text") == tooltip) as Button


func _button(under: Node, text: String) -> Button:
	return _find(under, func(node: Node) -> bool: return node is Button and node.get(&"text") == text) as Button


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	key.ctrl_pressed = ctrl
	return key


func _find(under: Node, matches: Callable) -> Node:
	for node: Node in under.find_children("*", "", true, false):
		if matches.call(node):
			return node
	return null


# Fails unless the errand's story file parses without errors and writes the same text again.
func _check_file(after: String) -> void:
	await process_frame
	var written := StoryFormat.write_errand(errand)
	var parsed := StoryFormat.parse_errand(written, PATH)
	check("after %s, the file parses" % after, parsed.errors, PackedStringArray())
	check("after %s, the file reads back the same" % after, StoryFormat.write_errand(parsed.value as Errand), written)


func _count() -> int:
	return graph.get_children().filter(func(node: Node) -> bool: return node is GraphNode).size()

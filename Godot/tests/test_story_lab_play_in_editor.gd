extends "res://tests/test.gd"
## Play in editor: the Story Lab plays a conversation in the game's dialogue box over the Lab, choices
## and all, from its start (Play in editor) or from a line (Shift+Enter, the sidebar's Play, the
## graph's Play), and leaves the paused game as it was. Play in game still jumps the game there.

const SKATER := "res://story/errands/0101_skater_bro.errand"
const HEADER := "customer: skater_bro\nproblem: dust_overheat\nbrief:\n\tMeet the skater."
const DROP_OFF := """== drop-off
(neutral) Yo!
(thinking) Is this the shop?
- Welcome!
	(happy) Sweet!
- Hi.
	(angry) Whatever.

+ What's wrong?
	set skater_told_us
	(problem) It turns off.
+ Bye. [end]
	(happy) Later!"""
const BROKEN := "== drop-off\n(neutral) Yo!\n- Welcome! [bogus]\n\t(happy) Sweet!"
const PLAY_LINE := "Play from this line in the game's dialogue box"

var lab: Control  # untyped: StoryLab names the Game autoload, which a test script compiled under -s can't
var panel: StoryErrandPanel
var code: CodeEdit
var box: Control


func run() -> void:
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	drafts.put(SKATER, StoryErrandPanel.join(HEADER, PackedStringArray([DROP_OFF])))
	lab = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate() as Control
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("open_story", SKATER)
	panel = lab.call("errand_panel")
	panel.show_view("Text")
	code = panel.find_children("*", "CodeEdit", true, false)[0]
	box = lab.call("editor_play")
	await process_frame
	await _play_in_editor_plays_it_all()
	await _shift_enter_plays_from_the_line()
	await _the_sidebar_and_the_graph_play_from_their_line()
	await _esc_closes_it_at_once()
	await _leaving_lines_show_in_the_box_last()
	await _text_that_does_not_parse_does_not_play()
	_play_in_game_jumps_the_game()
	lab.queue_free()
	await process_frame


func _play_in_editor_plays_it_all() -> void:
	var before: Dictionary = game.snapshot()
	(panel.get("_play_here") as Button).pressed.emit()
	check("Play in editor plays the conversation from its first line", [box.visible, _shown()], [true, "Yo!"])
	check("the status line says which flags it assumed", (lab.get("_status") as Label).text.contains("day 1's morning flags"), true)
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_ENTER))
	await process_frame
	check("Enter goes on to the next line", _shown(), "Is this the shop?")
	check("then the choices show under the box", await _until(func() -> bool: return _choices() == ["Welcome!", "Hi."]), true)
	_pick("Welcome!")
	check("a pick plays its reply", await _until(func() -> bool: return _shown() == "Sweet!"), true)
	check("after a -, the list below it", await _until(func() -> bool: return _choices() == ["What's wrong?", "Bye."]), true)
	_pick("What's wrong?")
	check("a + plays its reply", await _until(func() -> bool: return _shown() == "It turns off."), true)
	check("then the same list again, the pick in grey", await _until(func() -> bool: return _choices() == ["What's wrong?", "Bye."] and _greyed("What's wrong?")), true)
	var flags: Dictionary = (box.call("walk") as RefCounted).get("sandbox").get("flags")  # untyped: ConversationWalk names Game
	check("the reply set its flag on the sandbox, not in the game", [flags.has(&"skater_told_us"), game.flag(&"skater_told_us")], [true, 0])
	_pick("Bye.")
	check("[end] plays its reply", await _until(func() -> bool: return _shown() == "Later!"), true)
	check("then the conversation is over", await _until(func() -> bool: return box.call("is_over")), true)
	check("and the box closes by itself", await _until(func() -> bool: return not box.visible), true)
	check("the game is as it was", game.snapshot(), before)


func _shift_enter_plays_from_the_line() -> void:
	await _caret(10, 3)
	_shift_enter()
	await process_frame
	check("Shift+Enter plays from the line under the cursor", [box.visible, _shown()], [true, "It turns off."])
	check("on through the + list that follows it, its pick greyed", await _until(func() -> bool: return _choices() == ["What's wrong?", "Bye."] and _greyed("What's wrong?")), true)
	check("the text and the cursor stay", [code.text, code.get_caret_line(), code.get_caret_column()], [DROP_OFF, 10, 3])
	root.push_input(_key(KEY_ESCAPE))
	await process_frame
	check("Esc closes it at the choices, and the Lab stays", [box.visible, lab.visible, code.text, code.get_caret_line()], [false, true, DROP_OFF, 10])
	await _caret(5, 1)
	_shift_enter()
	await process_frame
	check("on a choice, it plays from the customer line above it", _shown(), "Sweet!")
	check("then the list below the - list", await _until(func() -> bool: return _choices() == ["What's wrong?", "Bye."] and not _greyed("What's wrong?")), true)
	_shift_enter()
	await process_frame
	check("Shift+Enter again closes it, without a new line", [box.visible, code.text], [false, DROP_OFF])


func _the_sidebar_and_the_graph_play_from_their_line() -> void:
	var sidebar: StoryTextSidebar = panel.find_children("*", "StoryTextSidebar", true, false)[0]
	await _caret(11, 0)
	(sidebar.get("_play") as Button).pressed.emit()
	check("the sidebar's Play does as Shift+Enter", [box.visible, _shown()], [true, "It turns off."])
	box.call("close")
	panel.show_view("Graph")
	await process_frame
	var graph: GraphEdit = panel.find_children("*", "GraphEdit", true, false)[0]
	var answer := panel.errand().conversations[0].then.choices[0].replies[0]
	var play: Button = graph.call("box_of", answer).find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.tooltip_text == PLAY_LINE)[0]
	play.pressed.emit()
	check("so does a line's Play in the graph", [box.visible, _shown()], [true, "It turns off."])
	check("with the list that follows", await _until(func() -> bool: return _choices() == ["What's wrong?", "Bye."]), true)
	box.call("close")
	panel.show_view("Text")


func _esc_closes_it_at_once() -> void:
	await _caret(2, 4)
	code.grab_focus()
	(panel.get("_play_here") as Button).pressed.emit()
	root.push_input(_key(KEY_ESCAPE))
	await process_frame
	check("Esc closes it while a line types", [box.visible, lab.visible], [false, true])
	check("the text, the cursor and its focus stay", [code.text, code.get_caret_line(), code.get_caret_column(), code.has_focus()], [DROP_OFF, 2, 4, true])


func _leaving_lines_show_in_the_box_last() -> void:
	panel.edit_section("== drop-off\n(neutral) Yo!\n(happy) Later! [leaving]")
	(panel.get("_play_here") as Button).pressed.emit()
	check("a leaving line that ends the conversation shows in the box last", await _until(func() -> bool: return _shown() == "Later!"), true)
	check("then it is over, and closes", await _until(func() -> bool: return not box.visible), true)
	panel.edit_section(DROP_OFF)


func _text_that_does_not_parse_does_not_play() -> void:
	panel.edit_section(BROKEN)
	(panel.get("_play_here") as Button).pressed.emit()
	var status: Label = lab.get("_status")
	check("Play in editor doesn't play text that doesn't parse", [box.visible, status.text.contains("doesn't parse")], [false, true])
	status.text = ""
	await _caret(1, 0)
	_shift_enter()
	await process_frame
	check("nor does Shift+Enter, and the status line says so", [box.visible, status.text.contains("doesn't parse")], [false, true])
	panel.edit_section(DROP_OFF)


func _play_in_game_jumps_the_game() -> void:
	var play: Button = panel.get("_play")
	check("Play in game is the old Play", play.text, "Play in game")
	game.load_story(lab.get("drafts").texts())  # as the Lab does after an edit
	play.pressed.emit()
	check("it hides the Lab and plays the errand's conversation in the game", [lab.visible, String(game.conversation.id) if game.conversation != null else ""], [false, "0101/drop-off/1"])
	lab.show()


func _shown() -> String:
	var line := box.call("shown_line") as DialogueLine
	return line.text if line != null else ""


# The texts of the choices under the box.
func _choices() -> Array:
	return _choice_buttons().map(func(b: Button) -> String: return b.text.trim_prefix("> "))


func _choice_buttons() -> Array:
	var choices: Control = box.find_children("Choices", "VBoxContainer", true, false)[0]
	if not choices.visible:
		return []
	return choices.get_children().filter(func(n: Node) -> bool: return n is Button and not n.is_queued_for_deletion())


func _greyed(text: String) -> bool:
	var asked: Color = box.find_children("*", "DialogueOverlay", true, false)[0].get("asked_color")
	var found := _choice_buttons().filter(func(b: Button) -> bool: return b.text == "> " + text)
	return not found.is_empty() and (found[0] as Button).get_theme_color(&"font_color") == asked


func _pick(text: String) -> void:
	var found := _choice_buttons().filter(func(b: Button) -> bool: return b.text == "> " + text)
	if found.is_empty():
		check("the choice '%s' shows" % text, _choices(), [text])
		return
	(found[0] as Button).pressed.emit()


# Waits up to [param seconds] of game time for [param holds] to return true; returns whether it did.
func _until(holds: Callable, seconds: float = 10.0) -> bool:
	for frame: int in roundi(seconds * FPS):
		if holds.call():
			return true
		await process_frame
	return holds.call()


func _caret(line: int, column: int) -> void:
	code.set_caret_line(line)
	code.set_caret_column(column)
	await process_frame  # TextEdit tells caret_changed at the end of the frame


func _shift_enter() -> void:
	code.grab_focus()
	var key := _key(KEY_ENTER)
	key.shift_pressed = true
	root.push_input(key)


func _key(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key

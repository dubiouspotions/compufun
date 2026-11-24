extends "res://tests/test.gd"
## The Story Lab's story mode: an errand fills the window beside its customer's errands, the customer
## strip switches customer, and Esc or "Back to timeline" goes back to the week board. Outside story
## mode, the line under the board drags.

const ERRANDS := "res://story/errands/"
const SKATER_1 := ERRANDS + "0101_skater_bro.errand"
const NICE := ERRANDS + "0102_nice_guy.errand"
const SKATER_2 := ERRANDS + "0201_skater_bro.errand"
const OFFICE_2 := ERRANDS + "0202_office_girl.errand"
const OFFICE_3 := ERRANDS + "0301_office_girl.errand"
const SKATER_3 := ERRANDS + "0302_skater_bro.errand"
const DAY_TEXT := "weather: clear\nwarp: 0\n"


func run() -> void:
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put("res://story/days/day_%d.day" % n, DAY_TEXT)
	drafts.put(SKATER_1, "customer: skater_bro\nproblem: dust_overheat\n\n== drop-off\n(neutral) Yo!\n")
	drafts.put(NICE, "customer: nice_guy\n")
	drafts.put(SKATER_2, "customer: skater_bro\nproblem: no_sound\n")
	drafts.put(OFFICE_3, "customer: office_girl\n")
	drafts.put(OFFICE_2, "customer: office_girl\n")
	drafts.put(SKATER_3, "customer: skater_bro\n")
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()  # StoryLab names Game, which -s can't compile
	lab.set("drafts", drafts)
	root.add_child(lab)
	await _frames(3)
	var board: StoryLabBoard = lab.find_children("*", "StoryLabBoard", true, false)[0]
	var panel: StoryErrandPanel = lab.call("errand_panel")
	var signs := _sign_strip(lab)

	check("the board sits above a line that drags", board.get_parent() is VSplitContainer, true)
	check("the board starts at its old height", board.size.y, float(lab.get("board_height")))

	await _click(_card(lab, SKATER_2).get_global_rect().get_center())
	check("a click on a card opens its errand below the board", [panel.path(), lab.call("story_mode"), board.is_visible_in_tree()], [SKATER_2, false, true])
	var week_height := panel.size.y

	await _click(_button(panel, "Open full").get_global_rect().get_center())
	check("Open full opens story mode on the errand", [lab.call("story_mode"), panel.path()], [true, SKATER_2])
	check("story mode hides the board and the signs", [board.is_visible_in_tree(), signs.is_visible_in_tree()], [false, false])
	check("the errand panel shows, and larger than below the board", [panel.is_visible_in_tree(), panel.size.y > week_height + 300], [true, true])
	check("Open full hides in story mode", _button(panel, "Open full").is_visible_in_tree(), false)

	check("the list holds only the customer's errands, in errand code order", _rows(panel), ["0101_skater_bro", "0201_skater_bro", "0302_skater_bro"])
	check("the open errand's row is highlighted", _pressed_rows(panel), ["0201_skater_bro"])
	check("a row shows the day, the errand code and the problem", _row_texts(panel, "0201_skater_bro"), ["Day 2", "0201", "no_sound"])
	check("a row without a problem says so", _row_texts(panel, "0302_skater_bro"), ["Day 3", "0302", "no repair"])
	await _click(_row(panel, "0302_skater_bro").get_global_rect().get_center())
	check("a click on a row opens that errand in story mode", [panel.path(), lab.call("story_mode"), _pressed_rows(panel)], [SKATER_3, true, ["0302_skater_bro"]])

	await _click(_chip(lab, "office_girl").get_global_rect().get_center())
	check("a click on another customer's chip opens their earliest errand", [panel.path(), lab.call("story_mode")], [OFFICE_2, true])
	check("the list follows the customer", _rows(panel), ["0202_office_girl", "0301_office_girl"])
	check("the open customer's chip is outlined", [_outlined(lab, "office_girl"), _outlined(lab, "skater_bro")], [true, false])
	await _click(_chip(lab, "hat_guy").get_global_rect().get_center())
	check("a click on a customer without errands keeps the open errand", [panel.path(), lab.call("story_mode")], [OFFICE_2, true])

	_key(KEY_ESCAPE)
	await _frames(2)
	check("Esc goes back to the week with the errand open", [lab.call("story_mode"), board.is_visible_in_tree(), signs.is_visible_in_tree(), panel.is_visible_in_tree(), panel.path()], [false, true, true, true, OFFICE_2])
	check("the week view outlines no chip", _outlined(lab, "office_girl"), false)
	_key(KEY_ESCAPE)
	await _frames(2)
	check("a second Esc closes the Lab", lab.visible, false)
	lab.show()
	await _frames(2)

	await _click(_chip(lab, "nice_guy").get_global_rect().get_center())
	check("in the week view a click on a chip opens story mode too", [lab.call("story_mode"), panel.path()], [true, NICE])
	lab.hide()
	await _frames(1)
	lab.show()
	await _frames(2)
	check("hiding and showing the Lab keeps story mode and the errand", [lab.call("story_mode"), panel.path(), board.is_visible_in_tree()], [true, NICE, false])
	await _click(_button(lab, "Back to timeline").get_global_rect().get_center())
	check("Back to timeline goes to the week with the errand open", [lab.call("story_mode"), board.is_visible_in_tree(), panel.path()], [false, true, NICE])
	check("Back to timeline hides in the week view", _button(lab, "Back to timeline").is_visible_in_tree(), false)

	var at := _card(lab, SKATER_1).get_global_rect().get_center()
	_press(at, true)
	await _frames(1)
	_press(at, false)
	await _frames(2)
	check("the first click of a double-click opens the errand below the board", [panel.path(), lab.call("story_mode")], [SKATER_1, false])
	_press(_card(lab, SKATER_1).get_global_rect().get_center(), true, true)
	await _frames(1)
	_press(at, false)
	await _frames(2)
	check("a double-click on a card opens it in story mode", [panel.path(), lab.call("story_mode")], [SKATER_1, true])

	lab.call("show_section", "Problems")
	lab.call("show_section", "Week")
	check("a section button leaves story mode", [lab.call("story_mode"), board.is_visible_in_tree()], [false, true])
	lab.call("open_story", SKATER_1)
	panel.remove_requested.emit(SKATER_1)
	check("removing the errand in story mode opens the customer's next one", [lab.call("story_mode"), panel.path()], [true, SKATER_2])
	lab.call("show_timeline")
	await _frames(2)

	var from := _chip(lab, "hat_guy").get_global_rect().get_center()
	# The day's header: a drop there goes last, wherever the real mouse is, which a headless run can't move.
	var to := _day_header(lab, 3).get_global_rect().get_center()
	_press(from, true)
	await _frames(1)
	var last := from
	for step: int in range(1, 11):
		var next := from.lerp(to, step / 10.0)
		_move(next, next - last)
		last = next
		await _frames(1)
	check("pressing a chip and moving drags it", root.gui_is_dragging(), true)
	_press(to, false)
	await _frames(2)
	check("a chip dropped on a day makes an errand there", drafts.texts().has(ERRANDS + "0303_hat_guy.errand"), true)
	check("and opens it below the board, not in story mode", [panel.path(), lab.call("story_mode")], [ERRANDS + "0303_hat_guy.errand", false])

	lab.queue_free()
	await _frames(1)


func _sign_strip(lab: Control) -> Control:
	for node: Node in lab.find_children("*", "HFlowContainer", true, false):
		if node.get_child_count() > 0 and node.get_child(0) is Label and (node.get_child(0) as Label).text == "Signs":
			return node
	check("the Lab has a sign strip", false, true)
	return null


func _card(lab: Control, path: String) -> Control:
	for node: Node in lab.find_children("*", "PanelContainer", true, false):
		if (node as Control).tooltip_text.begins_with(path.get_file() + "\n") and (node as Control).is_visible_in_tree():
			return node
	check("a card on the board for %s" % path.get_file(), false, true)
	return null


func _day_header(lab: Control, day: int) -> Control:
	for node: Node in lab.find_children("*", "PanelContainer", true, false):
		if (node as Control).tooltip_text.begins_with("Day %d:" % day):
			return node
	check("a header for day %d" % day, false, true)
	return null


func _chip(lab: Control, customer: String) -> Control:
	for node: Node in lab.find_children(customer, "PanelContainer", true, false):
		if (node as Control).tooltip_text.begins_with(customer + "\n"):
			return node
	check("a chip in the customer strip for %s" % customer, false, true)
	return null


func _outlined(lab: Control, customer: String) -> bool:
	return (_chip(lab, customer).get_theme_stylebox("panel") as StyleBoxFlat).border_width_top > 0


func _button(under: Control, text: String) -> Button:
	for node: Node in under.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	check("a button %s" % text, false, true)
	return null


# The rows of the errand list: Buttons named after their errand file.
func _rows(panel: Control) -> Array:
	return _row_buttons(panel).map(func(row: Button) -> String: return String(row.name))


func _pressed_rows(panel: Control) -> Array:
	return _row_buttons(panel).filter(func(row: Button) -> bool: return row.button_pressed).map(func(row: Button) -> String: return String(row.name))


func _row_buttons(panel: Control) -> Array:
	return panel.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return StoryLabBoard.code_of(String(node.name) + ".errand") != "" and (node as Control).is_visible_in_tree())


func _row(panel: Control, stem: String) -> Button:
	for row: Button in _row_buttons(panel):
		if String(row.name) == stem:
			return row
	check("a row for %s" % stem, false, true)
	return null


func _row_texts(panel: Control, stem: String) -> Array:
	return _row(panel, stem).find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func _click(at: Vector2) -> void:
	_press(at, true)
	await _frames(1)
	_press(at, false)
	await _frames(2)


func _press(at: Vector2, down: bool, double: bool = false) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = down
	button.double_click = double
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	button.position = at
	button.global_position = at
	root.push_input(button, true)


func _move(at: Vector2, relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = relative  # the viewport starts a drag once the relatives add up past its threshold
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)


func _key(keycode: Key) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = down
		root.push_input(key)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

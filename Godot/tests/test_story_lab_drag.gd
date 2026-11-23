extends "res://tests/test.gd"
## The Story Lab's week board moves an errand that the mouse drags onto another day, and a click
## without a drag opens it.

const ERRANDS := "res://story/errands/"
const NICE := ERRANDS + "0101_nice_guy.errand"
const OFFICE := ERRANDS + "0201_office_girl.errand"
const DAY_TEXT := "weather: clear\nwarp: 0\n"


func run() -> void:
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	for path: String in StoryFiles.files(ERRANDS, ".errand"):
		drafts.put(path, "")
	for n: int in range(1, 8):
		drafts.put("res://story/days/day_%d.day" % n, DAY_TEXT)
	drafts.put(NICE, "customer: nice_guy\n")
	drafts.put(OFFICE, "customer: office_girl\n")
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await _frames(3)

	var from := _card(lab, NICE).get_global_rect().get_center()
	await _click(from)
	check("a click opens the errand", (lab.call("errand_panel") as StoryErrandPanel).path(), NICE)

	from = _card(lab, NICE).get_global_rect().get_center()
	var onto := _card(lab, OFFICE).get_global_rect()
	# The empty space under day 2's card: a drop onto a card picks its zone from the real mouse, which a headless run can't move.
	var to := Vector2(onto.get_center().x, onto.end.y + 60)
	_press(from, true)
	await _frames(1)
	var at := from
	for step: int in range(1, 11):
		var next := from.lerp(to, step / 10.0)
		_move(next, next - at)
		at = next
		await _frames(1)
	check("pressing a card and moving drags it", root.gui_is_dragging(), true)
	_press(to, false)
	await _frames(2)
	var texts := drafts.texts()
	check("the errand dropped on day 2 comes last that day", texts.get(ERRANDS + "0202_nice_guy.errand"), "customer: nice_guy\n")
	check("its old file is gone", texts.has(NICE), false)
	lab.queue_free()
	await _frames(1)


func _card(lab: Control, path: String) -> Control:
	for node: Node in lab.find_children("*", "PanelContainer", true, false):
		if (node as Control).tooltip_text.begins_with(path.get_file() + "\n"):
			return node
	check("a card on the board for %s" % path.get_file(), false, true)
	return null


func _click(at: Vector2) -> void:
	_press(at, true)
	await _frames(1)
	_press(at, false)
	await _frames(2)


func _press(at: Vector2, down: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = down
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


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

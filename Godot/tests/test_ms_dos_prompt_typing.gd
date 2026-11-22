extends "res://tests/test.gd"
## The MS-DOS Prompt takes typing right after a command runs, and scrolls to keep the prompt in view.
## Keys go through Input's buffer, as real key presses do: input then reaches the prompt at the start
## of a frame, before the new text is laid out.


func run() -> void:
	var prompt: Control = load("res://win95/ms_dos_prompt.tscn").instantiate()
	root.add_child(prompt)
	await process_frame
	var command: LineEdit = prompt.get_node("%Command")
	var scroll: ScrollContainer = prompt.get_node("%Scroll")
	check("the prompt has the focus", command.has_focus(), true)

	await _type("dir")
	check("the line takes typing", command.text, "dir")
	await _key(KEY_ENTER)
	check("Enter runs and clears the line", command.text, "")
	await _type("ver")
	check("typing goes on after a command, with no second Enter", command.text, "ver")
	await _key(KEY_ENTER)

	var bar := scroll.get_v_scroll_bar()
	var behind: Array[String] = []
	for line: String in ["help", "dir", "cd \\", "dir", "help", "ver", "help"]:
		await _type(line)
		await _key(KEY_ENTER)
		for i: int in 3:
			await process_frame
		if scroll.scroll_vertical != int(bar.max_value - bar.page):
			behind.append("%s (%d of %d)" % [line, scroll.scroll_vertical, int(bar.max_value - bar.page)])
	check("the output overflows the window", bar.max_value > bar.page, true)
	check("the view follows each command's output to the bottom; it lagged after", behind, [] as Array[String])


func _type(text: String) -> void:
	for c: String in text:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = c.unicode_at(0)
		event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
		Input.parse_input_event(event)
		await process_frame


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

extends "res://tests/test.gd"
## Scrolling Marquee: Win95's default text enters at the right edge, scrolls left, and starts again
## from the right once it has left. A click ends it.


func run() -> void:
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var saver: Control = load("res://win95/savers/scrolling_marquee.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)
	await process_frame
	check("Win95's default text", saver.get(&"text"), "Where do you want to go today?")
	check("it enters at the right edge", saver.get(&"_x"), 640.0)
	var baseline: float = saver.get(&"_baseline")
	check("the line is on the screen", baseline > 0.0 and baseline <= 480.0, true)
	await create_timer(1.0).timeout
	var moved: float = 640.0 - saver.get(&"_x")
	check("it scrolls left at its speed", absf(moved - saver.get(&"speed")) < 10.0, true)
	var last: float = saver.get(&"_x")
	var restarted_at := INF
	for frame: int in FPS * 10:
		await process_frame
		var x: float = saver.get(&"_x")
		if x > last:
			restarted_at = x
			break
		last = x
	check("once it has left, it starts again from the right edge", restarted_at, 640.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	saver.call(&"_gui_input", click)
	await process_frame
	check("a click ends it", is_instance_valid(saver), false)
	screen.queue_free()

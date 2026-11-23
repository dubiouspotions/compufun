extends "res://tests/test.gd"
## Flying Windows: its flags fly towards the viewer, and one that leaves starts again far away. A key ends it.


func run() -> void:
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var saver: Control = load("res://win95/savers/flying_windows.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)
	await process_frame
	var flags: Array = saver.get(&"_flags")
	check("it flies as many flags as its density", flags.size(), saver.get(&"density"))
	var start: Array = flags.map(func(f: Vector3) -> float: return f.z)
	await process_frame
	var nearer: Array = range(flags.size()).filter(func(i: int) -> bool: return saver.get(&"_flags")[i].z < start[i])
	check("the flags come nearer", nearer.size() > flags.size() / 2, true)
	await create_timer(4.0).timeout
	var restarted: Array = range(flags.size()).filter(func(i: int) -> bool: return saver.get(&"_flags")[i].z > start[i])
	check("flags that left start again far away", restarted.size() > 0, true)
	check("every flag is ahead of the viewer", saver.get(&"_flags").all(func(f: Vector3) -> bool: return f.z > 0.0), true)
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	saver.call(&"_gui_input", key)
	await process_frame
	check("a key ends it", is_instance_valid(saver), false)
	screen.queue_free()

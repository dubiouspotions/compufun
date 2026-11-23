extends "res://tests/test.gd"
## Flying Windows: its logos fly towards the viewer, and one that leaves starts again far away. A key ends it.


func run() -> void:
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var saver: Control = load("res://win95/savers/flying_windows.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)
	await process_frame
	var logos: Array = saver.get(&"_logos")
	check("it flies as many logos as its density", logos.size(), saver.get(&"density"))
	var start: Array = logos.map(func(f: Vector3) -> float: return f.z)
	await process_frame
	var nearer: Array = range(logos.size()).filter(func(i: int) -> bool: return saver.get(&"_logos")[i].z < start[i])
	check("the logos come nearer", nearer.size() > logos.size() / 2, true)
	await create_timer(4.0).timeout
	var restarted: Array = range(logos.size()).filter(func(i: int) -> bool: return saver.get(&"_logos")[i].z > start[i])
	check("logos that left start again far away", restarted.size() > 0, true)
	check("every logo is ahead of the viewer", saver.get(&"_logos").all(func(f: Vector3) -> bool: return f.z > 0.0), true)
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	saver.call(&"_gui_input", key)
	await process_frame
	check("a key ends it", is_instance_valid(saver), false)
	screen.queue_free()

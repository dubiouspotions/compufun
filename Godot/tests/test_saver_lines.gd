extends "res://tests/test.gd"
## Mystify Your Mind and Curves and Colors: in a sized rect they draw trails of lines that stay
## inside it, keep only their set number of copies, and end on a key press.

const MYSTIFY := preload("res://win95/savers/mystify_your_mind.gd")
const CURVES := preload("res://win95/savers/curves_and_colors.gd")


func run() -> void:
	for saver_script: Script in [MYSTIFY, CURVES]:
		var name := saver_script.resource_path.get_file()
		var saver: Control = saver_script.new()
		saver.size = Vector2(640, 480)
		root.add_child(saver)
		await create_timer(3.0).timeout
		var trails: Array = []
		if saver_script == MYSTIFY:
			for shape: Object in saver.get("_shapes"):
				trails.append(shape.get("trail"))
			check("%s: two shapes" % name, trails.size(), 2)
		else:
			trails.append(saver.get("_trail"))
		var kept: int = saver.get("lines") if saver_script == MYSTIFY else saver.get("length")
		var inside := true
		for trail: Array in trails:
			check("%s: a full trail of %d copies" % [name, kept], trail.size(), kept)
			for copy: PackedVector2Array in trail:
				for point: Vector2 in copy:
					inside = inside and Rect2(Vector2.ZERO, saver.size).grow(0.5).has_point(point)
		check("%s: every line stays in the rect" % name, inside, true)
		var key := InputEventKey.new()
		key.keycode = KEY_A
		key.pressed = true
		saver.call(&"_gui_input", key)
		await process_frame
		check("%s: a key ends it" % name, is_instance_valid(saver), false)

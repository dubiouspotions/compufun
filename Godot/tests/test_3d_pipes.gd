extends "res://tests/test.gd"
## 3D Pipes: a pipe grows in a 3D grid, the picture dissolves to black once the grid holds
## full_segments and the pipes start over, and a key press ends the saver.


func run() -> void:
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var saver: Control = load("res://win95/savers/3d_pipes.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	saver.set("full_segments", 30)
	saver.set("pipe_length", Vector2i(5, 10))
	screen.add_child(saver)
	await create_timer(2.0).timeout
	var grown: int = saver.call(&"segment_count")
	check("a pipe grows at segments_per_second", grown >= 20 and grown <= 25, true)
	var meshes := saver.find_children("*", "MeshInstance3D", true, false).size()
	check("each segment is a 3D pipe or elbow", meshes >= grown, true)
	var before := grown
	var dropped := false
	while not dropped and now() < 10.0:
		await process_frame
		var count: int = saver.call(&"segment_count")
		dropped = count < before
		before = count
	check("once full, the picture dissolves and the pipes start over", dropped, true)
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	saver.call(&"_gui_input", key)
	await process_frame
	check("a key ends it", is_instance_valid(saver), false)
	screen.queue_free()

extends "res://tests/test.gd"
## The Flying Through Space screensaver draws every frame for seconds without errors.
## test_saver_registry.gd checks that it covers the screen and that a key ends it.


func run() -> void:
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var saver: Control = load("res://win95/savers/flying_through_space.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)
	var draws := [0]
	saver.draw.connect(func() -> void: draws[0] += 1)
	for i in 3 * FPS:
		await process_frame
	check("draws every frame", draws[0] >= 3 * FPS - 2, true)
	screen.queue_free()

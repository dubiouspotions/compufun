extends "res://tests/test.gd"
## A screensaver (Saver) hides the Win95 pointer while it plays and ends when the mouse moves past
## its jitter; a plain cover screen keeps the pointer and ignores the mouse moving.


func run() -> void:
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	var job := Job.new(load("res://customers/skater_bro.tres"), load("res://problems/dust_overheat.tres"), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	(win95.get("_boot") as Node).finished.emit()
	check("the desktop shows the pointer", bench.call("pointer_visible"), true)
	var changes := [0]
	bench.connect(&"pointer_changed", func() -> void: changes[0] += 1)

	var saver: Control = load("res://win95/savers/blank_screen.gd").new()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	win95.add_child(saver)
	await process_frame
	check("a saver hides the pointer", [bench.call("pointer_visible"), changes[0] > 0], [false, true])
	win95.set("pointer_visible", true)
	check("setting the pointer doesn't show it over a saver", win95.get("pointer_visible"), false)
	saver._gui_input(_move(Vector2(300, 200), Vector2(3, 0)))
	saver._gui_input(_move(Vector2(299, 202), Vector2(-1, 2)))
	await process_frame
	check("jitter leaves it playing", is_instance_valid(saver), true)
	saver._gui_input(_move(Vector2(305, 200), Vector2(6, -2)))
	await process_frame
	await process_frame
	check("a mouse move ends it", is_instance_valid(saver), false)
	check("and the pointer is back", bench.call("pointer_visible"), true)

	var cover: Control = load("res://win95/cover_screen.gd").new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	win95.add_child(cover)
	await process_frame
	cover._gui_input(_move(Vector2(400, 300), Vector2(100, 100)))
	await process_frame
	check("a cover screen keeps the pointer and ignores a mouse move", [bench.call("pointer_visible"), is_instance_valid(cover)], [true, true])
	cover.queue_free()
	bench.queue_free()


func _move(at: Vector2, by: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.relative = by
	return motion

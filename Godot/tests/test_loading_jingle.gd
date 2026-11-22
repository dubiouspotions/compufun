extends "res://tests/test.gd"
## The loading screen plays the CompuFun jingle from its first frame, as the logo starts to draw in,
## and draws the logo in for at least as long as the jingle's tune.


func run() -> void:
	var screen: CanvasLayer = (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var jingle: AudioStreamPlayer = screen.get_node("%Jingle")
	check("the jingle plays from the first frame", [jingle.stream != null, jingle.playing], [true, true])
	check("the logo draws in for the jingle's tune", screen.get("min_seconds") >= 2.0, true)
	# The game loads on a thread; let it finish before the screen goes, so no load is left running.
	var end := Time.get_ticks_msec() + 60000
	while ResourceLoader.load_threaded_get_status("res://main.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < end:
		await process_frame
	screen.set_process(false)
	ResourceLoader.load_threaded_get("res://main.tscn")
	screen.queue_free()
	await process_frame

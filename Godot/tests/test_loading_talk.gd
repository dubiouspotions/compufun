extends "res://tests/test.gd"
## The loading screen holds the game's talk (a talk_held property, as main.tscn has) from the moment
## the game comes in under the logo until the zoom has run talk_at_zoom of its time.


func run() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar talk_held: bool = false\n"
	if script.reload() != OK:
		check("the stand-in game's script compiles", false, true)
		return
	var stand_in := Node.new()
	stand_in.set_script(script)
	var packed := PackedScene.new()
	packed.pack(stand_in)
	var screen: CanvasLayer = (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	screen.set(&"game_scene", "res://props/wall_shelf.tscn")  # loads on a thread at once; the test reveals its own
	root.add_child(screen)
	screen.set_process(false)
	while ResourceLoader.load_threaded_get_status("res://props/wall_shelf.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame  # a quit while the load runs crashes Godot (docs/gotchas.md)
	ResourceLoader.load_threaded_get("res://props/wall_shelf.tscn")
	var logo: Control = screen.get_node("%Logo")
	screen.call(&"_reveal", packed)
	var game_node: Node = current_scene
	check("the game comes in with its talk held", game_node.get(&"talk_held"), true)
	var fade_from := -1.0
	var released := -1.0
	for i in 60 * 20:
		await process_frame
		if fade_from < 0.0 and logo.modulate.a < 1.0:
			fade_from = now()
		if game_node.get(&"talk_held") == false:
			released = now()
			break
	var expected: float = float(screen.get(&"zoom_after_seconds")) + float(screen.get(&"zoom_seconds")) * float(screen.get(&"talk_at_zoom"))
	check("held through the fade, let go part way into the zoom", [fade_from >= 0.0, released >= 0.0, absf(released - fade_from - expected) < 0.1], [true, true, true])
	game_node.queue_free()
	await process_frame

extends "res://tests/test.gd"
## The finale, with short timings: the world stands still, error boxes pile up, every thing in the
## world turns into the bluescreen, the whole window bluescreens, the chosen computer restarts and
## fails, and the credits show every person. A skip ends a stage at once. A focused text field (the
## F9 note) still gets its keys, and closing a tool that unpaused the tree does not let the world run.
## A browser's user agent names the computer.

const TIMINGS: Array[String] = ["flicker_seconds", "wave_seconds", "bluescreen_seconds", "off_seconds",
	"stuck_seconds", "repair_seconds", "error_seconds", "credits_fade_seconds"]


func run() -> void:
	_check_user_agents()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var finale: CanvasLayer = load("res://finale/finale.tscn").instantiate()
	for timing: String in TIMINGS:
		finale.set(timing, 0.3)
	finale.set("boxes_seconds", 61.0)  # all through the minute-long wave below
	finale.set("settle_seconds", 0.1)
	finale.set("box_every_first", 0.02)
	finale.set("box_every_last", 0.02)
	finale.set("wave_seconds", 60.0)
	finale.set("host", 2)  # Finale.HostChoice.MACOS
	main.add_child(finale)
	check("before it plays, no stage", finale.call("stage"), &"")
	finale.call("play")
	check("it plays, from the Main view", [finale.call("is_playing"), game.view], [true, &"Main"])
	await create_timer(0.5).timeout
	check("the world stands still once the view has turned", paused, true)
	paused = false  # as F9 or the Voice Lab do when they close
	await process_frame
	await process_frame
	check("and stays still when a tool unpauses it", paused, true)
	var note := LineEdit.new()
	note.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(note)
	note.grab_focus()
	_press_key(KEY_A, "a")
	check("a focused text field still gets its keys", note.text, "a")
	note.queue_free()
	var boxes: SubViewport = finale.get_node("%BoxBuffer")
	check("error boxes pile up", boxes.get_child_count() > 5, true)
	_press(&"skip_ahead")
	check("a skip ends the minute-long wave: the window bluescreens", await _until(finale, &"bluescreen", 2.0), true)
	check("the game stands still", paused, true)
	_check_world_is_blue(main, finale)
	check("the computer restarts", await _until(finale, &"restart", 3.0), true)
	var boot: Control = finale.get_node("%Boot")
	check("as the Mac that was chosen", boot.get("host"), HostBoot.Host.MACOS)
	var failed := false
	var end := now() + 4.0
	while not failed and now() < end:
		failed = boot.call("stage") == HostBoot.Stage.FAILED
		await process_frame
	check("it fails with its error", failed, true)
	var error_shown := now()
	check("the credits come after the error", await _until(finale, &"credits", 4.0), true)
	check("the error stays its error_seconds", now() - error_shown >= finale.get("error_seconds"), true)
	var people: Array = finale.call("cast")
	var starring := _card_texts(finale.get_node("%Cast"), "%Actor")
	var also := _card_texts(finale.get_node("%Also"), "%Role")
	check("the credits show every person with a portrait", [people.size() > 3, starring.size() + also.size()], [true, people.size()])
	check("actors star by their real name, the others are also starring by their nickname",
			people.all(func(person: Person) -> bool: return starring.has(person.actor) if person.actor != "" else also.has(person.nickname)), true)
	check("some actors star", starring.is_empty(), false)
	check("the credits thank the player", (finale.get_node("%Thanks") as Label).text, (finale.get("text") as FinaleText).thanks)
	_press_key(KEY_SPACE, " ")
	check("a key while the credits fade in does not end them", [finale.call("stage"), finale.call("is_playing")], [&"credits", true])
	paused = false
	main.queue_free()
	await process_frame


func _check_user_agents() -> void:
	var agents := {
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36": HostBoot.Host.WINDOWS,
		"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15": HostBoot.Host.MACOS,
		"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148": HostBoot.Host.MACOS,
		"Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0": HostBoot.Host.LINUX,
		"Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Mobile Safari/537.36": HostBoot.Host.LINUX,
		"Mozilla/5.0 (PlayStation; PlayStation 5/2.26) AppleWebKit/605.1.15 (KHTML, like Gecko)": HostBoot.Host.CAMBION,
	}
	for agent: String in agents:
		check("the user agent %s..." % agent.substr(0, 40), HostBoot.from_user_agent(agent), agents[agent])


# Every visible mesh in the world wears the bluescreen once the window has bluescreened.
func _check_world_is_blue(main: Node, finale: CanvasLayer) -> void:
	var world: SubViewport = main.get_node("World").get_child(0)
	var meshes := world.find_children("*", "MeshInstance3D", true, false).filter(
			func(mesh: MeshInstance3D) -> bool: return mesh.is_visible_in_tree())
	var blue := meshes.filter(func(mesh: MeshInstance3D) -> bool: return finale.call("is_blue", mesh))
	check("every visible mesh in the world is a bluescreen", [meshes.size() > 20, blue.size()], [true, meshes.size()])
	var sign: Node3D = world.find_child("OpenSign", true, false)
	var board: MeshInstance3D = sign.get_node("%Board")
	check("the open sign keeps its own material for its script", board.material_override is ShaderMaterial, true)


func _card_texts(box: Node, label: String) -> Array[String]:
	var texts: Array[String] = []
	for row: Node in box.get_children():
		for card: Node in row.get_children():
			texts.append((card.get_node(label) as Label).text)
	return texts


func _until(finale: CanvasLayer, stage: StringName, seconds: float) -> bool:
	var end := now() + seconds
	while now() < end:
		if finale.call("stage") == stage:
			return true
		await process_frame
	return finale.call("stage") == stage


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _press_key(key: Key, typed: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.unicode = typed.unicode_at(0)
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

extends "res://tests/test.gd"
## The player, inside, reads the side that faces in: OPEN while the shop is closed and CLOSED while
## it is open. The Open sign takes clicks and pulses an outline only while the shop can open or close, turns
## over on its strings with its flip sound, and the close question comes in the game's panel before
## day 4's warp and in a Win95 message box from it on; a change of view answers No.

var _seen_flips: Dictionary = {}


func run() -> void:
	var sign: Node3D = (load("res://props/open_sign.tscn") as PackedScene).instantiate()
	root.add_child(sign)
	var end_of_day: Control = (load("res://ui/end_of_day.tscn") as PackedScene).instantiate()
	root.add_child(end_of_day)
	await process_frame
	var hotspot: Area3D = sign.get_node("%Hotspot")
	var outline: Node3D = sign.get_node("%Outline")
	var day_1: Day = game.day_of(1)
	var asked := [0]
	var opened := [0]
	sign.connect("close_requested", func() -> void: asked[0] += 1)
	sign.connect("open_requested", func() -> void: opened[0] += 1)

	check("restore day 1, closed in the morning", game.restore({"day": 1, "phase": "CLOSED"}), "")
	check("openable: clicks and the outline", [game.can_open(), hotspot.input_ray_pickable, outline.visible], [true, true, true])
	var board: MeshInstance3D = sign.get_node("%Board")
	var shown := func() -> Texture2D: return (board.material_override as ShaderMaterial).get_shader_parameter("albedo_texture")
	check("closed in the morning, the player reads OPEN", shown.call() == sign.get("open_texture"), true)
	hotspot.emit_signal("clicked", hotspot)
	check("a click asks to open, not to close", [opened[0], asked[0]], [1, 0])
	check("no flip before it turns", _flips(sign), 0)
	game.open_shop()
	check("opening turns it over with a flip", _flips(sign), 1)
	var turn: float = sign.get("flip_seconds")
	check("it still shows OPEN as it starts to turn", shown.call() == sign.get("open_texture"), true)
	var widest := 0.0
	var until := now() + turn + 0.2
	while now() < until:
		await process_frame
		widest = maxf(widest, absf(sign.rotation.y))
	check("it turns on its strings, near edge-on", widest > 0.8, true)
	check("it ends turned back, showing CLOSED to the player", [is_zero_approx(sign.rotation.y), shown.call() == sign.get("closed_texture")], [true, true])
	check("restore day 1, open", game.restore({"day": 1, "phase": "OPEN"}), "")
	check("no flip while it stays open", _flips(sign), 1)

	check("restore day 1, one customer still to come", game.restore({"day": 1, "arrivals": day_1.codes().size() - 1}), "")
	check("before the last customer: no clicks, no outline", [game.can_close(), hotspot.input_ray_pickable, outline.visible], [false, false, false])
	check("restore day 1, every customer came and left", game.restore({"day": 1, "arrivals": day_1.codes().size()}), "")
	check("closable: clicks and the outline", [game.can_close(), hotspot.input_ray_pickable, outline.visible], [true, true, true])
	hotspot.emit_signal("clicked", hotspot)
	check("a click asks to close", asked[0], 1)

	var panel: Control = end_of_day.get_node("%Panel")
	var win95: Control = end_of_day.get_node("%Dialog")
	end_of_day.call("ask")
	check("day 1 asks in the panel", [panel.visible, win95.visible], [true, false])
	(end_of_day.get_node("%No") as Button).pressed.emit()
	check("No leaves the shop open", [panel.visible, game.phase], [false, game.Phase.OPEN])
	game.go_to_view(&"Right")
	end_of_day.call("ask")
	game.go_to_view(&"Main")
	check("turning away answers No", [panel.visible, game.phase], [false, game.Phase.OPEN])
	game.close_shop()
	check("closing turns it over with a flip", _flips(sign), 2)
	await create_timer(turn + 0.2).timeout
	check("closed for the night, the player reads OPEN", shown.call() == sign.get("open_texture"), true)
	game.start_day(game.day_of(2))
	check("the next morning it stays turned: no flip", [game.phase, _flips(sign)], [game.Phase.CLOSED, 2])
	var day_4: Day = game.day_of(4)
	check("restore day 4", game.restore({"day": 4, "arrivals": day_4.codes().size()}), "")
	end_of_day.call("ask")
	check("day 4 asks in a Win95 message box", [panel.visible, win95.visible], [false, true])
	game.go_to_view(&"Right")
	check("leaving the view closes the message box too", [win95.visible, game.phase], [false, game.Phase.OPEN])
	sign.queue_free()
	end_of_day.queue_free()
	await process_frame


# Each flip leaves a player of the flip sound on the sign while it plays; the count keeps every one seen.
func _flips(sign: Node3D) -> int:
	var flip: SoundSet = sign.get("flip_sound")
	for n: Node in sign.get_children():
		if n is AudioStreamPlayer3D and n.stream in flip.sounds:
			_seen_flips[n.get_instance_id()] = true
	return _seen_flips.size()

extends "res://tests/test.gd"
## The post-it in the Workview: a click brings it up close in front of the camera, and it goes back
## onto the computer when closed or when the player turns away.

var _shop: Node3D
var _camera: Camera3D


func run() -> void:
	_shop = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(_shop)
	await process_frame
	check("restore a job in focus in the Workview", game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
		"problem": "dust_overheat", "slot": 0}], "focus_slot": 0, "connected_slot": -1, "view": "Workview"}), "")
	await create_timer(1.0).timeout  # the camera reaches the Workview
	_camera = _shop.get_node("%Camera")
	var post_it: Node3D = _shop.pinned_post_it()
	var rest := post_it.global_position
	var paper: Rect2 = _shop.post_it_rect(post_it)

	_click(paper.get_center())
	check("a click on the post-it brings it up close", _shop.reading_post_it(), true)
	await create_timer(_shop.post_it_read_seconds + 0.2).timeout
	var marker: Node3D = _shop.view_marker(&"Workview")
	check("it stops in front of the camera", post_it.global_position.distance_to(
		marker.global_transform.translated_local(Vector3(0, 0, -_shop.post_it_read_distance)).origin) < 0.001, true)
	check("it fills much of the view", _shop.post_it_rect(post_it).size.y > _camera.get_viewport().get_visible_rect().size.y * 0.5, true)

	_shop.close_post_it()
	check("closing ends the reading at once", _shop.reading_post_it(), false)
	await create_timer(_shop.post_it_read_seconds + 0.2).timeout
	check("it goes back onto the computer", post_it.global_position.distance_to(rest) < 0.001, true)

	_click(paper.get_center())
	check("a second click brings it up close again", _shop.reading_post_it(), true)
	game.go_to_view(&"Main")
	check("turning away puts it back", _shop.reading_post_it(), false)
	await create_timer(_shop.post_it_read_seconds + 0.2).timeout
	check("on the computer again", post_it.global_position.distance_to(rest) < 0.001, true)
	_shop.queue_free()


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = root.get_final_transform() * at
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()

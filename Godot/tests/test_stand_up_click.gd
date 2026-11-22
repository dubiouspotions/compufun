extends "res://tests/test.gd"
## In the Workview, a click on empty space beside the lying computer stands it up, as a click on the
## screwdriver's outline does, once the side panel is on with both screws in; with a screw out it
## does nothing.

var _shop: Node3D
var _camera: Camera3D


func run() -> void:
	_shop = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(_shop)
	await process_frame
	check("restore a lying, closed job in focus in the Workview", game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
		"problem": "dust_overheat", "slot": 0, "lying": true}], "focus_slot": 0, "connected_slot": -1, "view": "Workview"}), "")
	await create_timer(1.0).timeout  # the camera reaches the Workview
	_camera = _shop.get_node("%Camera")
	var job: Job = game.jobs[0]
	var empty := _empty_spot()
	check("the Workview has empty space beside the computer", empty != Vector2(-1, -1), true)

	_click(empty)
	check("a click on empty space stands the closed computer up", job.lying, false)

	game.lay_down(job)
	game.turn_screw(job, 0)
	await create_timer(1.0).timeout
	empty = _empty_spot()
	_click(empty)
	check("with a screw out, a click on empty space leaves it lying", [job.lying, job.panel_screws], [true, [false, true]])
	_shop.queue_free()


# The first point, from the top of the view, that is off every computer and has nothing clickable.
func _empty_spot() -> Vector2:
	var view := _camera.get_viewport().get_visible_rect().size
	var slots: Node = _shop.get_node("%JobSlots")
	for y: int in range(4, int(view.y * 0.5), 8):
		for x: int in range(4, int(view.x), 8):
			var at := Vector2(x, y)
			if _shop.hotspot_at(at) == null and slots.job_at(_camera.project_ray_origin(at), _camera.project_ray_normal(at)) == null:
				return at
	return Vector2(-1, -1)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = root.get_final_transform() * at
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()

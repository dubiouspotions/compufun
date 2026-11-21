extends "res://tests/test.gd"
## The VGA cable's plug in the shop's Main view: a click takes it and the next click puts it down or
## plugs it in, and a press-drag-release still plugs it in where it is released.

var _shop: Node3D
var _bench: Node3D
var _camera: Camera3D


func run() -> void:
	root.physics_object_picking = false  # the test emits plug_grabbed itself, as picking would on the press
	_shop = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(_shop)
	await process_frame
	check("restore a job in slot 0, unplugged", game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
		"problem": "dust_overheat", "slot": 0}], "connected_slot": -1, "view": "Main"}), "")
	await process_frame
	_bench = _shop.find_child("Bench", true, false)
	_camera = _shop.get_node("%Camera")
	var plug := _px(_bench.get_node("%Plug/Body").global_position)
	var computer := _px(_shop.find_child("Slot0", true, false).find_child("Hotspot", true, false).global_position)
	var empty := plug + Vector2(0.0, -40.0)  # above the counter, beside the computer
	check("the empty spot is off every computer", _shop.get_node("%JobSlots").job_at(_camera.project_ray_origin(empty), _camera.project_ray_normal(empty)), null)

	_grab(plug)
	_button(plug, false)
	check("a click on the plug keeps it in the hand", [_bench.dragging, game.connected], [true, null])
	_move(computer)
	check("the carried plug outlines the computer under it", _shop.find_child("Slot0", true, false).find_child("Outline", true, false).visible, true)
	_button(computer, true)
	check("the next click on a computer plugs the plug in", [_bench.dragging, game.connected], [false, game.jobs[0]])
	_button(computer, false)
	check("its release leaves the plug in", [_bench.dragging, game.connected], [false, game.jobs[0]])

	_grab(computer)
	_button(computer, false)
	_move(empty)
	_button(empty, true)
	_button(empty, false)
	check("a click off the computers lays the carried plug down", [_bench.dragging, game.connected], [false, null])

	_grab(plug)
	_move(computer)
	_button(computer, false)
	check("a drag onto a computer plugs it in on the release", [_bench.dragging, game.connected], [false, game.jobs[0]])

	_button(plug, true)
	_button(plug, false)
	_bench.plug_grabbed.emit()  # a quick tap: the release came before picking reported the press
	check("a quick tap keeps the plug in the hand", [_bench.dragging, game.connected], [true, null])
	game.go_to_view(&"Left")
	check("a turn lays the carried plug down", _bench.dragging, false)
	_shop.queue_free()


# A press on the plug at [param at], as physics picking reports it.
func _grab(at: Vector2) -> void:
	_button(at, true)
	_bench.plug_grabbed.emit()


# Through Input, so that Input.is_mouse_button_pressed follows the button.
func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_send(event, at)


func _move(to: Vector2) -> void:
	_send(InputEventMouseMotion.new(), to)


func _send(event: InputEventMouse, at: Vector2) -> void:
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _px(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)

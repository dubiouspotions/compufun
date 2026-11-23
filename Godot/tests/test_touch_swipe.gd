extends "res://tests/test.gd"
## A finger's swipe across the world turns the view like a panorama (a finger that moves left turns
## right), and a swipe down leaves a close-up. A mouse drag of the same shape, a slow drag, a drag that
## starts on a button, and a drag of the plug or of the part in the hand don't swipe. A finger taps a
## hotspot and the back strip on the lift, a swipe that starts on one doesn't click it, and a mouse
## clicks it on the press.

var _main: Node
var _shop: Node
var _world: SubViewportContainer
var _camera: Camera3D


func run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	_shop = _main.get_node("%Shop")
	_world = _main.get_node("World")
	_camera = _shop.get_node("%Camera")
	var main_view: ViewMarker = _shop.view_marker(&"Main")
	var left_view: ViewMarker = _shop.view_marker(&"Left")

	await _go(&"Main")
	await _swipe(Vector2(1300, 500), Vector2(600, 520), true)
	check("a finger that moves left turns right", game.view, main_view.right)
	await _go(&"Main")
	await _swipe(Vector2(600, 500), Vector2(1300, 480), true)
	check("a finger that moves right turns left", game.view, main_view.left)
	await _go(&"Main")
	await _swipe(Vector2(1300, 500), Vector2(600, 520), false)
	check("a mouse drag turns nothing", game.view, &"Main")
	await _swipe(Vector2(1300, 500), Vector2(600, 520), true, 1.0)
	check("a slow drag turns nothing", game.view, &"Main")
	var left_button: Button = _main.get_node("%ViewNav").get_node("%LeftButton")
	await _swipe(left_button.get_global_rect().get_center(), left_button.get_global_rect().get_center() + Vector2(700, 0), true)
	check("a drag that starts on a button turns nothing", game.view, &"Main")
	await _go(&"Storage")
	await _swipe(Vector2(960, 300), Vector2(980, 800), true)
	check("a swipe down leaves a close-up", game.view, &"Left")

	await _go(&"Left")
	var door: Hotspot = _shop.find_child("StorageDoor", true, false)
	var on_door := _on(func(at: Vector2) -> bool: return _shop.hotspot_at(at) == door)
	check("the storage door shows in the Left View", on_door != Vector2.INF, true)
	_finger(on_door, true)
	await _frames(3)
	check("a finger's touch on a hotspot doesn't click it yet", game.view, &"Left")
	_finger(on_door, false)
	await _frames(3)
	check("its lift clicks it", game.view, &"Storage")

	await _go(&"Left")
	await _swipe(on_door, Vector2(maxf(on_door.x - 700.0, 20.0), on_door.y), true)
	check("a swipe that starts on a hotspot turns and doesn't click it", game.view, left_view.right)

	await _go(&"Left")
	_mouse_button(on_door, true)
	await _frames(3)
	check("a mouse clicks a hotspot on the press", game.view, &"Storage")
	_mouse_button(on_door, false)
	await _frames(1)

	await _go(&"Storage")
	var on_strip := _on(func(at: Vector2) -> bool: return _shop.call("_back_strip_at", at))
	check("the Storage View has a back strip", on_strip != Vector2.INF, true)
	_finger(on_strip, true)
	await _frames(3)
	check("a finger's touch on the back strip doesn't go back yet", game.view, &"Storage")
	_finger(on_strip, false)
	await _frames(3)
	check("its lift goes back", game.view, &"Left")

	await _check_drags()
	_main.queue_free()


# A finger drags the plug onto a computer and the part out of the hand, and neither turns the view.
func _check_drags() -> void:
	check("restore a job in slot 0, unplugged, RAM in the hand", game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
		"problem": "dust_overheat", "slot": 0}], "connected_slot": -1, "view": "Main", "hand": ["ram"]}), "")
	await _frames(60)
	var bench: Node = _shop.find_child("Bench", true, false)
	var plug := _ui(_camera.unproject_position(bench.get_node("%Plug/Body").global_position))
	var computer := _ui(_camera.unproject_position(_shop.find_child("Slot0", true, false).find_child("Hotspot", true, false).global_position))
	await _swipe(plug, Vector2(maxf(plug.x - 700.0, 20.0), plug.y), true)
	check("a finger's drag of the plug in a swipe's shape lays it down, and the view stays", [game.connected, game.view], [null, &"Main"])
	await _swipe(plug, computer, true)
	check("a finger drags the plug onto a computer, and the view stays", [game.connected, game.view], [game.jobs[0], &"Main"])

	var hand: Node3D = _shop.get_node("%Hand")
	var on_part := _on(func(at: Vector2) -> bool: return hand.call("covers", at))
	check("the part in the hand shows", on_part != Vector2.INF, true)
	await _swipe(on_part, on_part + Vector2(-700, 0), true)
	await _frames(3)
	check("a finger drags the part out of the hand, and the view stays", [game.hand != null, game.view], [true, &"Main"])


func _go(view: StringName) -> void:
	game.go_to_view(view)
	await create_timer(1.0).timeout  # the camera gets there


# A drag from [param from] to [param to], in pixels of the UI, over [param seconds]: a finger's touch,
# drags and lift (Godot makes the mouse events), or a mouse's.
func _swipe(from: Vector2, to: Vector2, finger: bool, seconds: float = 0.1) -> void:
	if finger:
		_finger(from, true)
	else:
		_mouse_button(from, true)
	await _frames(1)
	var steps := maxi(4, int(seconds * FPS))
	for i: int in range(1, steps + 1):
		var at := from.lerp(to, i / float(steps))
		if finger:
			var drag := InputEventScreenDrag.new()
			drag.position = _window(at)
			drag.relative = _window(at) - _window(from.lerp(to, (i - 1) / float(steps)))
			_send(drag)
		else:
			var motion := InputEventMouseMotion.new()
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			motion.position = _window(at)
			motion.global_position = motion.position
			_send(motion)
		await _frames(1)
	if finger:
		_finger(to, false)
	else:
		_mouse_button(to, false)
	await _frames(3)


func _finger(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = down
	touch.position = _window(at)
	_send(touch)


func _mouse_button(at: Vector2, down: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = down
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	button.position = _window(at)
	button.global_position = button.position
	_send(button)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame


# The point in the middle of the world-buffer pixels where [param hit] holds, in pixels of the UI; INF
# for none.
func _on(hit: Callable) -> Vector2:
	var size := Vector2(_world.get_child(0).size)
	var points: Array[Vector2] = []
	for y: int in range(2, int(size.y), 3):
		for x: int in range(2, int(size.x), 3):
			if hit.call(Vector2(x, y)):
				points.append(Vector2(x, y))
	if points.is_empty():
		return Vector2.INF
	var middle := Vector2.ZERO
	for point: Vector2 in points:
		middle += point
	middle /= points.size()
	var nearest := points[0]
	for point: Vector2 in points:
		if point.distance_to(middle) < nearest.distance_to(middle):
			nearest = point
	return _ui(nearest)


func _ui(world_px: Vector2) -> Vector2:
	return _world.get_global_transform() * (world_px * _world.stretch_shrink)


func _window(ui: Vector2) -> Vector2:
	return root.get_final_transform() * ui

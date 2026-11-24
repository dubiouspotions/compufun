extends "res://tests/test.gd"
## The corruption sign customer_x floats its [x] over the right side of its target customer's head (the
## young entrepreneur) wherever the camera sees him, also as he walks in, and only while
## sign_customer_x is set; never over the dialogue portrait. A click sends him away for good.

const GAME := preload("res://game.gd")

var _shop: Node3D  # untyped: Shop names Game
var _world: SubViewportContainer
var _close: Button
var _offset: Vector2


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set(&"talk_held", true)  # no conversation: the test ends it
	await _frames(5)
	_shop = main.find_child("Shop", true, false)
	_world = main.get_node(^"World")
	var sign: Node = main.find_child("CustomerX", true, false)
	check("the sign is in the shop", sign != null and _shop.is_ancestor_of(sign), true)
	var entrepreneur: Customer = load("res://customers/young_entrepreneur.tres")
	var skater: Customer = load("res://customers/skater_bro.tres")
	var dust: Problem = load("res://problems/dust_overheat.tres")
	check("its target is the young entrepreneur", sign.get("target"), entrepreneur)
	_close = sign.get_node("%Close")
	_offset = sign.get(&"offset")

	game.set_flag(&"sign_customer_x")
	game.start_day(make_day(6, [[skater, dust], [entrepreneur, dust]]))
	game.open_shop()
	var skater_walk := await _walk_in()
	check("not over another customer", skater_walk.has(true), false)
	game.dialogue_finished()
	while game.visitor_state != GAME.VisitorState.NONE:
		await process_frame
	tick(61.0)
	check("the target walks in", [game.visitor, game.visitor_state], [entrepreneur, GAME.VisitorState.WALKING_IN])
	var walk := await _walk_in()
	check("over him for part of the walk in", walk.has(true), true)
	check("over him while he talks", [game.visitor_state, _close.visible], [GAME.VisitorState.TALKING, true])
	check("in the UI layer, not on the dialogue portrait", [_close.get_parent().name, main.get_node(^"%DialogueOverlay").is_ancestor_of(_close)], [&"UI", false])
	game.set_flag(&"sign_customer_x", 0)
	check("not without the flag", _close.visible, false)
	game.set_flag(&"sign_customer_x")
	check("back with the flag", _close.visible, true)
	_close.pressed.emit()
	check("a click sends him away for good", [game.visitor, game.is_gone(entrepreneur), game.flag(&"gone_young_entrepreneur"), game.jobs.size()], [null, true, 1, 1])
	await process_frame
	check("gone with him", _close.visible, false)
	main.queue_free()
	await _frames(2)


# Plays the visitor's walk in to the counter; for each frame, whether the [x] showed. Checks that it
# showed above and right of the head, and only over the target while the camera saw his head. The
# [x] follows a frame late, so the frame where the head appears or hides doesn't count.
func _walk_in() -> Array[bool]:
	var shown: Array[bool] = []
	var misplaced := 0
	var mismatched := 0
	var was_expected := false
	var target: Customer = load("res://customers/young_entrepreneur.tres")
	while game.visitor_state == GAME.VisitorState.WALKING_IN:
		await process_frame
		shown.append(_close.visible)
		var head: Vector2 = _shop.call(&"visitor_head_point", Vector2.ZERO)
		var at: Vector2 = _shop.call(&"visitor_head_point", _offset)
		var expected: bool = game.visitor == target and at.is_finite() and Rect2(Vector2.ZERO, (_shop.get_viewport() as Viewport).get_visible_rect().size).has_point(at)
		if expected == was_expected and _close.visible != expected:
			mismatched += 1
		was_expected = expected
		var middle := _close.position + _close.size * _close.scale * 0.5
		var head_ui := _world.get_global_transform() * (head * float(_world.stretch_shrink))
		if _close.visible and head.is_finite() and not (middle.x > head_ui.x and middle.y < head_ui.y):
			misplaced += 1
	check("above and right of the head", misplaced, 0)
	check("shown while the camera sees his head", mismatched, 0)
	return shown


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

extends "res://tests/test.gd"
## A restore while a visitor walks in stops the shop's walk, so its end doesn't reach Game.

const GAME := preload("res://game.gd")
const WALK_SECONDS: float = 0.2

var _errors := Errors.new()


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	shop.walk_seconds = WALK_SECONDS
	root.add_child(shop)
	await process_frame
	OS.add_logger(_errors)
	var day: Day = (load("res://days/day_1.tres") as Day).duplicate()
	day.first_wait_seconds = Vector2.ZERO

	game.start_day(day)
	await create_timer(WALK_SECONDS * 3.0).timeout
	check("without a restore, the visitor reaches the counter", game.visitor_state, GAME.VisitorState.TALKING)

	game.start_day(day)
	check("the next visitor walks in", game.visitor_state, GAME.VisitorState.WALKING_IN)
	check("restore to an empty shop", game.restore({"day": 1, "arrivals": 1}), "")
	await create_timer(WALK_SECONDS * 3.0).timeout
	check("the shop stays empty", game.visitor_state, GAME.VisitorState.NONE)
	check("Game errors after the restore", _errors.messages.filter(func(m: String) -> bool: return m.begins_with("Game.")), [])
	OS.remove_logger(_errors)


class Errors extends Logger:
	var messages: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append(rationale if rationale != "" else code)

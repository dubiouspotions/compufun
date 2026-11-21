class_name Crash
extends Control
## The bluescreen over the whole window at the end (Game.Phase.ENDED), at a whole-number scale of
## its 640 x 480. While it shows, the game stands still (the tree pauses); any key or click reboots
## it on day 1 (Game.reboot).

var _shown: bool = false


func _ready() -> void:
	_show(false)
	Game.changed.connect(_sync)


## Shows the bluescreen; does nothing unless the game has ended.
func show_crash() -> void:
	_show(Game.phase == Game.Phase.ENDED)


func _sync() -> void:
	if Game.phase != Game.Phase.ENDED:
		_show(false)


func _show(on: bool) -> void:
	if on == _shown and visible == on:
		return
	_shown = on
	visible = on
	get_tree().paused = on


func _input(event: InputEvent) -> void:
	if not _shown or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		Game.reboot()

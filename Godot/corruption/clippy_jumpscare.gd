extends CorruptionSign
## A jump scare, armed at stage 1: the next time the player enters the Storage view, the lights go
## out, a life-size Clippy flashes up in the dark for a blink or two, and the lights come back
## without him. Then stage 2, done. A player who leaves the Storage view before the lights go out
## keeps it armed; one who leaves in the dark ends it.

const STORAGE_VIEW: StringName = &"Storage"

## The seconds between entering the Storage view and the lights going out: the camera's turn.
@export var arrive_seconds: float = 0.6
## The seconds of dark before the first flash.
@export var dark_seconds: float = 0.8
## The times that Clippy flashes up.
@export var flashes: int = 2
## The seconds that each flash shows Clippy.
@export var flash_seconds: float = 0.1
## The seconds of dark between two flashes.
@export var between_seconds: float = 0.15
## The seconds of dark after the last flash, before the lights come back.
@export var after_seconds: float = 0.7

var _scare: Tween
var _dark: bool = false

@onready var _clippy: Node3D = %Clippy
@onready var _lights_out: CanvasItem = %LightsOut


func _ready() -> void:
	var room := get_tree().get_first_node_in_group(&"storage_room") as Node3D
	if room == null:
		push_error("clippy_jumpscare: no Node3D in the group storage_room")
	else:
		_clippy.global_transform = room.global_transform * _clippy.transform  # his scene transform is in the room's space
	super()


func _apply(shown_stage: int) -> void:
	var running := _scare != null and _scare.is_running()
	if shown_stage != 1:
		_stop()
		return
	if running and Game.view != STORAGE_VIEW:
		var seen := _dark
		_stop()
		if seen:
			set_stage.call_deferred(2)
	elif not running and Game.view == STORAGE_VIEW:
		_start()


func _start() -> void:
	_scare = create_tween()
	_scare.tween_interval(arrive_seconds)
	_scare.tween_callback(_show.bind(true, false))
	_scare.tween_interval(dark_seconds)
	for flash: int in flashes:
		if flash > 0:
			_scare.tween_interval(between_seconds)
		_scare.tween_callback(_show.bind(false, true))
		_scare.tween_interval(flash_seconds)
		_scare.tween_callback(_show.bind(true, false))
	_scare.tween_interval(after_seconds)
	_scare.tween_callback(_finish)


func _finish() -> void:
	_scare = null  # done: the stage change below must not kill the tween that calls this
	_show(false, false)
	set_stage(2)


func _stop() -> void:
	if _scare != null:
		_scare.kill()
	_show(false, false)


func _show(dark: bool, clippy: bool) -> void:
	_dark = dark or clippy
	_lights_out.visible = dark
	_clippy.visible = clippy

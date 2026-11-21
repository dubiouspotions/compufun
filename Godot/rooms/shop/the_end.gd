class_name TheEnd
extends Node3D
## The end of the game in the shop (Game.Phase.ENDED): a calm moment in the evening, then the
## camera shakes with a rumble and the player looks down at their own body, a Pipedream pipe through
## the chest. Then the world crashes into the bluescreen. The body, the pipe and the blood are the
## children of Body, in world space, so move them in the editor.

## The camera wants to go to [param view]: the view that looks down at the body.
signal view_requested(view: StringName)
## The player has looked at the body for long enough: time for the bluescreen.
signal crashed

## The view marker that looks down at the body.
@export var end_view: StringName = &"End"
## The calm moment in the evening before the shake, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var calm_seconds: float = 1.5
@export_range(0.0, 10.0, 0.1, "suffix:s") var shake_seconds: float = 1.5
## How far the camera shakes at first; it calms down to nothing.
@export_range(0.0, 0.5, 0.005, "suffix:m") var shake_metres: float = 0.05
@export_range(1.0, 60.0, 0.5) var shakes_per_second: float = 14.0
## From the start of the look down to the bluescreen, in seconds, the turn of the End view included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var look_seconds: float = 2.2

## True while the game is ENDED. Setting it plays the end from the start; false takes it away.
var ended: bool = false:
	set(value):
		if value == ended:
			return
		ended = value
		_play()

var _sequence: Tween

@onready var _body: Node3D = %Body
@onready var _rumble: AudioStreamPlayer = %Rumble


func _ready() -> void:
	_body.visible = ended


func _play() -> void:
	if _sequence != null:
		_sequence.kill()
	_rumble.stop()
	_shake(shake_seconds)
	_body.visible = ended
	if not ended:
		return
	_sequence = create_tween()
	_sequence.tween_interval(calm_seconds)
	_sequence.tween_callback(_rumble.play)
	_sequence.tween_method(_shake, 0.0, shake_seconds, shake_seconds)
	_sequence.tween_callback(view_requested.emit.bind(end_view))
	_sequence.tween_interval(look_seconds)
	_sequence.tween_callback(crashed.emit)


# Shakes the room's camera at [param elapsed] seconds into the shake; at the end it stands still.
func _shake(elapsed: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("TheEnd %s: no camera to shake" % get_path())
		return
	var strength := shake_metres * (1.0 - elapsed / maxf(shake_seconds, 0.001))
	var phase := TAU * shakes_per_second * elapsed
	camera.h_offset = sin(phase) * strength
	camera.v_offset = sin(phase * 1.37 + 1.0) * strength

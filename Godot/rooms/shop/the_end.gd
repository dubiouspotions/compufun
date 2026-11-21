class_name TheEnd
extends Node3D
## The end of the game in the shop (Game.Phase.ENDED): a calm moment in the evening, the player
## looks up, then down at their own body, where a Pipedream pipe sticks a little out of the chest.
## Then the pipe pushes on through with a rumble and a cloud of blood, and the world crashes into
## the bluescreen. The body, the pipe and the blood are the children of Body, in world space, so
## move them in the editor; the pipe's place in the scene is where it ends up.

## The camera wants to go to [param view]: first the view that looks up, then the one at the body.
signal view_requested(view: StringName)
## The pipe has pushed through, and a moment has passed: time for the bluescreen.
signal crashed

## The view marker that looks up.
@export var up_view: StringName = &"EndUp"
## The view marker that looks down at the body.
@export var down_view: StringName = &"End"
## The calm moment in the evening before the player looks up, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var calm_seconds: float = 1.0
## From the start of the look up to the start of the look down, in seconds, the turn included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var up_seconds: float = 1.5
## From the start of the look down to the push of the pipe, in seconds, the turn included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var down_seconds: float = 1.8
## How much shorter the pipe sticks out of the chest before the push, in metres.
@export_range(0.0, 1.0, 0.01, "suffix:m") var push_metres: float = 0.2
@export_range(0.05, 3.0, 0.05, "suffix:s") var push_seconds: float = 0.2
## From the push to the bluescreen, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var crash_seconds: float = 1.0

## True while the game is ENDED. Setting it plays the end from the start; false takes it away.
var ended: bool = false:
	set(value):
		if value == ended:
			return
		ended = value
		_play()

var _sequence: Tween
var _pipe_end: Vector3

@onready var _body: Node3D = %Body
@onready var _pipe: Node3D = %Pipe
@onready var _bleeding: Node3D = %Bleeding
@onready var _splatter: CPUParticles3D = %Splatter
@onready var _rumble: AudioStreamPlayer = %Rumble


func _ready() -> void:
	_pipe_end = _pipe.position
	_play()


func _play() -> void:
	if _sequence != null:
		_sequence.kill()
	_rumble.stop()
	_splatter.emitting = false
	_bleeding.visible = false
	_pipe.position = _pipe_end + _pipe.basis.y.normalized() * push_metres  # the cylinder's axis
	_body.visible = ended
	if not ended:
		return
	_sequence = create_tween()
	_sequence.tween_interval(calm_seconds)
	_sequence.tween_callback(view_requested.emit.bind(up_view))
	_sequence.tween_interval(up_seconds)
	_sequence.tween_callback(view_requested.emit.bind(down_view))
	_sequence.tween_interval(down_seconds)
	_sequence.tween_callback(_rumble.play)
	_sequence.tween_property(_pipe, "position", _pipe_end, push_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_sequence.tween_callback(_bleed)
	_sequence.tween_interval(crash_seconds)
	_sequence.tween_callback(crashed.emit)


func _bleed() -> void:
	_bleeding.visible = true
	_splatter.restart()

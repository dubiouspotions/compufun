class_name TheEnd
extends Node3D
## The end of the game in the shop (Game.Phase.ENDED): a calm moment in the evening, the player
## looks up, and a Pipedream pipe stabs out through their chest from behind. They look down at the
## stub in their hands; then the pipe pushes on through with a rumble and a cloud of blood, and the
## world crashes into the bluescreen. Each stab jerks the chest along. The body, the pipe and the
## blood are the children of Body, in world space, so move them in the editor; the pipe's place in
## the scene is where it ends up.

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
## From the start of the look up to the first stab, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var stab_seconds: float = 0.8
## From the first stab to the look down, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var shock_seconds: float = 0.6
## From the start of the look down to the second stab, in seconds, the turn included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var down_seconds: float = 1.8
## From the second stab to the bluescreen, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var crash_seconds: float = 1.0
## How far the first stab pushes the pipe out of the chest, in metres.
@export_range(0.0, 1.0, 0.01, "suffix:m") var first_metres: float = 0.22
## How much further the second stab pushes it, in metres.
@export_range(0.0, 1.0, 0.01, "suffix:m") var second_metres: float = 0.2
## How long each stab takes, in seconds.
@export_range(0.01, 1.0, 0.01, "suffix:s") var stab_move_seconds: float = 0.07
## How far each stab jerks the chest along with the pipe, in metres; it settles back after.
@export_range(0.0, 0.3, 0.005, "suffix:m") var jerk_metres: float = 0.04
@export_range(0.05, 2.0, 0.05, "suffix:s") var settle_seconds: float = 0.35
## The pitch of the second stab's sound, against the first's 1.
@export_range(0.5, 2.0, 0.05) var second_pitch: float = 0.8

## True while the game is ENDED. Setting it plays the end from the start; false takes it away.
var ended: bool = false:
	set(value):
		if value == ended:
			return
		ended = value
		_play()

var _sequence: Tween
var _jerk: Tween
var _pipe_end: Vector3
var _chest_rest: Vector3

@onready var _body: Node3D = %Body
@onready var _chest: Node3D = %Chest
@onready var _pipe: Node3D = %Pipe
@onready var _chest_blood: Node3D = %ChestBlood
@onready var _bleeding: Node3D = %Bleeding
@onready var _splatter: CPUParticles3D = %Splatter
@onready var _pierce: AudioStreamPlayer = %Pierce
@onready var _rumble: AudioStreamPlayer = %Rumble


func _ready() -> void:
	_pipe_end = _pipe.position
	_chest_rest = _chest.position
	_play()


func _play() -> void:
	for tween: Tween in [_sequence, _jerk]:
		if tween != null:
			tween.kill()
	_pierce.stop()
	_rumble.stop()
	_splatter.emitting = false
	_chest_blood.visible = false
	_bleeding.visible = false
	_chest.position = _chest_rest
	_pipe.position = _pipe_at(first_metres + second_metres)
	_body.visible = ended
	if not ended:
		return
	_sequence = create_tween()
	_sequence.tween_interval(calm_seconds)
	_sequence.tween_callback(view_requested.emit.bind(up_view))
	_sequence.tween_interval(stab_seconds)
	_stab(_pipe_at(second_metres), 1.0)
	_sequence.tween_interval(shock_seconds)
	_sequence.tween_callback(view_requested.emit.bind(down_view))
	_sequence.tween_interval(down_seconds)
	_sequence.tween_callback(_rumble.play)
	_stab(_pipe_end, second_pitch)
	_sequence.tween_callback(_bleed)
	_sequence.tween_interval(crash_seconds)
	_sequence.tween_callback(crashed.emit)


# Where the pipe is when it is [param short_metres] short of its end, back along its axis.
func _pipe_at(short_metres: float) -> Vector3:
	return _pipe_end + _pipe.basis.y.normalized() * short_metres


# Adds a stab to the sequence: the sound, the pipe to [param to], and the chest jerked along.
func _stab(to: Vector3, pitch: float) -> void:
	_sequence.tween_callback(func() -> void:
		_pierce.pitch_scale = pitch
		_pierce.play()
		_jerk_chest())
	_sequence.tween_property(_pipe, "position", to, stab_move_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _jerk_chest() -> void:
	if _jerk != null:
		_jerk.kill()
	var along := -_pipe.basis.y.normalized() * jerk_metres
	_jerk = create_tween()
	_jerk.tween_property(_chest, "position", _chest_rest + along, stab_move_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_jerk.tween_property(_chest, "position", _chest_rest, settle_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _bleed() -> void:
	_chest_blood.visible = true
	_bleeding.visible = true
	_splatter.restart()

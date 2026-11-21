class_name TheEnd
extends Node3D
## The end of the game in the shop (Game.Phase.ENDED): a calm moment in the evening, then
## Pipedream pipes stab out through the player's chest from behind, and their head jerks up in
## shock. They look down at the stubs in their hands; then the pipes push on through with a rumble and a cloud of blood, one
## bends off like in the screensaver, and the world crashes into the bluescreen. Each stab jerks the
## chest along. The body, the pipes and the blood are the children of Body, in world space, so move
## them in the editor; each pipe under Pipes stabs along its own axis, and its place in the scene is
## where it ends up. Bend (a joint, and an arm under Grow that grows along its x) shows after the push.

## The camera wants to go to [param view]: first the view that looks up, then the one at the body.
signal view_requested(view: StringName)
## The pipe has pushed through, and a moment has passed: time for the bluescreen.
signal crashed

## The view marker that looks up.
@export var up_view: StringName = &"EndUp"
## The view marker that looks down at the body.
@export var down_view: StringName = &"End"
## The calm moment in the evening before the first stab, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var calm_seconds: float = 1.5
## From the first stab to the head jerking up, in seconds.
@export_range(0.0, 2.0, 0.01, "suffix:s") var flinch_seconds: float = 0.05
## How long the player looks up in shock before looking down, in seconds, the turn included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var shock_seconds: float = 0.8
## From the start of the look down to the second stab, in seconds, the turn included.
@export_range(0.0, 10.0, 0.1, "suffix:s") var down_seconds: float = 1.8
## From the second stab to the bluescreen, in seconds.
@export_range(0.0, 10.0, 0.1, "suffix:s") var crash_seconds: float = 1.0
## How far the first stab pushes the pipes out of the chest, in metres.
@export_range(0.0, 1.0, 0.01, "suffix:m") var first_metres: float = 0.22
## How much further the second stab pushes them, in metres.
@export_range(0.0, 1.0, 0.01, "suffix:m") var second_metres: float = 0.2
## How long each stab takes, in seconds.
@export_range(0.01, 1.0, 0.01, "suffix:s") var stab_move_seconds: float = 0.07
## How far each stab jerks the chest along with the pipe, in metres; it settles back after.
@export_range(0.0, 0.3, 0.005, "suffix:m") var jerk_metres: float = 0.04
@export_range(0.05, 2.0, 0.05, "suffix:s") var settle_seconds: float = 0.35
## How long the bend takes to grow out after the second stab, in seconds.
@export_range(0.01, 1.0, 0.01, "suffix:s") var bend_seconds: float = 0.1
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
var _pipe_ends: Dictionary[Node3D, Vector3] = {}
var _chest_rest: Vector3

@onready var _body: Node3D = %Body
@onready var _chest: Node3D = %Chest
@onready var _pipes: Node3D = %Pipes
@onready var _bend: Node3D = %Bend
@onready var _grow: Node3D = %Grow
@onready var _chest_blood: Node3D = %ChestBlood
@onready var _bleeding: Node3D = %Bleeding
@onready var _splatter: CPUParticles3D = %Splatter
@onready var _pierce: AudioStreamPlayer = %Pierce
@onready var _rumble: AudioStreamPlayer = %Rumble


func _ready() -> void:
	for pipe: Node3D in _pipes.get_children():
		_pipe_ends[pipe] = pipe.position
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
	for pipe: Node3D in _pipe_ends:
		pipe.position = _pipe_at(pipe, first_metres + second_metres)
	_bend.visible = false
	_grow.scale = Vector3(0.001, 1.0, 1.0)
	_body.visible = ended
	if not ended:
		return
	_sequence = create_tween()
	_sequence.tween_interval(calm_seconds)
	_stab(second_metres, 1.0)
	_sequence.tween_interval(flinch_seconds)
	_sequence.tween_callback(view_requested.emit.bind(up_view))
	_sequence.tween_interval(shock_seconds)
	_sequence.tween_callback(view_requested.emit.bind(down_view))
	_sequence.tween_interval(down_seconds)
	_sequence.tween_callback(_rumble.play)
	_stab(0.0, second_pitch)
	_sequence.tween_callback(_bend.show)
	_sequence.tween_property(_grow, "scale:x", 1.0, bend_seconds)
	_sequence.parallel().tween_callback(_bleed)
	_sequence.tween_interval(crash_seconds)
	_sequence.tween_callback(crashed.emit)


# Where [param pipe] is when it is [param short_metres] short of its end, back along its axis.
func _pipe_at(pipe: Node3D, short_metres: float) -> Vector3:
	return _pipe_ends[pipe] + pipe.basis.y.normalized() * short_metres  # a cylinder's axis is its y


# Adds a stab to the sequence: the sound, every pipe to [param short_metres] short of its end
# together, and the chest jerked along.
func _stab(short_metres: float, pitch: float) -> void:
	_sequence.tween_callback(func() -> void:
		_pierce.pitch_scale = pitch
		_pierce.play()
		_jerk_chest())
	var first := true
	for pipe: Node3D in _pipe_ends:
		var into := _sequence if first else _sequence.parallel()
		into.tween_property(pipe, "position", _pipe_at(pipe, short_metres), stab_move_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		first = false


func _jerk_chest() -> void:
	if _jerk != null:
		_jerk.kill()
	var along := Vector3.FORWARD * jerk_metres  # the pipes come out toward -z
	_jerk = create_tween()
	_jerk.tween_property(_chest, "position", _chest_rest + along, stab_move_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_jerk.tween_property(_chest, "position", _chest_rest, settle_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _bleed() -> void:
	_chest_blood.visible = true
	_bleeding.visible = true
	_splatter.restart()

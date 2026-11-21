extends Node3D
## The shop's front door. It stands open while the shop is open (Game.Phase OPEN or CALLING) and is
## shut otherwise: in the morning before the Open sign, at night and at the end. It swings open
## when the shop opens and slams shut when it closes, and takes its place at once when it first
## shows. Its origin is the hinge; place the instance in the shop shut.

## How far the door stands open, in degrees around the hinge; positive swings out to the street.
@export_range(-180.0, 180.0, 1.0, "suffix:deg") var open_degrees: float = 80.0
## How long the swing open takes, in seconds.
@export_range(0.0, 5.0, 0.05, "suffix:s") var swing_seconds: float = 0.8
## How long the slam shut takes, in seconds; [member slam] plays as it hits the frame.
@export_range(0.0, 5.0, 0.05, "suffix:s") var shut_seconds: float = 0.3
@export var slam: SoundSet = preload("res://sounds/door_slam.tres")

var _open: bool = false
var _placed: bool = false
var _swing: Tween

@onready var _hinge: Node3D = %Hinge


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## True while the shop is open, so the door stands open or swings open.
func is_open() -> bool:
	return _open


func _sync() -> void:
	var open: bool = Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.CALLING
	if _placed and open == _open:
		return
	_open = open
	if _swing != null:
		_swing.kill()
	var angle := deg_to_rad(open_degrees) if open else 0.0
	if not _placed:
		_placed = true
		_hinge.rotation.y = angle
		return
	if open:
		_swing = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_swing.tween_property(_hinge, "rotation:y", angle, swing_seconds)
		return
	_swing = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.tween_property(_hinge, "rotation:y", angle, shut_seconds)
	_swing.tween_callback(slam.play_at.bind(self))

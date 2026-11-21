extends CorruptionSign
## The shop's poster falls off the wall like a card of the Solitaire win: it bounces along the floor
## and leaves a trail of copies of itself, then it leans against the wall on the floor. Stage 1: it
## falls once the player has looked at it for [member look_seconds]; it then sets stage 2, fallen.

enum Phase { HANGING, FALLING, LANDED }

## A fall that never reaches the floor stops after this many steps.
const MAX_STEPS: int = 1000

## The seconds that the poster must be in view before it falls.
@export var look_seconds: float = 0.6
## The speed along the wall, in m/s. Negative falls to the left.
@export var side_speed: float = -0.5
## The speed away from the wall, in m/s, so that each copy lies in front of the one before.
@export var out_speed: float = 0.05
## The pull down, in m/s per second.
@export var gravity: float = 6.0
## The share of the speed that a bounce keeps, 0 to 1.
@export_range(0.0, 1.0) var bounce: float = 0.65
## The bounces before the poster stays on the floor.
@export var bounces: int = 4
## The seconds between two copies of the trail.
@export var trail_step: float = 0.04
## The seconds that the trail stays after the poster lands.
@export var trail_seconds: float = 3.0
## The seconds that the poster takes to tip against the wall when it lands.
@export var tip_seconds: float = 0.25
## The height of the shop floor, in metres.
@export var floor_height: float = 0.0

var _poster: Poster
var _sheets: Array[MeshInstance3D] = []
var _home: Transform3D
var _phase: Phase = Phase.HANGING
var _looked: float = 0.0
var _path: PackedVector3Array
var _step: int = 0
var _clock: float = 0.0
var _tip: Tween
var _trail_wait: Tween

@onready var _trail: Node3D = %Trail


func _ready() -> void:
	_poster = get_tree().get_first_node_in_group(&"shop_poster") as Poster
	if _poster == null:
		push_error("poster_falls: no Poster in the group shop_poster")
	else:
		_home = _poster.global_transform
		for node: Node in _poster.find_children("*", "MeshInstance3D", true, false):
			_sheets.append(node as MeshInstance3D)
	super()


func _apply(shown_stage: int) -> void:
	if _poster == null:
		return
	if shown_stage == 1:
		if _phase == Phase.LANDED and not (_tip != null and _tip.is_running()):
			_phase = Phase.HANGING  # set back to 1 after it fell: it falls again
		if _phase == Phase.HANGING:
			_poster.global_transform = _home
			set_process(true)
		return
	set_process(false)
	_looked = 0.0
	if shown_stage == 0:
		if _tip != null:
			_tip.kill()
		_clear_trail()
		_phase = Phase.HANGING
		_poster.global_transform = _home
		return
	if _phase == Phase.LANDED:
		return  # it leans there, or tips there
	if _phase == Phase.FALLING:
		_clear_trail()
	_phase = Phase.LANDED
	_poster.global_transform = _leaning()


func _process(delta: float) -> void:
	if _phase == Phase.HANGING:
		var camera := get_viewport().get_camera_3d()
		var seen := camera != null and camera.is_position_in_frustum(_poster.global_position)
		_looked = _looked + delta if seen else 0.0
		if _looked >= look_seconds:
			_fall()
		return
	_clock += delta
	while _phase == Phase.FALLING and _clock >= trail_step:
		_clock -= trail_step
		_step += 1
		if _step >= _path.size():
			_land()
			return
		_poster.global_position = _path[_step]
		_leave_copy()


func _fall() -> void:
	_clear_trail()
	_path = _fall_path()
	_step = -1
	_clock = trail_step
	_phase = Phase.FALLING


func _land() -> void:
	set_process(false)
	_phase = Phase.LANDED
	_trail_wait = create_tween()
	_trail_wait.tween_interval(trail_seconds)
	_trail_wait.tween_callback(_remove_copies)
	_tip = create_tween()
	_tip.tween_property(_poster, ^"global_transform", _leaning(), tip_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tip.tween_callback(set_stage.bind(2))


# The centre of the poster at each trail step, from the wall to where it stays on the floor.
func _fall_path() -> PackedVector3Array:
	var points := PackedVector3Array()
	var half := _poster.size.y * 0.5
	var drift := _home.basis.x.normalized() * side_speed + _home.basis.z.normalized() * out_speed
	var at := _home.origin
	var fall := 0.0
	var left := bounces
	while points.size() < MAX_STEPS:
		fall -= gravity * trail_step
		at += (drift + Vector3.UP * fall) * trail_step
		if at.y - half <= floor_height and fall < 0.0:
			at.y = floor_height + half
			if left <= 0:
				points.append(at)
				break
			left -= 1
			fall = -fall * bounce
		points.append(at)
	return points


# Where the poster stays: its bottom edge on the floor at the end of the fall, its top against the wall.
func _leaning() -> Transform3D:
	var end := _fall_path()[-1]
	var out := _home.basis.z.normalized()
	var from_wall := (end - _home.origin).dot(out)
	var lean := asin(clampf(from_wall / _poster.size.y, 0.0, 1.0))
	var tilted := Basis(_home.basis.x.normalized(), -lean) * _home.basis
	var bottom := Vector3(end.x, floor_height, end.z)
	return Transform3D(tilted, bottom + tilted.y.normalized() * _poster.size.y * 0.5)


func _leave_copy() -> void:
	for sheet: MeshInstance3D in _sheets:
		var copy := MeshInstance3D.new()
		copy.mesh = sheet.mesh
		copy.material_override = sheet.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.add_child(copy)
		copy.global_transform = sheet.global_transform


func _clear_trail() -> void:
	if _trail_wait != null:
		_trail_wait.kill()
	_remove_copies()


func _remove_copies() -> void:
	for copy: Node in _trail.get_children():
		copy.queue_free()

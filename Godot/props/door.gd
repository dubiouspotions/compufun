class_name ShopDoor
extends Node3D
## The shop's front door, a swing door on a spring hinge. It stands shut; a customer near the doorway
## pushes it open away from them (in when they come from the street, out when they leave), and once
## they are through the door closer swings it back, past shut and back a few times, until it rests.
## It follows where the customers are on every frame, so a restore or a skipped walk leaves it right.
## It also lets the street in: the street's bus is near silent and muffled while the door is shut,
## and opens up with it.

## The group of every customer body that walks through the door.
const WALKERS: StringName = &"customer_bodies"

## How far a push swings the door, in degrees.
@export var open_degrees: float = 85.0
## Where the hinge stops the door, in degrees each way; it bounces back off the stop.
@export var stop_degrees: float = 100.0
## How near a customer must be to the middle of the doorway to push the door, in metres.
@export var open_distance: float = 1.5
## The push: how hard it pulls the door open (per second squared) and how much it brakes (per second).
@export var push_stiffness: float = 70.0
@export var push_damping: float = 11.0
## The door closer: how hard it pulls the door shut and how much it brakes. A little brake lets the
## door swing past shut and back before it rests.
@export var closer_stiffness: float = 24.0
@export var closer_damping: float = 3.6
## The middle of the doorway, from the hinge, while the door is shut.
@export var doorway_offset: Vector3 = Vector3(0.58, 0.0, 0.0)
## The bus of the street's sounds (default_bus_layout.tres; rooms/shop/sound_zones.tscn sends the
## street's 3D sounds to it). Its first effect is the low-pass filter that the door opens.
@export var street_bus: StringName = &"Street"
## The street's low-pass cutoff in Hz, and its bus volume in dB, while the door is shut and open.
@export var shut_cutoff_hz: float = 500.0
@export var open_cutoff_hz: float = 12000.0
@export var shut_volume_db: float = -20.0
@export var open_volume_db: float = 2.0

var _closed_yaw: float
# The door's swing from shut, in radians (negative: into the shop), and how fast it turns.
var _angle: float = 0.0
var _speed: float = 0.0
# Which way the current push swings the door: -1 into the shop (a customer on the street pushes),
# 1 out to the street (a customer in the shop pushes), 0 no push.
var _push: float = 0.0
var _street: int = -1
var _filter: AudioEffectLowPassFilter


func _ready() -> void:
	_closed_yaw = rotation.y
	_street = AudioServer.get_bus_index(street_bus)
	if _street < 0:
		push_error("ShopDoor: no audio bus '%s' in default_bus_layout.tres" % street_bus)
		return
	_filter = AudioServer.get_bus_effect(_street, 0) as AudioEffectLowPassFilter
	if _filter == null:
		push_error("ShopDoor: the first effect of the bus '%s' is not a low-pass filter" % street_bus)


func _process(delta: float) -> void:
	var side := _nearest_side()
	# A push starts only on a door that is nearly shut; then it keeps its way until the door shuts.
	if side == 0.0:
		_push = 0.0
	elif _push == 0.0 and absf(_angle) < deg_to_rad(15.0):
		_push = side
	var target := _push * deg_to_rad(open_degrees)
	var stiffness := push_stiffness if _push != 0.0 else closer_stiffness
	var damping := push_damping if _push != 0.0 else closer_damping
	# Small steps keep the spring steady when a frame is long.
	var steps := ceili(delta / 0.008)
	var step := delta / steps
	for i: int in steps:
		_speed += (stiffness * (target - _angle) - damping * _speed) * step
		_angle += _speed * step
		var stop := deg_to_rad(stop_degrees)
		if absf(_angle) > stop:
			_angle = signf(_angle) * stop
			_speed *= -0.3
	rotation.y = _closed_yaw + _angle
	_let_street_in(clampf(absf(_angle) / deg_to_rad(open_degrees), 0.0, 1.0))


# Which side of the doorway the nearest customer within open_distance is on: -1 the street, 1 the
# shop, 0 nobody near.
func _nearest_side() -> float:
	var hinge := get_parent_node_3d().global_transform * position
	var shut := get_parent_node_3d().global_basis * Basis(Vector3.UP, _closed_yaw)
	var doorway := hinge + shut * doorway_offset
	var best := open_distance
	var side := 0.0
	for node: Node in get_tree().get_nodes_in_group(WALKERS):
		var body := node as Node3D
		if not body.is_visible_in_tree():
			continue
		var offset := body.global_position - doorway
		var distance := Vector2(offset.x, offset.z).length()
		if distance < best:
			best = distance
			side = signf((shut.inverse() * offset).z)
	return side


# The street sounds as open as the door: the cutoff moves on a log scale, as the ear hears pitch.
func _let_street_in(open: float) -> void:
	if _filter == null:
		return
	_filter.cutoff_hz = exp(lerpf(log(shut_cutoff_hz), log(open_cutoff_hz), open))
	AudioServer.set_bus_volume_db(_street, lerpf(shut_volume_db, open_volume_db, open))

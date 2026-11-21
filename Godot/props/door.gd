class_name ShopDoor
extends Node3D
## The shop's front door. It stands closed, swings open while a customer is near the doorway, coming
## in or going out, and swings shut once they are through. It follows where the customers are on
## every frame, so a restore or a skipped walk leaves it right.

## The group of every customer body that walks through the door.
const WALKERS: StringName = &"customer_bodies"

## How far the door swings open, in degrees about its hinge (negative: into the shop).
@export var open_degrees: float = -80.0
## How near a customer must be to the middle of the doorway for the door to stand open, in metres.
@export var open_distance: float = 1.5
## How fast the door swings, in degrees per second.
@export var swing_speed: float = 260.0
## The middle of the doorway, from the hinge, while the door is closed.
@export var doorway_offset: Vector3 = Vector3(0.58, 0.0, 0.0)

var _closed_yaw: float


func _ready() -> void:
	_closed_yaw = rotation.y


func _process(delta: float) -> void:
	var target := _closed_yaw + (deg_to_rad(open_degrees) if _someone_near() else 0.0)
	rotation.y = move_toward(rotation.y, target, deg_to_rad(swing_speed) * delta)


func _someone_near() -> bool:
	var doorway := get_parent_node_3d().global_transform * (position + Basis(Vector3.UP, _closed_yaw) * doorway_offset)
	for node: Node in get_tree().get_nodes_in_group(WALKERS):
		var body := node as Node3D
		if body.is_visible_in_tree() and Vector2(body.global_position.x - doorway.x, body.global_position.z - doorway.z).length() < open_distance:
			return true
	return false

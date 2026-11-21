class_name Hotspot
extends Area3D
## A thing that the player clicks. Every hotspot is this scene (rooms/hotspot.tscn); the room
## decides what a click does from [member action]. The mouse cursor turns into a hand over it.

## The player clicked the hotspot with the left mouse button.
signal clicked(hotspot: Hotspot)

enum Action { GO_TO_VIEW, CALL_CUSTOMER, TAKE_PART }

## The group of the hotspots that take a drop (see [member takes_drop]).
const DROP_TARGETS: StringName = &"hotspot_drop_targets"

@export var action: Action = Action.GO_TO_VIEW
## For GO_TO_VIEW: the name of the view marker to go to.
@export var view: StringName = &""
## For TAKE_PART: the part that a click takes from the storage into the hand.
@export var part: Part
## The size of the clickable box, in metres. It applies when the game runs.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5)
## The player can drag the part in the hand here: dropping it acts as a click (see Hand). Set before
## the hotspot enters the tree.
@export var takes_drop: bool = false

@onready var _shape: CollisionShape3D = %Shape


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	if takes_drop:
		add_to_group(DROP_TARGETS)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	mouse_exited.connect(func() -> void: Input.set_default_cursor_shape(Input.CURSOR_ARROW))


## Shows or hides the hotspot. A hidden hotspot does not take clicks.
func set_enabled(on: bool) -> void:
	visible = on
	input_ray_pickable = on
	if not on:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## The distance in metres along the ray from [param from] along the unit vector [param dir] (world
## space) to where it enters the clickable box, or -1.0 when it misses or the hotspot is disabled.
func ray_distance(from: Vector3, dir: Vector3) -> float:
	return box_ray_distance(from, dir) if input_ray_pickable else -1.0


## Like [method ray_distance], but it also measures a disabled hotspot's box.
func box_ray_distance(from: Vector3, dir: Vector3) -> float:
	var to_box := global_transform.affine_inverse()
	var hit: Variant = AABB(-size * 0.5, size).intersects_ray(to_box * from, to_box.basis * dir)
	return from.distance_to(global_transform * (hit as Vector3)) if hit != null else -1.0


func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

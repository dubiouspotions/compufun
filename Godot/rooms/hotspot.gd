class_name Hotspot
extends Area3D
## A thing that the player clicks. Every hotspot is this scene (rooms/hotspot.tscn); the room
## decides what a click does from [member action]. The mouse cursor turns into a hand over it.

## The player clicked the hotspot: with the left mouse button's press, or with a finger's tap, on the
## lift (TapGate).
signal clicked(hotspot: Hotspot)

enum Action { GO_TO_VIEW, CALL_CUSTOMER, TAKE_PART, TALK_TO_VISITOR, POWER_WORK_COMPUTER }

## The group of the hotspots that take a drop (see [member takes_drop]).
const DROP_TARGETS: StringName = &"hotspot_drop_targets"

@export var action: Action = Action.GO_TO_VIEW
## For GO_TO_VIEW: the name of the view marker to go to.
@export var view: StringName = &""
## For TAKE_PART: the part that a click takes from the storage into the empty hand, or that an unused
## piece in the hand goes back to (see [method Game.return_part]).
@export var part: Part
## The size of the clickable box, in metres. It applies when the game runs, and at once when it
## changes while the game runs.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5):
	set(value):
		size = value
		if is_node_ready():
			(_shape.shape as BoxShape3D).size = value
## The player can drag the part in the hand here: dropping it acts as a click (see Hand). Set before
## the hotspot enters the tree.
@export var takes_drop: bool = false
## The player drags from here (the VGA plug): a finger clicks on the touch, as the mouse does on the
## press, rather than on the lift.
var drag_source: bool = false

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


## Tints [param mesh] in [param color], with an outline, while the mouse is over the hotspot. For a
## button on a surface, where an outline alone hardly shows. It uses the mesh's material_overlay.
func highlight_on_hover(mesh: MeshInstance3D, color: Color) -> void:
	var tint := ghost_material(color)
	tint.albedo_color.a = 0.6
	tint.next_pass = outline_material(color, 0.008)
	mouse_entered.connect(func() -> void: mesh.material_overlay = tint)
	mouse_exited.connect(func() -> void: mesh.material_overlay = null)


## An outline in [param color] for a mesh's [member GeometryInstance3D.material_overlay]: an
## inverted hull, its front faces culled, grown [param width] metres along the normals.
static func outline_material(color: Color, width: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = width
	material.albedo_color = color
	return material


## A see-through ghost material in [param color], for a mesh's material_override: where a thing can go.
static func ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.35)
	return material


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
	if TapGate.presses(event) if drag_source else TapGate.clicks(event):
		clicked.emit(self)

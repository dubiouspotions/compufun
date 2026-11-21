class_name CustomerBody
extends Node3D
## The 3D customer: one placeholder body for all customers. It wears the person's photos: the face
## photo on the face, the average colour of the face photo on the skin, and the shirt from the
## clothes portrait. The trousers take the customer's colour. It walks, with footsteps, while it moves,
## and carries a computer in when the shop says so (carrying).

# The shirt parameters that a portrait sets; without a portrait they come from shirt_material.
const SHIRT_PARAMETERS: Array[StringName] = [&"albedo_texture", &"albedo_color", &"uv_rect", &"tint_texture",
	&"tint_rect", &"fill_transparent"]

## The face when the person has no face texture yet.
@export var default_face: Texture2D
## The size of the face photo, as a share of the face area: the front of the head from the chin to
## the brow. 1 fills the area; the rest of the area takes the skin colour.
@export_range(0.3, 1.0) var face_scale: float = 0.85
## The gap below the face photo, as a share of the face area's height. Raise it to lift the eyeline;
## above 1 - face_scale, the top of the photo is cut off.
@export_range(0.0, 0.7) var face_lift: float = 0.15
## The portrait pose whose clothes the shirt shows.
@export var clothes_pose: StringName = &"neutral"
## The speed, in metres per second, at which the walk plays at its own pace.
@export var walk_speed: float = 1.4
## How far the arms swing while the body walks without a computer, in degrees.
@export var arm_swing: float = 17.0
## How far forward the arms reach to hold the computer, in degrees.
@export var carry_reach: float = 20.0
## The shared materials. Each part that uses one gets this body's own copy, which the customer
## changes.
@export var face_material: ShaderMaterial
@export var skin_material: ShaderMaterial
@export var shirt_material: ShaderMaterial
@export var trousers_material: ShaderMaterial

var _shown: Customer
var _has_shown: bool = false
var _face: ShaderMaterial
var _skin: ShaderMaterial
var _shirt: ShaderMaterial
var _trousers: ShaderMaterial
var _last_position: Vector3

## True while the body carries a computer in. The shop sets it for a drop-off.
var carrying: bool = false:
	set(value):
		carrying = value
		if is_node_ready():
			_computer.visible = value

@onready var _animation: AnimationPlayer = %AnimationPlayer
@onready var _steps: AudioStreamPlayer3D = %Steps
@onready var _computer: Node3D = %Computer
@onready var _shoulder_left: Node3D = $ShoulderL
@onready var _shoulder_right: Node3D = $ShoulderR


func _ready() -> void:
	_face = _own_copy(face_material)
	_face.set_shader_parameter("uv_rect", _face_rect())
	_skin = _own_copy(skin_material)
	_shirt = _own_copy(shirt_material)
	_trousers = _own_copy(trousers_material)
	_last_position = global_position
	_computer.visible = carrying
	_animation.play(&"idle")


func _process(delta: float) -> void:
	# Only the move across the ground counts; the walk's own bob is up and down.
	var moved := global_position - _last_position
	moved.y = 0.0
	var speed := moved.length() / maxf(delta, 0.0001)
	_last_position = global_position
	# A jump, such as the move back to the start of the path, is not a walk.
	if speed > 0.05 and speed < 20.0:
		_animation.speed_scale = speed / walk_speed
		if _animation.assigned_animation != &"walk":
			_animation.play(&"walk", 0.15)
	elif _animation.assigned_animation != &"idle":
		_animation.speed_scale = 1.0
		_animation.play(&"idle", 0.2)
	_move_arms(delta)


# The arms hold the computer, or swing against the legs while walking, or hang. They ease between
# those, so a change of pose never snaps.
func _move_arms(delta: float) -> void:
	var swing := 0.0
	if _animation.assigned_animation == &"walk" and _animation.current_animation_length > 0.0:
		var cycle := _animation.current_animation_position / _animation.current_animation_length
		swing = deg_to_rad(arm_swing) * sin(TAU * cycle)
	var left := -swing
	var right := swing
	if carrying:
		left = deg_to_rad(carry_reach)
		right = left
	var weight := minf(delta * 10.0, 1.0)
	_shoulder_left.rotation.x = lerpf(_shoulder_left.rotation.x, left, weight)
	_shoulder_right.rotation.x = lerpf(_shoulder_right.rotation.x, right, weight)


## Plays one footstep, a little higher or lower each time. The walk animation calls it when a foot
## lands.
func step() -> void:
	_steps.pitch_scale = randf_range(0.9, 1.1)
	_steps.play()


## Dresses the body as [param customer]. null shows the default face and clothes.
func show_customer(customer: Customer) -> void:
	if _has_shown and customer == _shown:
		return
	_has_shown = true
	_shown = customer
	var person := customer.person if customer != null else null
	var face := default_face
	if person != null and person.face != null:
		face = person.face
	_face.set_shader_parameter("albedo_texture", face)
	_face.set_shader_parameter("tint_texture", face)
	_skin.set_shader_parameter("tint_texture", face)
	_skin.set_shader_parameter("tint_from_texture", true)
	var portrait: Texture2D = person.portraits.get(clothes_pose) if person != null else null
	if portrait != null:
		var rect := person.shirt_rect
		var area := Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		_shirt.set_shader_parameter("albedo_texture", portrait)
		_shirt.set_shader_parameter("albedo_color", Color.WHITE)
		_shirt.set_shader_parameter("uv_rect", area)
		_shirt.set_shader_parameter("tint_texture", portrait)
		_shirt.set_shader_parameter("tint_rect", area)
		_shirt.set_shader_parameter("fill_transparent", true)
	else:
		for parameter: StringName in SHIRT_PARAMETERS:
			_shirt.set_shader_parameter(parameter, shirt_material.get_shader_parameter(parameter))
	var trousers: Color = trousers_material.get_shader_parameter("albedo_color")
	_trousers.set_shader_parameter("albedo_color", customer.trousers_color if customer != null else trousers)


# The uv_rect that shows the whole face photo at face_scale, centred, face_lift above the chin.
func _face_rect() -> Vector4:
	var corner := Vector2((1.0 - face_scale) * 0.5, 1.0 - face_lift - face_scale)
	return Vector4(-corner.x / face_scale, -corner.y / face_scale, 1.0 / face_scale, 1.0 / face_scale)


func _own_copy(shared: ShaderMaterial) -> ShaderMaterial:
	assert(shared != null, "CustomerBody: set the four materials in the inspector")
	var copy := shared.duplicate() as ShaderMaterial
	for node: Node in find_children("*", "MeshInstance3D"):
		var part := node as MeshInstance3D
		if part.material_override == shared:
			part.material_override = copy
	return copy

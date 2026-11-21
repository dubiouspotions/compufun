class_name CustomerBody
extends Node3D
## The 3D customer: one placeholder body for all customers. The face shows the person's face
## texture, or [member default_face] until the person has one. The shirt and the trousers take the
## colours of the customer.

const FACE_SHADER: Shader = preload("res://shaders/psx_world.gdshader")

## The face when the person has no face texture yet.
@export var default_face: Texture2D
## The shared shirt material. Each part that uses it gets this body's own copy, in the customer's
## shirt colour.
@export var shirt_material: ShaderMaterial
## The shared trousers material. Each part that uses it gets this body's own copy, in the
## customer's trousers colour.
@export var trousers_material: ShaderMaterial

var _shown: Customer
var _has_shown: bool = false
var _shirt: ShaderMaterial
var _trousers: ShaderMaterial

@onready var _face: MeshInstance3D = %Face


func _ready() -> void:
	_shirt = _own_copy(shirt_material)
	_trousers = _own_copy(trousers_material)


## Shows the face and the clothes of [param customer]. null shows the default face and clothes.
func show_customer(customer: Customer) -> void:
	if _has_shown and customer == _shown:
		return
	_has_shown = true
	_shown = customer
	var face := default_face
	if customer != null and customer.person != null and customer.person.face != null:
		face = customer.person.face
	var material := ShaderMaterial.new()
	material.shader = FACE_SHADER
	material.set_shader_parameter("albedo_texture", face)
	_face.material_override = material
	var shirt: Color = shirt_material.get_shader_parameter("albedo_color")
	var trousers: Color = trousers_material.get_shader_parameter("albedo_color")
	if customer != null:
		shirt = customer.shirt_color
		trousers = customer.trousers_color
	_shirt.set_shader_parameter("albedo_color", shirt)
	_trousers.set_shader_parameter("albedo_color", trousers)


func _own_copy(shared: ShaderMaterial) -> ShaderMaterial:
	assert(shared != null, "CustomerBody: set the shirt and the trousers materials in the inspector")
	var copy := shared.duplicate() as ShaderMaterial
	for node: Node in find_children("*", "MeshInstance3D"):
		var part := node as MeshInstance3D
		if part.material_override == shared:
			part.material_override = copy
	return copy

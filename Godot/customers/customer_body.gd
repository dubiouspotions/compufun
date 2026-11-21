class_name CustomerBody
extends Node3D
## The 3D customer: one placeholder body for all customers. The face shows the person's face
## texture, or [member default_face] until the person has one.

const FACE_SHADER: Shader = preload("res://shaders/psx_world.gdshader")

## The face when the person has no face texture yet.
@export var default_face: Texture2D

var _shown: Customer
var _has_shown: bool = false

@onready var _face: MeshInstance3D = %Face


## Shows the face of [param customer]. null shows the default face.
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

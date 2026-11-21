@tool
class_name Poster
extends Node3D
## A printed sheet: a poster on a wall, or a sticker on a case. Its origin is the centre of the sheet,
## which faces +Z.

## The picture on the sheet, stretched to [member size].
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply()
## Width and height of the sheet, in metres.
@export var size := Vector2(0.32, 0.457):
	set(value):
		size = value
		_apply()

@onready var _sheet: MeshInstance3D = $Sheet


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	(_sheet.material_override as ShaderMaterial).set_shader_parameter(&"albedo_texture", texture)
	(_sheet.mesh as QuadMesh).size = size

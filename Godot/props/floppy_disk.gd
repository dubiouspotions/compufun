@tool
class_name FloppyDiskModel
extends Node3D
## The 3D floppy disk (props/floppy_disk.tscn), the model of every FloppyDisk: in the hand, in its
## storage box and sticking out of a FloppyDrive.

## The picture printed over the paper label (FloppyDisk.label); null shows the plain label with the
## Windows logo.
@export var label: Texture2D:
	set(value):
		label = value
		if is_node_ready():
			_show_label()

@onready var _logo: MeshInstance3D = $Flag
@onready var _print: MeshInstance3D = $Print


func _ready() -> void:
	_show_label()


func _show_label() -> void:
	_logo.visible = label == null
	_print.visible = label != null
	(_print.material_override as ShaderMaterial).set_shader_parameter(&"albedo_texture", label)

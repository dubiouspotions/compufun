@tool
class_name FloppyDiskModel
extends Node3D
## The 3D floppy disk (props/floppy_disk.tscn), the model of every FloppyDisk: in the hand, in its
## storage box and sticking out of a FloppyDrive. One box whose texture holds the label and the
## shutter (tools/make_floppy_disk.py), so that nothing on it can z-fight under the PSX vertex snap.

## The picture printed over the paper label (FloppyDisk.label); null shows the plain label with the
## Windows logo.
@export var label: Texture2D:
	set(value):
		label = value
		if is_node_ready():
			_show_label()
## Where [member label] is printed on the top, in metres from the disk's middle: x across, y along
## the disk away from the shutter. The picture's top faces the shutter.
@export var print_area := Rect2(-0.036, 0.0178, 0.072, 0.0254)

const _BLANK_LABEL := preload("res://materials/textures/floppy_disk_blank.png")

@onready var _disk: MeshInstance3D = $Disk
@onready var _plain: Material = _disk.material_override


func _ready() -> void:
	_show_label()


func _show_label() -> void:
	var plain := _plain as ShaderMaterial
	if label == null or plain == null:  # a ghost of the disk has no texture to print on
		_disk.material_override = _plain
		return
	var printed := plain.duplicate() as ShaderMaterial
	printed.set_shader_parameter(&"albedo_texture", _BLANK_LABEL)
	printed.set_shader_parameter(&"overlay", true)
	printed.set_shader_parameter(&"overlay_texture", label)
	printed.set_shader_parameter(&"overlay_rect", _top_uv_rect(print_area))
	_disk.material_override = printed


# [param area] on the top of the BoxMesh as a rect in its texture's UV, its top left corner at -x, -z:
# BoxMesh puts the top in the middle of the second row, u running from +x to -x and v from +z to -z.
func _top_uv_rect(area: Rect2) -> Vector4:
	var size := (_disk.mesh as BoxMesh).size
	var u := func(x: float) -> float: return (2.0 - (x / size.x + 0.5)) / 3.0
	var v := func(z: float) -> float: return 0.5 + (0.5 - z / size.z) / 2.0
	var top_left := Vector2(u.call(area.position.x), v.call(area.position.y))
	var bottom_right := Vector2(u.call(area.end.x), v.call(area.end.y))
	return Vector4(top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y)

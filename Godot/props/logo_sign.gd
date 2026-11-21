class_name LogoSign
extends MeshInstance3D
## The CompuFun logo sign. The corruption signs logo_blue and logo_cambion change it; both can be on.

## The group of the logo signs in the shop.
const GROUP: StringName = &"logo_signs"

## The art when [member blue] is on.
@export var blue_art: Texture2D
## The art when [member cambion] is on.
@export var cambion_art: Texture2D
## The art when [member blue] and [member cambion] are both on.
@export var blue_cambion_art: Texture2D

## On: the sign is Windows blue.
var blue: bool = false:
	set(value):
		blue = value
		_show()
## On: the sign reads CambIon.
var cambion: bool = false:
	set(value):
		cambion = value
		_show()

var _plain: ShaderMaterial
var _looks: Dictionary[Texture2D, ShaderMaterial] = {}


## Every logo sign in the group [constant GROUP] of [param tree]. Reports an empty group, and a node
## in the group that is not a LogoSign.
static func every(tree: SceneTree) -> Array[LogoSign]:
	var logos: Array[LogoSign] = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		var logo := node as LogoSign
		if logo == null:
			push_error("LogoSign: %s in the group %s is not a LogoSign" % [node.get_path(), GROUP])
		else:
			logos.append(logo)
	if logos.is_empty():
		push_error("LogoSign: no logo sign in the group %s" % GROUP)
	return logos


func _ready() -> void:
	_plain = material_override as ShaderMaterial
	if _plain == null:
		push_error("LogoSign %s: its material_override is not a ShaderMaterial" % get_path())
	_show()


func _show() -> void:
	if not is_node_ready() or _plain == null:
		return
	var art: Texture2D = null
	if blue or cambion:
		art = blue_cambion_art if blue and cambion else blue_art if blue else cambion_art
		if art == null:
			push_error("LogoSign %s: no art for blue=%s cambion=%s" % [get_path(), blue, cambion])
	if art == null:
		material_override = _plain
		return
	if not _looks.has(art):
		var look := _plain.duplicate() as ShaderMaterial
		look.set_shader_parameter(&"albedo_texture", art)
		_looks[art] = look
	material_override = _looks[art]
